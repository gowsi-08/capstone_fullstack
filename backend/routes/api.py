from flask import Blueprint, request, jsonify, send_file
from services.database import db, fs
from services.model_service import model_service
from services.auth_service import auth_service
from services.training_service import training_service
from services.pathfinding_service import pathfinding_service
from utils.image_processing import process_map_image
from utils.csv_handler import read_test_csv
from bson import ObjectId
import base64
from io import BytesIO

api_bp = Blueprint('api', __name__)

# =====================
# AUTH ROUTES
# =====================
@api_bp.route('/auth/login', methods=['POST'])
def login():
    """Authenticate a user (student or admin)."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        username = data.get('username', '').strip().lower()
        password = data.get('password', '').strip()

        if not username or not password:
            return jsonify({'error': 'Username and password required'}), 400

        user = auth_service.authenticate(username, password)
        if user:
            print(f"✅ LOGIN: {user['display_name']} ({user['role']})", flush=True)
            return jsonify({
                'success': True,
                'user': user
            })
        else:
            return jsonify({'success': False, 'error': 'Invalid credentials'}), 401

    except Exception as e:
        print(f"❌ LOGIN ERROR: {e}")
        return jsonify({'error': str(e)}), 500


# =====================
# PREDICTION ROUTE
# =====================
# PREDICTION ROUTE
# =====================
# PREDICTION ROUTE
# =====================
@api_bp.route('/getlocation', methods=['POST'])
def get_prediction():
    try:
        data = request.get_json()
        if not data:
            print("❌ No data provided in request", flush=True)
            return jsonify({'error': 'No data provided'}), 400
        
        # Check if this is GPS data or WiFi data
        is_gps_data = isinstance(data, dict) and 'latitude' in data and 'longitude' in data
        
        print(f"🔍 Request data type: {type(data)}", flush=True)
        print(f"🔍 Is GPS data: {is_gps_data}", flush=True)
        print(f"🔍 Data keys: {data.keys() if isinstance(data, dict) else 'not a dict'}", flush=True)
        
        if is_gps_data:
            # GPS-based prediction
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            print(f"📍 API: Received GPS location request: ({latitude}, {longitude})", flush=True)
            
            from math import radians, sin, cos, sqrt, atan2
            
            # Find nearest node with GPS coordinates
            nearest_node = None
            min_distance = float('inf')
            total_nodes_checked = 0
            nodes_with_gps = 0
            
            # Also track a fallback node (default node or any node with dataset_location)
            fallback_node = None
            
            for floor in [1, 2, 3]:
                graph = pathfinding_service.build_graph(floor)
                if not graph:
                    continue
                
                print(f"🔍 Checking floor {floor}: {len(graph['nodes'])} nodes", flush=True)
                
                for nid, node_data in graph['nodes'].items():
                    total_nodes_checked += 1
                    
                    # Track fallback: prefer default node, then any node with dataset_location
                    if fallback_node is None:
                        if node_data.get('is_default', False):
                            fallback_node = {
                                'node_id': nid,
                                'x': node_data['x'],
                                'y': node_data['y'],
                                'floor': floor,
                                'dataset_location': node_data.get('dataset_location'),
                                'distance_meters': -1
                            }
                        elif node_data.get('dataset_location') and fallback_node is None:
                            fallback_node = {
                                'node_id': nid,
                                'x': node_data['x'],
                                'y': node_data['y'],
                                'floor': floor,
                                'dataset_location': node_data.get('dataset_location'),
                                'distance_meters': -1
                            }
                    
                    node_lat = node_data.get('latitude')
                    node_lng = node_data.get('longitude')
                    
                    if node_lat is None or node_lng is None:
                        continue
                    
                    nodes_with_gps += 1
                    
                    # Calculate Haversine distance
                    R = 6371000  # Earth radius in meters
                    
                    lat1 = radians(latitude)
                    lat2 = radians(node_lat)
                    dlat = radians(node_lat - latitude)
                    dlng = radians(node_lng - longitude)
                    
                    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
                    c = 2 * atan2(sqrt(a), sqrt(1-a))
                    distance = R * c
                    
                    if distance < min_distance:
                        min_distance = distance
                        nearest_node = {
                            'node_id': nid,
                            'x': node_data['x'],
                            'y': node_data['y'],
                            'floor': floor,
                            'dataset_location': node_data.get('dataset_location'),
                            'distance_meters': round(distance, 2)
                        }
            
            print(f"📊 Summary: Checked {total_nodes_checked} nodes, found {nodes_with_gps} with GPS", flush=True)
            
            # If no GPS-mapped nodes found, use fallback node so the app still works
            if not nearest_node:
                if fallback_node:
                    print(f"⚠️ No GPS nodes found, using fallback node: {fallback_node['node_id']}", flush=True)
                    nearest_node = fallback_node
                else:
                    print("❌ No nodes found at all in any graph", flush=True)
                    return jsonify({'error': 'No nodes available in graph'}), 404
            
            prediction = nearest_node['dataset_location'] or 'Corridor'
            print(f"📍 GPS prediction: {prediction} at node {nearest_node['node_id']} ({nearest_node['distance_meters']}m away)", flush=True)
            
            response = {
                'predicted': prediction,
                'source': 'gps_based',
                'is_navigable': nearest_node['dataset_location'] is not None,
                'node_id': nearest_node['node_id'],
                'node_x': nearest_node['x'],
                'node_y': nearest_node['y'],
                'floor': nearest_node['floor'],
                'distance_meters': nearest_node['distance_meters']
            }
            
            print(f"✅ Sending GPS response: {response}", flush=True)
            return jsonify([response])
        
        else:
            # WiFi-based prediction (original logic)
            num_scans = len(data) if isinstance(data, list) else 1
            print(f"📥 API: Received WiFi location request with {num_scans} Access Points", flush=True)
            
            bssid_to_signal = {}
            if isinstance(data, list):
                for scan in data:
                    bssid = str(scan.get('BSSID', scan.get('bssid', ''))).strip().lower()
                    rssi = scan.get('Signal Strength dBm', scan.get('rssi', -100))
                    bssid_to_signal[bssid] = rssi
                    print(f"  📡 BSSID: {bssid}, RSSI: {rssi}", flush=True)
            else:
                print("❌ Expected list of scans, got something else", flush=True)
                return jsonify({'error': 'Expected list of scans'}), 400

            print(f"🔮 Calling model_service.predict with {len(bssid_to_signal)} BSSIDs", flush=True)
            prediction = model_service.predict(bssid_to_signal)
            
            if prediction is None:
                print("❌ Model returned None - model not loaded or internal error", flush=True)
                return jsonify({'error': 'Model not loaded or internal error'}), 500

            print(f"📡 SERVER: WiFi prediction made for {prediction}", flush=True)
        
        # Check if predicted location is mapped to a graph node
        is_navigable = False
        node_id = None
        node_x = None
        node_y = None
        floor = None
        default_node_x = None
        default_node_y = None
        
        # Try to find which floor this location is on
        training_record = db.training_data_records.find_one({'location': prediction})
        if training_record:
            floor = training_record.get('floor')
            print(f"📍 Found training record for {prediction} on floor {floor}", flush=True)
            
            # Check if it's mapped to a node
            if floor:
                graph = pathfinding_service.build_graph(floor)
                if graph:
                    print(f"📊 Graph loaded with {len(graph['nodes'])} nodes", flush=True)
                    for nid, node_data in graph['nodes'].items():
                        if node_data.get('dataset_location') == prediction:
                            is_navigable = True
                            node_id = nid
                            node_x = node_data['x']
                            node_y = node_data['y']
                            print(f"✅ Location {prediction} is navigable at node {node_id}", flush=True)
                            break
                    
                    # If not navigable, get default node for fallback marker
                    if not is_navigable:
                        print(f"⚠️ Location {prediction} is not mapped to any node", flush=True)
                        default_node = pathfinding_service.get_default_node(floor)
                        if default_node:
                            default_node_x = default_node['x']
                            default_node_y = default_node['y']
                            print(f"📍 Using default node at ({default_node_x}, {default_node_y})", flush=True)
                else:
                    print(f"⚠️ No graph found for floor {floor}", flush=True)
        else:
            print(f"⚠️ No training record found for location: {prediction}", flush=True)
        
        response = {
            'predicted': prediction,
            'source': 'flask_server',
            'is_navigable': is_navigable,
            'node_id': node_id,
            'node_x': node_x,
            'node_y': node_y,
            'floor': floor
        }
        
        # Add default node coordinates if location is not navigable
        if not is_navigable and default_node_x is not None:
            response['default_node_x'] = default_node_x
            response['default_node_y'] = default_node_y
        
        print(f"✅ Sending response: {response}", flush=True)
        return jsonify([response])
    except Exception as e:
        print(f"❌ SERVER ERROR: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@api_bp.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200


# =====================
# TRAINING DATA ROUTES
# =====================
@api_bp.route('/admin/training-data', methods=['POST'])
def add_training_data():
    """
    Add new WiFi training data. Expects JSON:
    {
        "location": "Room Name",
        "landmark": "Near something",
        "floor": "ground floor",
        "scans": [
            {
                "ssid": "KcN",
                "bssid": "54:07:7d:40:74:88",
                "frequency": 2462,
                "bandwidth": 20,
                "signal_strength": -48,
                "estimated_distance": 2.43,
                "capabilities": "[WPA2-PSK...]"
            },
            ...
        ]
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        location = data.get('location', '').strip()
        landmark = data.get('landmark', '').strip()
        floor = data.get('floor', '').strip()
        scans = data.get('scans', [])

        if not location:
            return jsonify({'error': 'Location is required'}), 400
        if not scans:
            return jsonify({'error': 'At least one WiFi scan is required'}), 400

        # Build CSV rows
        rows = []
        for scan in scans:
            rows.append({
                'SSID': scan.get('ssid', ''),
                'Location': location,
                'Landmark': landmark,
                'Floor': floor,
                'BSSID': scan.get('bssid', ''),
                'Frequency (MHz)': scan.get('frequency', ''),
                'Bandwidth (MHz)': scan.get('bandwidth', ''),
                'Signal Strength dBm': scan.get('signal_strength', ''),
                'Estimated Distance m': scan.get('estimated_distance', ''),
                'Capabilities': scan.get('capabilities', '')
            })

        count = training_service.append_training_data(rows)
        print(f"📝 TRAINING DATA: Added {count} rows for location '{location}'", flush=True)

        # Trigger async retrain
        training_service.retrain_async()

        return jsonify({
            'success': True,
            'rows_added': count,
            'message': f'{count} WiFi scans added for "{location}". Model retraining started.'
        })

    except Exception as e:
        print(f"❌ TRAINING DATA ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/retrain', methods=['POST'])
def retrain_model():
    """Manually trigger model retraining."""
    try:
        training_service.retrain_async()
        return jsonify({
            'success': True,
            'message': 'Model retraining started in background'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-stats', methods=['GET'])
def training_stats():
    """Get stats about the training data from MongoDB."""
    try:
        training_collection = db['training_data_records']
        
        # Get total count
        total_rows = training_collection.count_documents({})
        
        # Get unique locations
        locations = training_collection.distinct('location')
        total_locations = len(locations)
        
        # Get unique BSSIDs
        bssids = training_collection.distinct('bssid')
        total_bssids = len(bssids)

        return jsonify({
            'total_rows': total_rows,
            'total_locations': total_locations,
            'total_bssids': total_bssids,
            'locations': locations
        })
    except Exception as e:
        print(f"Error fetching training stats: {e}")
        return jsonify({'error': str(e)}), 500


# =====================
# ADMIN MAP ROUTES
# =====================
@api_bp.route('/admin/upload_map/<floor>', methods=['POST'])
def upload_map(floor):
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    try:
        file_bytes = file.read()
        output_io, (width, height), new_locations = process_map_image(file_bytes, floor)

        if output_io is None:
            return jsonify({'error': 'Invalid image format'}), 400

        db.maps.delete_many({'floor': floor})
        file_id = fs.put(output_io, filename=f"map_floor_{floor}.webp")
        db.maps.insert_one({'floor': floor, 'file_id': file_id, 'width': width, 'height': height})
        
        db.locations.delete_many({'floor': floor})
        if new_locations:
            db.locations.insert_many(new_locations)

        return jsonify({'success': True, 'rooms_detected': len(new_locations)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@api_bp.route('/admin/map_base64/<floor>', methods=['GET'])
def get_map_base64(floor='1'):
    map_doc = db.maps.find_one({'floor': floor})
    if not map_doc: return jsonify({'error': 'Map not found'}), 404
    grid_out = fs.get(map_doc['file_id'])
    encoded_string = base64.b64encode(grid_out.read()).decode('utf-8')
    return jsonify({'base64': encoded_string})

@api_bp.route('/admin/map_image/<floor>', methods=['GET'])
def get_map_image(floor='1'):
    map_doc = db.maps.find_one({'floor': floor})
    if not map_doc: return jsonify({'error': 'Map not found'}), 404
    grid_out = fs.get(map_doc['file_id'])
    return send_file(BytesIO(grid_out.read()), mimetype='image/png')

@api_bp.route('/admin/testdata', methods=['GET'])
def get_test_data():
    try:
        rows = read_test_csv('test.csv')
        return jsonify(rows)
    except FileNotFoundError:
        return jsonify({'error': 'test.csv not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# =====================
# TRAINING RECORDS CRUD (MongoDB)
# =====================
@api_bp.route('/admin/training-records', methods=['GET'])
def get_training_records():
    """Get paginated training records with filters"""
    try:
        floor = request.args.get('floor', type=int)
        location = request.args.get('location')
        source = request.args.get('source')  # 'train' or 'test'
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 50, type=int)
        
        query = {}
        if floor:
            query['floor'] = floor  # Floor is stored as int in training_data_records
        if location:
            query['location'] = {'$regex': location, '$options': 'i'}
        if source:
            query['source'] = source
        
        skip = (page - 1) * limit
        total = db.training_data_records.count_documents(query)
        records = list(db.training_data_records.find(query).skip(skip).limit(limit).sort('_id', -1))
        
        # Convert ObjectId to string
        for record in records:
            record['_id'] = str(record['_id'])
        
        return jsonify({
            'records': records,
            'total': total,
            'page': page,
            'limit': limit,
            'pages': (total + limit - 1) // limit,
            'filters': {'floor': floor, 'location': location, 'source': source}
        })
    except Exception as e:
        print(f"❌ GET TRAINING RECORDS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/grouped', methods=['GET'])
def get_training_records_grouped():
    """Get training records grouped by location"""
    try:
        floor = request.args.get('floor', type=int)
        
        match_stage = {}
        if floor:
            match_stage['floor'] = floor  # Floor is stored as int
        
        pipeline = [
            {'$match': match_stage} if match_stage else {'$match': {}},
            {'$group': {
                '_id': {'location': '$location', 'floor': '$floor'},
                'count': {'$sum': 1},
                'bssids': {'$addToSet': '$bssid'},
                'avg_signal': {'$avg': '$signal'},
                'records': {'$push': {
                    'id': {'$toString': '$_id'},
                    'bssid': '$bssid',
                    'ssid': '$ssid',
                    'signal_strength': '$signal',
                    'landmark': '$landmark',
                    'source': '$source'
                }}
            }},
            {'$sort': {'_id.floor': 1, '_id.location': 1}}
        ]
        
        results = list(db.training_data_records.aggregate(pipeline))
        
        grouped = {}
        for item in results:
            key = f"{item['_id']['location']} (Floor {item['_id']['floor']})"
            grouped[key] = {
                'location': item['_id']['location'],
                'floor': item['_id']['floor'],
                'count': item['count'],
                'bssids': item['bssids'],
                'bssid_count': len(item['bssids']),
                'avg_signal': round(item['avg_signal'], 2) if item['avg_signal'] else 0,
                'records': item['records'][:10]  # Limit to first 10 for preview
            }
        
        return jsonify(grouped)
    except Exception as e:
        print(f"❌ GET GROUPED RECORDS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/locations', methods=['GET'])
def get_training_locations():
    """Get distinct locations with counts"""
    try:
        pipeline = [
            {'$group': {
                '_id': {'location': '$location', 'floor': '$floor'},
                'count': {'$sum': 1}
            }},
            {'$sort': {'_id.floor': 1, '_id.location': 1}}
        ]
        
        results = list(db.training_data_records.aggregate(pipeline))
        locations = [
            {
                'location': item['_id']['location'],
                'floor': item['_id']['floor'],
                'count': item['count']
            }
            for item in results
        ]
        
        return jsonify(locations)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records', methods=['POST'])
def add_training_record():
    """Add single training record"""
    try:
        from datetime import datetime
        data = request.get_json()
        
        record = {
            'ssid': data.get('ssid', ''),
            'bssid': data.get('bssid', '').lower(),
            'signal_strength': int(data.get('signal_strength', -100)),
            'location': data.get('location', ''),
            'landmark': data.get('landmark', ''),
            'floor': int(data.get('floor', 1)),
            'frequency': int(data.get('frequency', 0)),
            'bandwidth': int(data.get('bandwidth', 20)),
            'estimated_distance': float(data.get('estimated_distance', 0)),
            'capabilities': data.get('capabilities', ''),
            'source': data.get('source', 'manual'),
            'collected_at': datetime.utcnow(),
            'created_at': datetime.utcnow()
        }
        
        result = db.training_data_records.insert_one(record)
        return jsonify({'success': True, 'id': str(result.inserted_id)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/bulk', methods=['POST'])
def add_training_records_bulk():
    """Bulk insert training records"""
    try:
        from datetime import datetime
        data = request.get_json()
        records = data.get('records', [])
        
        if not records:
            return jsonify({'error': 'No records provided'}), 400
        
        for record in records:
            record['collected_at'] = datetime.utcnow()
            record['created_at'] = datetime.utcnow()
            if 'bssid' in record:
                record['bssid'] = record['bssid'].lower()
        
        result = db.training_data_records.insert_many(records)
        return jsonify({'success': True, 'count': len(result.inserted_ids)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/<record_id>', methods=['PUT'])
def update_training_record(record_id):
    """Update single training record"""
    try:
        data = request.get_json()
        updates = {}
        
        allowed_fields = ['ssid', 'bssid', 'signal', 'location', 'landmark', 'floor', 'source']
        for field in allowed_fields:
            if field in data:
                updates[field] = data[field]
        
        if 'bssid' in updates:
            updates['bssid'] = updates['bssid'].lower()
        
        result = db.training_data_records.update_one(
            {'_id': ObjectId(record_id)},
            {'$set': updates}
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Record not found'}), 404
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/bulk', methods=['PUT'])
def update_training_records_bulk():
    """Bulk update training records"""
    try:
        data = request.get_json()
        ids = data.get('ids', [])
        updates = data.get('updates', {})
        
        if not ids or not updates:
            return jsonify({'error': 'IDs and updates required'}), 400
        
        object_ids = [ObjectId(id) for id in ids]
        result = db.training_data_records.update_many(
            {'_id': {'$in': object_ids}},
            {'$set': updates}
        )
        
        return jsonify({'success': True, 'modified': result.modified_count})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/<record_id>', methods=['DELETE'])
def delete_training_record(record_id):
    """Delete single training record"""
    try:
        result = db.training_data_records.delete_one({'_id': ObjectId(record_id)})
        
        if result.deleted_count == 0:
            return jsonify({'error': 'Record not found'}), 404
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/bulk', methods=['DELETE'])
def delete_training_records_bulk():
    """Bulk delete training records"""
    try:
        data = request.get_json()
        ids = data.get('ids', [])
        
        if not ids:
            return jsonify({'error': 'No IDs provided'}), 400
        
        object_ids = [ObjectId(id) for id in ids]
        result = db.training_data_records.delete_many({'_id': {'$in': object_ids}})
        
        return jsonify({'success': True, 'deleted': result.deleted_count})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/group/<location>', methods=['DELETE'])
def delete_training_records_by_group(location):
    """Delete all records for a location+floor"""
    try:
        floor = request.args.get('floor', type=int)
        
        query = {'location': location}
        if floor:
            query['floor'] = floor  # Floor is stored as int
        
        result = db.training_data_records.delete_many(query)
        return jsonify({'success': True, 'deleted': result.deleted_count})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/merge', methods=['POST'])
def merge_training_locations():
    """Merge multiple locations into one"""
    try:
        data = request.get_json()
        source_locations = data.get('source_locations', [])
        target_location = data.get('target_location', '')
        floor = data.get('floor')
        delete_sources = data.get('delete_sources', True)
        
        if not source_locations or not target_location:
            return jsonify({'error': 'Source and target locations required'}), 400
        
        query = {'location': {'$in': source_locations}}
        if floor:
            query['floor'] = floor  # Floor is stored as int
        
        # Update all matching records
        result = db.training_data_records.update_many(
            query,
            {'$set': {'location': target_location}}
        )
        
        return jsonify({
            'success': True,
            'merged': result.modified_count,
            'target': target_location
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-records/export', methods=['GET'])
def export_training_records():
    """Export training records as CSV"""
    try:
        import csv
        from io import StringIO
        
        floor = request.args.get('floor', type=int)
        source = request.args.get('source')
        
        query = {}
        if floor:
            query['floor'] = floor  # Floor is stored as int
        if source:
            query['source'] = source
        
        records = list(db.training_data_records.find(query))
        
        if not records:
            return jsonify({'error': 'No records found'}), 404
        
        # Create CSV
        output = StringIO()
        fieldnames = ['SSID', 'Location', 'Landmark', 'Floor', 'BSSID', 
                     'Frequency (MHz)', 'Bandwidth (MHz)', 'Signal Strength dBm',
                     'Estimated Distance m', 'Capabilities', 'Source']
        
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        
        for record in records:
            writer.writerow({
                'SSID': record.get('ssid', ''),
                'Location': record.get('location', ''),
                'Landmark': record.get('landmark', ''),
                'Floor': record.get('floor', ''),
                'BSSID': record.get('bssid', ''),
                'Frequency (MHz)': record.get('frequency', ''),
                'Bandwidth (MHz)': record.get('bandwidth', ''),
                'Signal Strength dBm': record.get('signal', ''),
                'Estimated Distance m': record.get('estimated_distance', ''),
                'Capabilities': record.get('capabilities', ''),
                'Source': record.get('source', '')
            })
        
        output.seek(0)
        return send_file(
            BytesIO(output.getvalue().encode('utf-8')),
            mimetype='text/csv',
            as_attachment=True,
            download_name=f'training_data_floor_{floor or "all"}.csv'
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# =====================
# WALKABLE GRAPH ROUTES
# =====================
@api_bp.route('/admin/graph/<int:floor>', methods=['GET'])
def get_walkable_graph(floor):
    """Get walkable graph (nodes + edges) for a floor"""
    try:
        graph_doc = db.walkable_graph.find_one({'floor': floor})
        if not graph_doc:
            return jsonify({
                'floor': floor,
                'nodes': [],
                'edges': [],
                'exists': False
            })
        
        # Convert ObjectId to string
        graph_doc['_id'] = str(graph_doc['_id'])
        graph_doc['exists'] = True
        
        return jsonify(graph_doc)
    except Exception as e:
        print(f"❌ GET GRAPH ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/graph/<int:floor>', methods=['POST'])
def save_walkable_graph(floor):
    """
    Save or update walkable graph for a floor
    Validates uniqueness rules:
    - Only one node per floor can have is_default=true
    - Only one node per floor can have any given dataset_location
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        nodes = data.get('nodes', [])
        edges = data.get('edges', [])
        
        result = pathfinding_service.save_graph(floor, nodes, edges)
        
        if result['success']:
            print(f"✅ GRAPH SAVED: Floor {floor} - {len(nodes)} nodes, {len(edges)} edges")
            return jsonify(result)
        else:
            print(f"❌ GRAPH VALIDATION FAILED: {result['errors']}")
            return jsonify(result), 400
            
    except Exception as e:
        print(f"❌ SAVE GRAPH ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/graph/<int:floor>', methods=['DELETE'])
def delete_walkable_graph(floor):
    """Delete walkable graph for a floor"""
    try:
        success = pathfinding_service.delete_graph(floor)
        
        if success:
            print(f"🗑️ GRAPH DELETED: Floor {floor}")
            return jsonify({'success': True, 'message': f'Graph deleted for floor {floor}'})
        else:
            return jsonify({'error': 'Failed to delete graph'}), 500
            
    except Exception as e:
        print(f"❌ DELETE GRAPH ERROR: {e}")
        return jsonify({'error': str(e)}), 500


# =====================
# PATHFINDING ROUTES
# =====================
@api_bp.route('/navigation/path', methods=['POST'])
def calculate_navigation_path():
    """
    Calculate shortest path between two locations using Dijkstra's algorithm
    Body: {
        "floor": 1,
        "from_location": "Room 101",
        "to_location": "Room 202"
    }
    Returns: {
        "path_nodes": [{"x": 0.34, "y": 0.56}, ...],
        "total_distance": 12.4,
        "estimated_seconds": 45,
        "found": true
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        floor = data.get('floor', 1)
        from_location = data.get('from_location', '').strip()
        to_location = data.get('to_location', '').strip()
        
        if not from_location or not to_location:
            return jsonify({'error': 'from_location and to_location required'}), 400
        
        print(f"🗺️ PATHFINDING: Floor {floor}, {from_location} → {to_location}")
        
        result = pathfinding_service.calculate_path(floor, from_location, to_location)
        
        if result['found']:
            print(f"✅ PATH FOUND: {len(result['path_nodes'])} nodes, {result['total_distance']:.2f} distance")
        else:
            print(f"❌ NO PATH: {result.get('error', 'Unknown error')}")
        
        return jsonify(result)
        
    except Exception as e:
        print(f"❌ PATHFINDING ERROR: {e}")
        return jsonify({
            'path_nodes': [],
            'total_distance': 0,
            'estimated_seconds': 0,
            'found': False,
            'error': str(e)
        }), 500


# =====================
# NAVIGATION NODE ROUTES (Replaces locations collection)
# =====================
@api_bp.route('/navigation/nodes/<int:floor>', methods=['GET'])
def get_navigable_nodes_for_floor(floor):
    """
    Get only nodes that have dataset_location set (navigable destinations) for a specific floor
    Replaces GET /admin/locations/{floor}
    Returns: [{
        'node_id': str,
        'location_name': str,
        'x': float,
        'y': float,
        'floor': int,
        'is_default': bool,
        'record_count': int
    }]
    """
    try:
        nodes = pathfinding_service.get_navigable_nodes(floor)
        print(f"🗺️ NAVIGABLE NODES: Floor {floor} - {len(nodes)} nodes")
        return jsonify(nodes)
    except Exception as e:
        print(f"❌ GET NAVIGABLE NODES ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/navigation/nodes/all', methods=['GET'])
def get_all_navigable_nodes():
    """
    Get only nodes that have dataset_location set (navigable destinations) across all floors
    Used by map screen search
    Returns: [{
        'node_id': str,
        'location_name': str,
        'x': float,
        'y': float,
        'floor': int,
        'is_default': bool,
        'record_count': int
    }]
    """
    try:
        nodes = pathfinding_service.get_navigable_nodes()
        print(f"🗺️ ALL NAVIGABLE NODES: {len(nodes)} nodes across all floors")
        return jsonify(nodes)
    except Exception as e:
        print(f"❌ GET ALL NAVIGABLE NODES ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/navigation/default/<int:floor>', methods=['GET'])
def get_default_node_for_floor(floor):
    """
    Get the default node for a floor (node with is_default=true)
    Used as fallback marker position when WiFi predicts unmapped location
    Returns: {'node_id': str, 'x': float, 'y': float, 'floor': int} or null
    """
    try:
        default_node = pathfinding_service.get_default_node(floor)
        print(f"🎯 DEFAULT NODE: Floor {floor} - {default_node}")
        return jsonify(default_node)
    except Exception as e:
        print(f"❌ GET DEFAULT NODE ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/node-data/<int:floor>', methods=['GET'])
def get_node_data_groups(floor):
    """
    Get WiFi data groups linked to each named node on a floor
    Used by location marking screen to show which nodes have training data
    Returns: [{
        'node_id': str,
        'location_name': str,
        'x': float,
        'y': float,
        'is_default': bool,
        'wifi_groups': [{'bssid': str, 'record_count': int, 'avg_signal': float}],
        'total_records': int
    }]
    """
    try:
        node_data = pathfinding_service.get_node_data_groups(floor)
        print(f"📊 NODE DATA GROUPS: Floor {floor} - {len(node_data)} nodes with data")
        return jsonify(node_data)
    except Exception as e:
        print(f"❌ GET NODE DATA GROUPS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


# =====================
# DATASET LOCATION MAPPING ROUTES
# =====================
@api_bp.route('/admin/dataset-locations/<int:floor>', methods=['GET'])
def get_dataset_locations(floor):
    """
    Get all distinct dataset locations for a floor with assignment status
    Returns: [{
        'location': str,
        'floor': int,
        'record_count': int,
        'assigned_node_id': str or None,
        'is_assigned': bool
    }]
    """
    try:
        locations = pathfinding_service.get_dataset_locations(floor)
        print(f"📊 DATASET LOCATIONS: Floor {floor} - {len(locations)} locations")
        return jsonify(locations)
    except Exception as e:
        print(f"❌ GET DATASET LOCATIONS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/graph/<int:floor>/node/<node_id>/assign-location', methods=['PUT'])
def assign_dataset_location_to_node(floor, node_id):
    """
    Assign a dataset location to a node
    Body: {'dataset_location': 'Room 101'}
    Ensures uniqueness: only one node per floor can have a given dataset_location
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        dataset_location = data.get('dataset_location', '').strip()
        if not dataset_location:
            return jsonify({'error': 'dataset_location required'}), 400
        
        result = pathfinding_service.assign_dataset_location(floor, node_id, dataset_location)
        
        if result['success']:
            print(f"✅ ASSIGNED: {dataset_location} → Node {node_id} (Floor {floor})")
            if result['previous_node_id']:
                print(f"   Unassigned from: {result['previous_node_id']}")
        else:
            print(f"❌ ASSIGN FAILED: {result['message']}")
        
        return jsonify(result)
        
    except Exception as e:
        print(f"❌ ASSIGN LOCATION ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/graph/<int:floor>/node/<node_id>/unassign-location', methods=['PUT'])
def unassign_dataset_location_from_node(floor, node_id):
    """Remove dataset_location assignment from a node"""
    try:
        result = pathfinding_service.unassign_dataset_location(floor, node_id)
        
        if result['success']:
            print(f"✅ UNASSIGNED: Node {node_id} (Floor {floor})")
        else:
            print(f"❌ UNASSIGN FAILED: {result['message']}")
        
        return jsonify(result)
        
    except Exception as e:
        print(f"❌ UNASSIGN LOCATION ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/navigation/locations/<int:floor>', methods=['GET'])
def get_navigable_locations_for_floor(floor):
    """
    Get only nodes that have dataset_location set (navigable destinations) for a specific floor
    Returns: [{
        'location_name': str,
        'node_id': str,
        'x': float,
        'y': float,
        'floor': int,
        'record_count': int
    }]
    """
    try:
        locations = pathfinding_service.get_navigable_locations(floor)
        print(f"🗺️ NAVIGABLE LOCATIONS: Floor {floor} - {len(locations)} locations")
        return jsonify(locations)
    except Exception as e:
        print(f"❌ GET NAVIGABLE LOCATIONS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/navigation/locations/all', methods=['GET'])
def get_all_navigable_locations():
    """
    Get only nodes that have dataset_location set (navigable destinations) across all floors
    Returns: [{
        'location_name': str,
        'node_id': str,
        'x': float,
        'y': float,
        'floor': int,
        'record_count': int
    }]
    """
    try:
        locations = pathfinding_service.get_navigable_locations()
        print(f"🗺️ ALL NAVIGABLE LOCATIONS: {len(locations)} locations across all floors")
        return jsonify(locations)
    except Exception as e:
        print(f"❌ GET ALL NAVIGABLE LOCATIONS ERROR: {e}")
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/test_location', methods=['POST'])
def test_location():
    """
    Test location prediction using WiFi or GPS
    
    Request body:
    {
        "mode": "wifi" | "gps",
        "wifi_data": [...],  // Required if mode=wifi
        "latitude": float,   // Required if mode=gps
        "longitude": float   // Required if mode=gps
    }
    
    Response:
    {
        "mode": "wifi" | "gps",
        "predicted_location": str,
        "node_id": str,
        "floor": int,
        "x": float,
        "y": float,
        "confidence": str,
        "distance_meters": float  // Only for GPS mode
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        mode = data.get('mode', '').lower()
        
        if mode == 'wifi':
            # WiFi-based prediction
            wifi_data = data.get('wifi_data', [])
            if not wifi_data:
                return jsonify({'error': 'wifi_data is required for WiFi mode'}), 400
            
            print(f"📡 Testing WiFi location with {len(wifi_data)} access points", flush=True)
            
            # Build BSSID to signal map
            bssid_to_signal = {}
            for scan in wifi_data:
                bssid = str(scan.get('BSSID', scan.get('bssid', ''))).strip().lower()
                rssi = scan.get('Signal Strength dBm', scan.get('rssi', -100))
                bssid_to_signal[bssid] = rssi
            
            # Get prediction from model
            prediction = model_service.predict(bssid_to_signal)
            
            if prediction is None:
                return jsonify({'error': 'Model prediction failed'}), 500
            
            # Find the node for this location
            training_record = db.training_data_records.find_one({'location': prediction})
            if not training_record:
                return jsonify({
                    'mode': 'wifi',
                    'predicted_location': prediction,
                    'error': 'Location not found in training data'
                }), 404
            
            floor = training_record.get('floor')
            graph = pathfinding_service.build_graph(floor)
            
            if not graph:
                return jsonify({
                    'mode': 'wifi',
                    'predicted_location': prediction,
                    'floor': floor,
                    'error': 'No graph found for this floor'
                }), 404
            
            # Find node with this dataset_location
            node_found = None
            for nid, node_data in graph['nodes'].items():
                if node_data.get('dataset_location') == prediction:
                    node_found = {
                        'node_id': nid,
                        'x': node_data['x'],
                        'y': node_data['y'],
                        'floor': floor
                    }
                    break
            
            if not node_found:
                return jsonify({
                    'mode': 'wifi',
                    'predicted_location': prediction,
                    'floor': floor,
                    'error': 'Location not mapped to any node'
                }), 404
            
            print(f"✅ WiFi prediction: {prediction} at node {node_found['node_id']}", flush=True)
            
            return jsonify({
                'mode': 'wifi',
                'predicted_location': prediction,
                'node_id': node_found['node_id'],
                'floor': node_found['floor'],
                'x': node_found['x'],
                'y': node_found['y'],
                'confidence': 'model_based'
            })
        
        elif mode == 'gps':
            # GPS-based nearest node finding
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            
            if latitude is None or longitude is None:
                return jsonify({'error': 'latitude and longitude are required for GPS mode'}), 400
            
            print(f"📍 Testing GPS location: ({latitude}, {longitude})", flush=True)
            
            # Find nearest node with GPS coordinates across all floors
            nearest_node = None
            min_distance = float('inf')
            
            for floor in [1, 2, 3]:
                graph = pathfinding_service.build_graph(floor)
                if not graph:
                    continue
                
                for nid, node_data in graph['nodes'].items():
                    node_lat = node_data.get('latitude')
                    node_lng = node_data.get('longitude')
                    
                    if node_lat is None or node_lng is None:
                        continue
                    
                    # Calculate Haversine distance
                    from math import radians, sin, cos, sqrt, atan2
                    
                    R = 6371000  # Earth radius in meters
                    
                    lat1 = radians(latitude)
                    lat2 = radians(node_lat)
                    dlat = radians(node_lat - latitude)
                    dlng = radians(node_lng - longitude)
                    
                    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
                    c = 2 * atan2(sqrt(a), sqrt(1-a))
                    distance = R * c
                    
                    if distance < min_distance:
                        min_distance = distance
                        nearest_node = {
                            'node_id': nid,
                            'x': node_data['x'],
                            'y': node_data['y'],
                            'floor': floor,
                            'latitude': node_lat,
                            'longitude': node_lng,
                            'dataset_location': node_data.get('dataset_location'),
                            'distance_meters': round(distance, 2)
                        }
            
            if not nearest_node:
                return jsonify({
                    'mode': 'gps',
                    'error': 'No nodes with GPS coordinates found'
                }), 404
            
            print(f"✅ GPS nearest node: {nearest_node['node_id']} at {nearest_node['distance_meters']}m", flush=True)
            
            return jsonify({
                'mode': 'gps',
                'predicted_location': nearest_node['dataset_location'] or 'Corridor',
                'node_id': nearest_node['node_id'],
                'floor': nearest_node['floor'],
                'x': nearest_node['x'],
                'y': nearest_node['y'],
                'distance_meters': nearest_node['distance_meters'],
                'confidence': 'gps_based'
            })
        
        else:
            return jsonify({'error': 'Invalid mode. Use "wifi" or "gps"'}), 400
    
    except Exception as e:
        print(f"❌ TEST LOCATION ERROR: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/location_mode', methods=['GET'])
def get_location_mode():
    """
    Get the current location prediction mode (wifi or gps)
    
    Response:
    {
        "mode": "wifi" | "gps"
    }
    """
    try:
        settings = db.app_settings.find_one({'key': 'location_mode'})
        mode = settings['value'] if settings else 'wifi'  # Default to wifi
        print(f"📡 Current location mode: {mode}", flush=True)
        return jsonify({'mode': mode})
    except Exception as e:
        print(f"❌ GET LOCATION MODE ERROR: {e}", flush=True)
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/location_mode', methods=['POST'])
def set_location_mode():
    """
    Set the location prediction mode (wifi or gps)
    
    Request body:
    {
        "mode": "wifi" | "gps"
    }
    
    Response:
    {
        "success": true,
        "mode": "wifi" | "gps"
    }
    """
    try:
        data = request.get_json()
        if not data or 'mode' not in data:
            return jsonify({'error': 'mode is required'}), 400
        
        mode = data['mode'].lower()
        if mode not in ['wifi', 'gps']:
            return jsonify({'error': 'mode must be "wifi" or "gps"'}), 400
        
        # Update or insert the setting
        db.app_settings.update_one(
            {'key': 'location_mode'},
            {'$set': {'key': 'location_mode', 'value': mode}},
            upsert=True
        )
        
        print(f"✅ Location mode set to: {mode}", flush=True)
        return jsonify({'success': True, 'mode': mode})
    except Exception as e:
        print(f"❌ SET LOCATION MODE ERROR: {e}", flush=True)
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/debug_gps_nodes', methods=['GET'])
def debug_gps_nodes():
    """Debug endpoint to check if GPS nodes are being loaded"""
    try:
        result = []
        for floor in [1, 2, 3]:
            graph = pathfinding_service.build_graph(floor)
            if not graph:
                continue
            
            for nid, node_data in graph['nodes'].items():
                if node_data.get('latitude') is not None and node_data.get('longitude') is not None:
                    result.append({
                        'floor': floor,
                        'node_id': nid,
                        'latitude': node_data.get('latitude'),
                        'longitude': node_data.get('longitude'),
                        'dataset_location': node_data.get('dataset_location'),
                        'x': node_data.get('x'),
                        'y': node_data.get('y')
                    })
        
        return jsonify({
            'total_gps_nodes': len(result),
            'nodes': result
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
