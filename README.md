# Indoor Navigation System

A WiFi-based indoor positioning and navigation system for multi-floor buildings.

## 🚀 Quick Start

### Backend
```bash
cd backend
python app.py
```

### Frontend
```bash
cd frontend
flutter run
```

## 📚 Documentation

- **[WORKSPACE_CONTEXT.md](WORKSPACE_CONTEXT.md)** - Complete system documentation
  - Architecture overview
  - All features and screens
  - API endpoints
  - Data models
  - Common patterns
  - Testing guidelines

- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Recent changes (Parts 5 & 6)
  - GraphNode updates
  - NavigableNode class
  - API service updates
  - Verification status

## 🏗️ Architecture

### Node-Based Navigation System

The system uses a graph-based approach where:
- **Nodes** represent walkable points on the map
- **Edges** connect nodes to form walkable paths
- **Dataset Locations** (from WiFi training data) are assigned to nodes
- **Navigable Nodes** are nodes with dataset locations assigned
- **Default Nodes** serve as fallback positions for unmapped predictions

### Tech Stack

**Frontend**: Flutter (Dart)
- Material Design with custom dark theme
- Provider for state management
- WiFi scanning for positioning

**Backend**: Flask (Python)
- REST API
- MongoDB for data storage
- Random Forest ML model for WiFi fingerprinting
- Dijkstra's algorithm for pathfinding

## 🎯 Key Features

### For Users
- WiFi-based location detection
- Search for destinations
- Turn-by-turn navigation
- Multi-floor support
- Animated path visualization

### For Admins
- Upload floor maps
- Create walkable graphs
- Assign locations to nodes
- Collect training data
- Retrain ML model
- View analytics

## 🔑 Core Concepts

### Coordinates
- **Normalized**: 0.0 to 1.0 (stored in database)
- **Pixel**: Actual screen coordinates (used for rendering)
- Resolution-independent design

### Navigation Flow
1. User scans WiFi
2. ML model predicts location
3. System checks if location is mapped to a node
4. If mapped: Shows marker at node position
5. If not mapped: Shows marker at default node position
6. User selects destination
7. System calculates shortest path using Dijkstra's algorithm
8. Animated path displays on map

## 📱 Screens

### User Screens
- **Login**: Authentication
- **Map**: Main navigation interface

### Admin Screens
- **Admin Dashboard**: Central hub
- **Floor Plans**: Map upload and graph editor
- **Node Data Manager**: Assign locations to nodes
- **Training Data Collection**: WiFi fingerprinting
- **Training Data Management**: CRUD operations
- **Model Training**: Retrain ML model
- **Statistics**: Analytics dashboard

## 🔌 API Endpoints

### Navigation
- `POST /getlocation` - Predict location from WiFi
- `POST /navigation/path` - Calculate shortest path
- `GET /navigation/nodes/{floor}` - Get navigable nodes
- `GET /navigation/default/{floor}` - Get default node

### Graph Management
- `GET /admin/graph/{floor}` - Get walkable graph
- `POST /admin/graph/{floor}` - Save graph
- `DELETE /admin/graph/{floor}` - Delete graph

### Node Data
- `GET /admin/node-data/{floor}` - Get WiFi data per node
- `GET /admin/dataset-locations/{floor}` - Get dataset locations
- `PUT /admin/graph/{floor}/node/{id}/assign-location` - Assign location
- `PUT /admin/graph/{floor}/node/{id}/unassign-location` - Unassign location

### Training Data
- `POST /admin/training-data` - Submit training data
- `GET /admin/training-records` - Get records
- `POST /admin/retrain` - Retrain model

See [WORKSPACE_CONTEXT.md](WORKSPACE_CONTEXT.md) for complete API documentation.

## 🗄️ Database Schema

### Collections
- `users` - User accounts
- `maps` - Floor map images (GridFS)
- `training_data_records` - WiFi fingerprints
- `walkable_graph` - Navigation graphs

### Key Fields
- **GraphNode**: `id`, `x`, `y`, `label`, `dataset_location`, `is_default`
- **GraphEdge**: `id`, `from_node`, `to_node`, `weight`

## 🎨 Design System

### Colors
- Background: `#0A1929` (Navy)
- Cards: `#132F4C` (Dark Navy)
- Primary: `#2979FF` (Blue)
- Secondary: `#00BCD4` (Teal)
- Success: `#00C853` (Green)
- Warning: `#FF6D00` (Orange)
- Accent: `#7C4DFF` (Purple)

### Typography
- Headings: GoogleFonts.outfit()
- Body: GoogleFonts.inter()
- Weight: FontWeight.w600

### Style Rules
- ❌ No gradients
- ❌ No blur effects (except path shadow)
- ❌ No box shadows
- ✅ Solid colors only
- ✅ Professional appearance

## 🧪 Testing

### Backend
```bash
cd backend
python -m pytest
```

### Frontend
```bash
cd frontend
flutter test
```

### Integration
1. Create walkable graph
2. Assign dataset locations to nodes
3. Collect training data
4. Test WiFi prediction
5. Test pathfinding

## 📦 Dependencies

### Backend
- Flask
- pymongo
- scikit-learn
- pandas
- numpy

### Frontend
- flutter
- http
- provider
- google_fonts
- wifi_scan
- connectivity_plus
- fluttertoast

## 🔧 Configuration

### Backend
Edit `backend/config.py`:
- MongoDB connection string
- Flask settings
- Model parameters

### Frontend
Edit `frontend/lib/api_service.dart`:
- Base URL (production/local)
- Timeout settings

## 🚀 Deployment

### Backend (Render.com)
1. Push to GitHub
2. Connect to Render
3. Set environment variables
4. Deploy

### Frontend (Mobile)
```bash
cd frontend
flutter build apk --release
```

## 📝 License

[Your License Here]

## 👥 Contributors

[Your Team Here]

## 📧 Support

For issues or questions, please refer to [WORKSPACE_CONTEXT.md](WORKSPACE_CONTEXT.md) for detailed documentation.

---

**Version**: 2.0 (Node-Based System)  
**Status**: ✅ Production-ready  
**Last Updated**: March 28, 2026
