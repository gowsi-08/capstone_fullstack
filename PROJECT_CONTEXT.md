# FindMyWay - Indoor Navigation System Context

## Project Overview
FindMyWay is a WiFi-based indoor navigation system that uses machine learning to predict user location from WiFi signal strengths. The system consists of a Flutter mobile app and a Flask backend with MongoDB storage.

## Architecture

### Frontend (Flutter)
- **Framework**: Flutter 3.10.4+ (Dart)
- **Platform Support**: Android, iOS, Web
- **State Management**: Provider pattern
- **Local Storage**: SQLite (sqflite) + SharedPreferences
- **Key Dependencies**: wifi_scan, http, connectivity_plus, image_picker

### Backend (Python Flask)
- **Framework**: Flask 2.3.3 with Flask-CORS
- **ML Engine**: scikit-learn 1.5.0 (RandomForest classifier)
- **Database**: MongoDB Atlas with GridFS for images
- **Image Processing**: OpenCV + Pillow
- **Server**: Gunicorn for production
- **Deployment**: Render.com (https://capstone-server-yadf.onrender.com)

### Database Schema (MongoDB)
- **users**: Authentication (180 students + admin)
- **locations**: Room/landmark coordinates per floor
- **maps**: Floor plan images (stored in GridFS)
- **training_data**: WiFi fingerprint samples

## Core Features

### User Features
1. **WiFi-Based Localization**: Scans WiFi networks, sends BSSID+signal strength to backend, receives predicted room
2. **Interactive Floor Maps**: Pan, zoom, tap-to-select destinations
3. **Pathfinding**: Shortest path calculation between current location and destination
4. **Multi-Floor Support**: Floor 1, 2, 3 with separate maps
5. **Guest Mode**: Access without login
6. **Real-time Updates**: Animated markers, live location tracking

### Admin Features
1. **Floor Plan Management**: Upload and process floor plan images
2. **Location Marking**: Add/edit/delete room positions on maps
3. **Training Data Collection**: Collect WiFi fingerprints at known locations
4. **Model Retraining**: Trigger ML model retraining with new data
5. **Statistics Dashboard**: View training data counts and model performance

## Authentication System
- **Students**: 180 accounts (22ucs001-22ucs180, password = username)
- **Admin**: admin@admin.com / KCETADMIN
- **Fallback**: Local authentication when backend unreachable
- **Session**: Persistent login via SharedPreferences

## Machine Learning Pipeline

### Training Process
1. Admin collects WiFi fingerprints at known locations
2. Data stored in train.csv with columns: SSID, Location, Landmark, Floor, BSSID, Signal Strength, etc.
3. RandomForest model trained on BSSID signal strengths → Location mapping
4. Model saved as wifi_model.pkl

### Prediction Process
1. User scans WiFi networks on device
2. App sends {BSSID: signal_strength} map to /getlocation
3. Backend creates feature vector from all known BSSIDs
4. Model predicts room/location
5. Frontend displays result on map

## Key Files Reference

### Backend Core
- `backend/app.py` - Flask app initialization
- `backend/config.py` - Environment configuration
- `backend/routes/api.py` - All API endpoints
- `backend/services/model_service.py` - ML model loading & prediction
- `backend/services/training_service.py` - Training data & retraining
- `backend/services/auth_service.py` - User authentication
- `backend/services/database.py` - MongoDB connection
- `backend/utils/image_processing.py` - Floor plan processing (contour detection)

### Frontend Core
- `frontend/lib/main.dart` - App entry point & routing
- `frontend/lib/map_screen.dart` - Main navigation UI
- `frontend/lib/admin_screen.dart` - Admin dashboard
- `frontend/lib/training_data_screen.dart` - WiFi data collection
- `frontend/lib/api_service.dart` - Backend API client
- `frontend/lib/app_state.dart` - Global state (user, login status)
- `frontend/lib/navigation_service.dart` - Pathfinding algorithms
- `frontend/lib/db_helper.dart` - Local SQLite operations

### Configuration
- `backend/.env` - Environment variables (MongoDB URL, credentials)
- `backend/requirements.txt` - Python dependencies
- `frontend/pubspec.yaml` - Flutter dependencies
- `backend/render.yaml` - Render deployment config

## API Endpoints

### Authentication
- `POST /auth/login` - User login (student/admin)

### Location Prediction
- `POST /getlocation` - Predict location from WiFi signals
- `GET /locations/all` - Get all locations for a floor

### Admin - Training Data
- `POST /admin/training-data` - Append WiFi fingerprint data
- `POST /admin/retrain` - Trigger model retraining
- `GET /admin/training-stats` - Get training data statistics

### Admin - Maps
- `POST /admin/upload_map/{floor}` - Upload floor plan image
- `GET /admin/map_base64/{floor}` - Get map as base64
- `GET /admin/map_image/{floor}` - Get map as image file

### Admin - Locations
- `GET /admin/locations/{floor}` - Get all locations for floor
- `POST /admin/locations/{floor}` - Add new location
- `PUT /admin/location/{id}` - Update location
- `DELETE /admin/location/{id}` - Delete location

### Health
- `GET /health` - Server health check

## Current State & Known Issues

### Working Features
✅ User authentication with fallback
✅ WiFi scanning and location prediction
✅ Floor map display with zoom/pan
✅ Admin floor plan upload with automatic room detection
✅ Training data collection and model retraining
✅ Pathfinding between locations
✅ Multi-floor support
✅ Production deployment on Render

### Areas for Improvement
⚠️ **Security**: Hardcoded credentials, weak password hashing (SHA256 instead of bcrypt)
⚠️ **Testing**: No unit tests or integration tests
⚠️ **Error Handling**: Some endpoints lack comprehensive validation
⚠️ **Performance**: No caching, pagination, or rate limiting
⚠️ **Documentation**: No API documentation (OpenAPI/Swagger)
⚠️ **Monitoring**: No logging infrastructure or analytics
⚠️ **Offline Mode**: App requires backend connectivity

## Development Environment Setup

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py  # Runs on port 5000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run  # For mobile
flutter run -d chrome  # For web
```

### Environment Variables
Create `backend/.env`:
```
MONGO_URL=mongodb+srv://...
DB_NAME=findmyway
SECRET_KEY=your-secret-key
ADMIN_EMAIL=admin@admin.com
ADMIN_PASSWORD=KCETADMIN
PORT=5000
DEBUG=True
```

## Common Development Tasks

### Add New API Endpoint
1. Define route in `backend/routes/api.py`
2. Add service logic in appropriate `backend/services/*.py`
3. Update `frontend/lib/api_service.dart` with client method
4. Call from UI screens

### Add New Screen
1. Create screen file in `frontend/lib/`
2. Add route in `main.dart`
3. Navigate using `Navigator.pushNamed(context, '/route')`

### Retrain Model
1. Collect training data via Training Data screen
2. Click "Retrain Model" in Admin panel
3. Model updates asynchronously in background

### Update Floor Map
1. Admin panel → Upload Map
2. Select floor and image file
3. Backend processes image (contour detection)
4. Locations auto-detected or manually added

## Technology Decisions

### Why WiFi Fingerprinting?
- No additional hardware required (uses existing WiFi infrastructure)
- Works indoors where GPS fails
- Reasonable accuracy (room-level precision)

### Why RandomForest?
- Handles non-linear relationships in signal propagation
- Robust to noise and outliers
- Fast prediction time
- No hyperparameter tuning needed for MVP

### Why Flutter?
- Single codebase for Android, iOS, Web
- Native performance
- Rich UI components
- Strong community support

### Why MongoDB?
- Flexible schema for evolving data models
- GridFS for large file storage
- Cloud hosting (Atlas) for easy deployment
- Good Python integration

## Prompt Generation Ideas

Use this context to generate prompts like:
- "Add JWT authentication to replace the current session-based auth"
- "Implement API rate limiting to prevent abuse"
- "Add unit tests for the model_service.py prediction logic"
- "Create an offline mode that caches the last known location"
- "Add OpenAPI/Swagger documentation for all endpoints"
- "Implement real-time location updates using WebSockets"
- "Add analytics dashboard showing user navigation patterns"
- "Optimize image processing for large floor plans"
- "Add multi-language support (English, Spanish, etc.)"
- "Implement role-based access control with custom permissions"
- "Add CI/CD pipeline with GitHub Actions"
- "Create a location history feature for users"
- "Implement Bluetooth beacon support for improved accuracy"
- "Add dark mode theme to the Flutter app"
- "Create export functionality for training data"

## Project Goals
This appears to be a capstone/final year project for KCET (likely an engineering college) focused on indoor navigation using WiFi-based machine learning localization.
