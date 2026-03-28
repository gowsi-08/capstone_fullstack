# FindMyWay - Indoor Navigation System
## Complete Project Context & Documentation

---

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Features](#features)
5. [Setup & Installation](#setup--installation)
6. [User Roles](#user-roles)
7. [How It Works](#how-it-works)
8. [API Documentation](#api-documentation)
9. [Database Schema](#database-schema)
10. [Deployment](#deployment)
11. [Troubleshooting](#troubleshooting)

---

## 📱 Project Overview

**FindMyWay** is an indoor navigation system that uses WiFi fingerprinting to determine a user's location inside a building and provide turn-by-turn navigation to their destination.

### Key Capabilities
- Real-time indoor positioning using WiFi signals
- Interactive floor plan visualization
- Turn-by-turn navigation between locations
- Admin dashboard for system management
- Training data collection and model retraining
- Graph-based pathfinding

### Use Case
Designed for educational institutions, hospitals, shopping malls, or any large indoor facility where GPS doesn't work effectively.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                    │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐   │
│  │  Login   │  │   Map    │  │  Admin Dashboard   │   │
│  │  Screen  │→ │  Screen  │  │  - Floor Plans     │   │
│  └──────────┘  └──────────┘  │  - Training Data   │   │
│                               │  - Location Marking│   │
│                               └────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                         ↕ HTTP/REST API
┌─────────────────────────────────────────────────────────┐
│              Python Flask Backend Server                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Auth Service │  │ Model Service│  │ Pathfinding  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │   Database   │  │  ML Training │                   │
│  │   Service    │  │   Service    │                   │
│  └──────────────┘  └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
                         ↕
┌─────────────────────────────────────────────────────────┐
│                    MongoDB Database                      │
│  - training_data_records (WiFi fingerprints)            │
│  - walkable_graphs (floor navigation graphs)            │
│  - users (authentication)                               │
└─────────────────────────────────────────────────────────┘
```

---

## 💻 Technology Stack

### Frontend (Mobile App)
- **Framework**: Flutter 3.10+
- **Language**: Dart
- **Key Packages**:
  - `http` - API communication
  - `provider` - State management
  - `wifi_scan` - WiFi scanning
  - `google_fonts` - Typography
  - `fluttertoast` - User notifications
  - `connectivity_plus` - Network status
  - `shared_preferences` - Local storage

### Backend (Server)
- **Framework**: Flask (Python)
- **Language**: Python 3.9+
- **Key Libraries**:
  - `flask` - Web framework
  - `flask-cors` - CORS handling
  - `pymongo` - MongoDB driver
  - `scikit-learn` - Machine learning
  - `joblib` - Model serialization
  - `pandas` - Data processing

### Database
- **Type**: MongoDB (NoSQL)
- **Hosting**: MongoDB Atlas (Cloud)

### Machine Learning
- **Algorithm**: K-Nearest Neighbors (KNN)
- **Purpose**: WiFi fingerprint classification
- **Features**: BSSID signal strengths
- **Labels**: Location names

### Hosting
- **Backend**: Render (Free Tier)
- **Database**: MongoDB Atlas (Free Tier)
- **Mobile App**: APK distribution

---

## ✨ Features

### For Students/Users

#### 1. Location Detection
- Automatic WiFi scanning
- Real-time position tracking
- Visual marker on map
- Location name display

#### 2. Navigation
- Search for destinations
- Select from/to locations
- Turn-by-turn path visualization
- Estimated time display
- Animated route drawing

#### 3. Map Interaction
- Zoom and pan
- Floor switching
- Location markers
- Current position indicator

### For Administrators

#### 1. Floor Plan Management
- Upload floor maps
- View all floors
- Edit navigation paths
- Create walkable graphs

#### 2. Path Editor
- Add/remove nodes
- Connect nodes with edges
- Visual graph editing
- Save/clear graphs

#### 3. Location Marking
- Assign dataset locations to nodes
- View unassigned locations
- Bulk location management
- Node selection on map

#### 4. Training Data Management
- Collect WiFi fingerprints
- View training records
- Filter by floor/location
- Export to CSV
- Merge duplicate locations
- Bulk operations

#### 5. Model Training
- Manual retrain trigger
- View training statistics
- Model accuracy monitoring
- Automatic retraining on app start

---

## 🚀 Setup & Installation

### Prerequisites
- Flutter SDK 3.10+
- Python 3.9+
- MongoDB Atlas account
- Android device/emulator

### Backend Setup

1. **Clone Repository**
```bash
git clone <repository-url>
cd capstone/backend
```

2. **Create Virtual Environment**
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows
```

3. **Install Dependencies**
```bash
pip install -r requirements.txt
```

4. **Configure Environment**
Create `.env` file:
```env
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/
PORT=5000
DEBUG=True
```

5. **Run Server**
```bash
python app.py
```

### Frontend Setup

1. **Navigate to Frontend**
```bash
cd capstone/frontend
```

2. **Install Dependencies**
```bash
flutter pub get
```

3. **Configure API URL**
Edit `lib/api_service.dart`:
```dart
static const String _productionUrl = "https://your-server.onrender.com";
const bool useProduction = true;
```

4. **Generate App Icons**
```bash
flutter pub run flutter_launcher_icons
```

5. **Build APK**
```bash
flutter build apk --release
```

6. **Install on Device**
```bash
flutter install
```

---

## 👥 User Roles

### Student Role
**Credentials**: 22ucs001 to 22ucs180 (username = password)

**Capabilities**:
- View map
- Search locations
- Get navigation
- Track current location
- Switch floors

**Restrictions**:
- Cannot access admin dashboard
- Cannot modify floor plans
- Cannot collect training data

### Admin Role
**Credentials**: admin@admin.com / KCETADMIN

**Capabilities**:
- All student capabilities
- Access admin dashboard
- Upload floor plans
- Edit navigation graphs
- Collect training data
- Manage locations
- Retrain ML model
- View statistics

### Guest Role
**Access**: Continue as Guest button

**Capabilities**:
- View map
- Search locations
- Get navigation
- Limited features

---

## 🔧 How It Works

### WiFi Fingerprinting Process

#### 1. Training Phase (Admin)
```
1. Admin goes to location (e.g., "Room 101")
2. App scans WiFi networks
3. Records: [BSSID1: -45dBm, BSSID2: -67dBm, ...]
4. Stores in database with location label
5. Repeat for multiple locations
6. Train KNN model with collected data
```

#### 2. Prediction Phase (User)
```
1. User clicks "Current Location" button
2. App scans WiFi networks
3. Sends signal strengths to server
4. Server uses KNN model to predict location
5. Returns: location name, coordinates, floor
6. App displays marker on map
```

### Navigation Process

#### 1. Graph Creation (Admin)
```
1. Admin opens Floor Plan Management
2. Selects floor and clicks "Edit Paths"
3. Adds nodes at walkable points
4. Connects nodes with edges
5. Saves graph to database
```

#### 2. Location Assignment (Admin)
```
1. Admin opens Location Marking
2. Selects dataset location
3. Clicks node on map to assign
4. Location becomes navigable
```

#### 3. Route Calculation (User)
```
1. User searches for destination
2. Clicks "Get Directions"
3. Selects starting point (current or other)
4. Server runs Dijkstra's algorithm
5. Returns shortest path as node coordinates
6. App draws animated route on map
```

### Keep-Alive Mechanism

**Purpose**: Prevent free-tier server from sleeping

**Implementation**:
```
1. App opens → Login screen loads
2. Immediately pings /health endpoint
3. Continues pinging every 20 seconds
4. Server stays awake throughout session
5. App closes → Pinging stops
```

**Benefits**:
- Instant server responses
- No 30-40 second wake-up delays
- Seamless user experience

---

## 📡 API Documentation

### Base URL
```
Production: https://capstone-server-yadf.onrender.com
Local: http://localhost:5000
```

### Authentication

#### POST /auth/login
Login with credentials

**Request**:
```json
{
  "username": "22ucs001",
  "password": "22ucs001"
}
```

**Response**:
```json
{
  "success": true,
  "user": {
    "role": "student",
    "display_name": "Student 22UCS001"
  }
}
```

### Location Prediction

#### POST /getlocation
Predict location from WiFi signals

**Request**:
```json
[
  {
    "BSSID": "aa:bb:cc:dd:ee:ff",
    "Signal Strength dBm": -45
  },
  {
    "BSSID": "11:22:33:44:55:66",
    "Signal Strength dBm": -67
  }
]
```

**Response**:
```json
[
  {
    "predicted": "Room 101",
    "source": "flask_server",
    "is_navigable": true,
    "node_id": "node_1",
    "node_x": 0.5,
    "node_y": 0.3,
    "floor": 1
  }
]
```

### Navigation

#### POST /navigation/path
Calculate route between locations

**Request**:
```json
{
  "floor": 1,
  "from_location": "Room 101",
  "to_location": "Room 205"
}
```

**Response**:
```json
{
  "found": true,
  "path_nodes": [
    {"x": 0.5, "y": 0.3},
    {"x": 0.6, "y": 0.4},
    {"x": 0.7, "y": 0.5}
  ],
  "total_distance": 150.5,
  "estimated_seconds": 90
}
```

#### GET /navigation/nodes/{floor}
Get navigable nodes for floor

**Response**:
```json
[
  {
    "node_id": "node_1",
    "location_name": "Room 101",
    "x": 0.5,
    "y": 0.3,
    "floor": 1,
    "is_default": false,
    "record_count": 45
  }
]
```

### Admin - Floor Plans

#### GET /admin/map_base64/{floor}
Get floor map as base64

**Response**:
```json
{
  "base64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

#### GET /admin/graph/{floor}
Get walkable graph for floor

**Response**:
```json
{
  "exists": true,
  "floor": 1,
  "nodes": [
    {
      "id": "node_1",
      "x": 0.5,
      "y": 0.3,
      "dataset_location": "Room 101"
    }
  ],
  "edges": [
    {
      "id": "edge_1",
      "from_node": "node_1",
      "to_node": "node_2"
    }
  ]
}
```

#### POST /admin/graph/{floor}
Save walkable graph

**Request**:
```json
{
  "nodes": [...],
  "edges": [...]
}
```

### Admin - Training Data

#### POST /admin/training-data
Submit training data

**Request**:
```json
{
  "location": "Room 101",
  "landmark": "Near entrance",
  "floor": "1",
  "scans": [
    {
      "ssid": "WiFi-Network",
      "bssid": "aa:bb:cc:dd:ee:ff",
      "rssi": -45
    }
  ]
}
```

#### GET /admin/training-stats
Get training statistics

**Response**:
```json
{
  "total_rows": 1234,
  "total_locations": 45,
  "total_bssids": 67
}
```

#### POST /admin/retrain
Trigger model retraining

**Response**:
```json
{
  "success": true,
  "message": "Model retraining started in background"
}
```

### Health Check

#### GET /health
Server health check

**Response**:
```json
{
  "status": "ok"
}
```

---

## 🗄️ Database Schema

### Collection: training_data_records

**Purpose**: Store WiFi fingerprints for ML training

```javascript
{
  "_id": ObjectId("..."),
  "location": "Room 101",
  "landmark": "Near entrance",
  "floor": 1,
  "bssid": "aa:bb:cc:dd:ee:ff",
  "ssid": "WiFi-Network",
  "rssi": -45,
  "source": "train",
  "timestamp": ISODate("2024-01-01T12:00:00Z")
}
```

**Indexes**:
- `location` (ascending)
- `floor` (ascending)
- `bssid` (ascending)

### Collection: walkable_graphs

**Purpose**: Store navigation graphs for each floor

```javascript
{
  "_id": ObjectId("..."),
  "floor": 1,
  "nodes": [
    {
      "id": "node_1",
      "x": 0.5,
      "y": 0.3,
      "label": "",
      "dataset_location": "Room 101",
      "is_default": false
    }
  ],
  "edges": [
    {
      "id": "edge_1",
      "from_node": "node_1",
      "to_node": "node_2",
      "weight": 10.5
    }
  ],
  "updated_at": ISODate("2024-01-01T12:00:00Z")
}
```

**Indexes**:
- `floor` (unique)

### Collection: users

**Purpose**: Store user authentication data

```javascript
{
  "_id": ObjectId("..."),
  "username": "22ucs001",
  "password": "hashed_password",
  "role": "student",
  "display_name": "Student 22UCS001",
  "created_at": ISODate("2024-01-01T12:00:00Z")
}
```

**Indexes**:
- `username` (unique)

---

## 🌐 Deployment

### Backend Deployment (Render)

1. **Create Render Account**
   - Go to render.com
   - Sign up with GitHub

2. **Create Web Service**
   - New → Web Service
   - Connect GitHub repository
   - Select backend folder

3. **Configure Service**
   ```
   Name: capstone-server
   Environment: Python 3
   Build Command: pip install -r requirements.txt
   Start Command: python app.py
   ```

4. **Add Environment Variables**
   ```
   MONGO_URI=mongodb+srv://...
   PORT=5000
   DEBUG=False
   ```

5. **Deploy**
   - Click "Create Web Service"
   - Wait for deployment
   - Note the URL: https://capstone-server-xxx.onrender.com

### Database Setup (MongoDB Atlas)

1. **Create Cluster**
   - Go to mongodb.com/cloud/atlas
   - Create free cluster

2. **Create Database User**
   - Database Access → Add User
   - Username/Password authentication

3. **Whitelist IP**
   - Network Access → Add IP
   - Allow access from anywhere (0.0.0.0/0)

4. **Get Connection String**
   - Clusters → Connect → Connect your application
   - Copy connection string
   - Replace <password> with actual password

### Mobile App Distribution

1. **Build Release APK**
```bash
cd frontend
flutter build apk --release
```

2. **Locate APK**
```
frontend/build/app/outputs/flutter-apk/app-release.apk
```

3. **Distribution Options**:
   - Direct APK sharing
   - Google Play Store
   - Internal testing platforms
   - Firebase App Distribution

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Server Not Responding
**Symptoms**: Timeout errors, "Could not predict location"

**Solutions**:
- Check server is running (visit /health endpoint)
- Verify API URL in api_service.dart
- Check internet connection
- Wait for server to wake up (30-40s on free tier)

#### 2. WiFi Scan Fails
**Symptoms**: "No Wi-Fi signals found"

**Solutions**:
- Enable WiFi on device
- Grant location permissions
- Check WiFi scanning is supported
- Ensure device is not in airplane mode

#### 3. Model Not Trained
**Symptoms**: "Train model first" error

**Solutions**:
- Collect training data first
- Trigger manual retrain from admin dashboard
- Wait for automatic retrain on app start
- Check training data exists in database

#### 4. Navigation Path Not Found
**Symptoms**: "No walkable path found"

**Solutions**:
- Ensure graph exists for floor
- Check locations are assigned to nodes
- Verify nodes are connected with edges
- Check both locations are on same floor

#### 5. App Crashes on Startup
**Symptoms**: ClassNotFoundException

**Solutions**:
- Uninstall old app completely
- Clean build: `flutter clean`
- Rebuild: `flutter build apk --release`
- Reinstall app

### Debug Mode

Enable debug logging in app:
```dart
// In api_service.dart
const bool DEBUG = true;
```

Check console logs for:
- `🌐 API REQUEST` - API calls
- `📡 WiFi scan found X access points` - WiFi scanning
- `💚 Server keep-alive: OK` - Keep-alive status
- `📍 Location predicted` - Prediction results

---

## 📞 Support & Contact

For issues, questions, or contributions:
- Check troubleshooting section
- Review API documentation
- Check server logs on Render dashboard
- Verify database connection on MongoDB Atlas

---

## 📄 License

This project is for educational purposes.

---

**Last Updated**: 2024
**Version**: 1.0.0
**Status**: Production Ready
