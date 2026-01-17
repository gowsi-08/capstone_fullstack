from flask import Blueprint, request, jsonify, send_file
from services.database import db, fs
from services.model_service import model_service
from utils.image_processing import process_map_image
from utils.csv_handler import read_test_csv
from bson import ObjectId
import base64
from io import BytesIO

api_bp = Blueprint('api', __name__)

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

# --- Admin Routes ---
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
        rows = read_test_csv('test.csv')
        return jsonify(rows)
    except FileNotFoundError:
        return jsonify({'error': 'test.csv not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500
