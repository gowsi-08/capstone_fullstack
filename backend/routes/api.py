from flask import Blueprint, request, jsonify, send_file
from services.database import db, fs
from services.model_service import model_service
from services.auth_service import auth_service
from services.training_service import training_service
from utils.image_processing import process_map_image
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
@api_bp.route('/getlocation', methods=['POST'])
def get_prediction():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        num_scans = len(data) if isinstance(data, list) else 1
        print(f"📥 API: Received /getlocation request with {num_scans} Access Points", flush=True)
        
        bssid_to_signal = {}
        if isinstance(data, list):
            for scan in data:
                bssid = str(scan.get('BSSID', scan.get('bssid', ''))).strip().lower()
                rssi = scan.get('Signal Strength dBm', scan.get('rssi', -100))
                bssid_to_signal[bssid] = rssi
        else:
            return jsonify({'error': 'Expected list of scans'}), 400

        prediction = model_service.predict(bssid_to_signal)
        if prediction is None:
            return jsonify({'error': 'Model not loaded or internal error'}), 500

        print(f"📡 SERVER: Prediction made for {prediction}", flush=True)
        return jsonify([{
            'predicted': prediction,
            'source': 'flask_server'
        }])
    except Exception as e:
        print(f"❌ SERVER ERROR: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/locations/all', methods=['GET'])
def get_all_locations():
    try:
        locs = list(db.locations.find({}, {'_id': 0}))
        return jsonify(locs)
    except Exception as e:
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

        # Build MongoDB documents
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
    """Get stats about the training data."""
    try:
        import pandas as pd

        data = list(db.wifi_training_data.find({}, {'_id': 0}))
        if not data:
            return jsonify({'error': 'No training data found in database'}), 404

        df = pd.DataFrame(data)
        locations = df['Location'].unique().tolist() if 'Location' in df.columns else []
        total_rows = len(df)
        total_bssids = df['BSSID'].nunique() if 'BSSID' in df.columns else 0

        return jsonify({
            'total_rows': total_rows,
            'total_locations': len(locations),
            'total_bssids': total_bssids,
            'locations': locations
        })
    except Exception as e:
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

@api_bp.route('/admin/locations/<floor>', methods=['GET'])
def get_locations(floor='1'):
    locs = list(db.locations.find({'floor': floor}))
    return jsonify([{'id': str(loc['_id']), 'name': loc['name'], 'x': loc['x'], 'y': loc['y']} for loc in locs])

@api_bp.route('/admin/locations/<floor>', methods=['POST'])
def save_locations(floor='1'):
    data = request.get_json()
    db.locations.delete_many({'floor': floor})
    for loc in data:
        db.locations.insert_one({'floor': floor, 'name': loc['name'], 'x': loc['x'], 'y': loc['y']})
    return jsonify({'success': True})

@api_bp.route('/admin/map_image/<floor>', methods=['GET'])
def get_map_image(floor='1'):
    map_doc = db.maps.find_one({'floor': floor})
    if not map_doc: return jsonify({'error': 'Map not found'}), 404
    grid_out = fs.get(map_doc['file_id'])
    return send_file(BytesIO(grid_out.read()), mimetype='image/png')

@api_bp.route('/admin/location/<loc_id>', methods=['PUT'])
def edit_location(loc_id):
    data = request.get_json()
    result = db.locations.update_one(
        {'_id': ObjectId(loc_id)},
        {'$set': {'name': data.get('name'), 'x': data.get('x'), 'y': data.get('y')}}
    )
    if result.matched_count == 0: return jsonify({'error': 'Location not found'}), 404
    return jsonify({'success': True})

@api_bp.route('/admin/location/<loc_id>', methods=['DELETE'])
def delete_location(loc_id):
    result = db.locations.delete_one({'_id': ObjectId(loc_id)})
    if result.deleted_count == 0: return jsonify({'error': 'Location not found'}), 404
    return jsonify({'success': True})

@api_bp.route('/admin/testdata', methods=['GET'])
def get_test_data():
    try:
        rows = list(db.wifi_test_data.find({}, {'_id': 0}))
        if not rows:
            return jsonify({'error': 'No test data found in database'}), 404
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/training-locations', methods=['GET'])
def get_training_locations():
    """Get unique locations from training data with sample counts."""
    try:
        pipeline = [
            {'$group': {
                '_id': '$Location',
                'landmark': {'$first': '$Landmark'},
                'floor': {'$first': '$Floor'},
                'count': {'$sum': 1}
            }},
            {'$sort': {'_id': 1}}
        ]
        results = list(db.wifi_training_data.aggregate(pipeline))
        locations = []
        for r in results:
            if r['_id']:
                locations.append({
                    'name': r['_id'],
                    'landmark': r.get('landmark', ''),
                    'floor': r.get('floor', ''),
                    'sample_count': r['count']
                })
        return jsonify(locations)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api_bp.route('/admin/location/add', methods=['POST'])
def add_single_location():
    """Add or update a single location marker on the map."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        name = data.get('name', '').strip()
        floor = data.get('floor', '1')
        x = data.get('x', 0)
        y = data.get('y', 0)

        if not name:
            return jsonify({'error': 'Location name is required'}), 400

        existing = db.locations.find_one({'name': name, 'floor': floor})
        if existing:
            db.locations.update_one(
                {'_id': existing['_id']},
                {'$set': {'x': x, 'y': y}}
            )
            return jsonify({'success': True, 'action': 'updated', 'id': str(existing['_id'])})

        result = db.locations.insert_one({
            'floor': floor, 'name': name, 'x': x, 'y': y
        })
        return jsonify({'success': True, 'action': 'created', 'id': str(result.inserted_id)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
