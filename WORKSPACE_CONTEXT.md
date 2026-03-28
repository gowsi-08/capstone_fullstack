# Indoor Navigation System - Complete Workspace Context

## 🎯 Project Overview

**Type**: Indoor Navigation Mobile App (Flutter + Flask)  
**Purpose**: WiFi-based indoor positioning and navigation for multi-floor buildings  
**Tech Stack**: Flutter (Frontend), Flask (Backend), MongoDB (Database)  
**ML Model**: Random Forest for WiFi fingerprinting  
**Navigation**: Graph-based pathfinding with Dijkstra's algorithm  
**Coordinates**: Normalized 0.0-1.0 (resolution-independent)  
**Status**: ✅ Production-ready with node-based navigation system

---

## 🏗️ System Architecture

### Frontend (Flutter)
- **Platform**: Android/iOS mobile app
- **State Management**: Provider (AppState)
- **UI Framework**: Material Design with custom dark theme
- **Navigation**: Named routes
- **Image Handling**: Base64 from backend
- **Networking**: http package with 10-15s timeouts

### Backend (Flask)
- **Framework**: Flask REST API
- **Database**: MongoDB with GridFS for images
- **ML**: scikit-learn (Random Forest)
- **Pathfinding**: Custom Dijkstra implementation
- **Deployment**: Render.com (production)

### Database (MongoDB)
- **Collections**: users, maps, training_data_records, walkable_graph
- **GridFS**: Map images storage
- **Indexing**: By floor, location, timestamp

---

## 🎨 Design System

### Color Palette
```dart
Background:  Color(0xFF0A1929)  // Navy
Cards:       Color(0xFF132F4C)  // Dark Navy
Blue:        Color(0xFF2979FF)  // Primary actions
Teal:        Color(0xFF00BCD4)  // Secondary/paths
Green:       Color(0xFF00C853)  // Success/navigable
Orange:      Color(0xFFFF6D00)  // Warning/unmapped
Purple:      Color(0xFF7C4DFF)  // Accent/locations
Red:         Colors.redAccent   // Destructive
```

### Typography
- **Headings**: GoogleFonts.outfit()
- **Body**: GoogleFonts.inter()
- **Weight**: FontWeight.w600 (NOT bold)

### Style Rules
- ❌ NO gradients
- ❌ NO blur effects (except path shadow)
- ❌ NO box shadows
- ✅ Solid colors only
- ✅ Borders: white.withOpacity(0.1)
- ✅ Professional, Zoho-level appearance

---

## 📁 File Structure

### Backend Structure
```
backend/
├── app.py                          # Main Flask app
├── config.py                       # Configuration
├── requirements.txt                # Python dependencies
├── services/
│   ├── auth_service.py            # Authentication logic
│   ├── database.py                # MongoDB connection
│   ├── model_service.py           # ML model (Random Forest)
│   ├── pathfinding_service.py     # Dijkstra + node management (500+ lines)
│   └── training_service.py        # Model training
├── routes/
│   └── api.py                     # All API endpoints (1000+ lines, 50+ endpoints)
└── utils/
    ├── csv_handler.py             # CSV operations
    └── image_processing.py        # Image utilities
```

### Frontend Structure
```
frontend/lib/
├── main.dart                      # App entry point
├── app_state.dart                 # Global state (Provider)
├── api_service.dart               # API client (600+ lines, 60+ methods)
├── navigation_service.dart        # Legacy navigation (deprecated)
├── login_screen.dart              # Login page
├── map_screen.dart                # Main user interface (1175 lines)
├── admin_dashboard_screen.dart    # Admin hub (6 sections)
├── admin/
│   ├── floor_plan_screen.dart           # Path editor (950+ lines)
│   ├── location_marking_screen.dart     # Node data manager (1230+ lines)
│   ├── training_data_screen.dart        # Data collection
│   ├── training_data_management_screen.dart  # CRUD operations
│   ├── model_training_screen.dart       # Model retraining
│   └── statistics_screen.dart           # Analytics
└── models/
    └── graph_models.dart          # Data models (700+ lines, 8 classes)
```

---

## 🔑 Key Concepts

### Node-Based Navigation System (NEW)

**Architecture Change**: The system has been refactored from a separate locations collection to a node-based system where:

1. **Graph Nodes** are the foundation
   - Nodes represent walkable points on the map
   - Nodes can be:
     - **Mapped**: Assigned a `dataset_location` (navigable destination)
     - **Default**: Marked with `is_default=true` (fallback marker position)
     - **Corridor-only**: No assignment (just for pathfinding)

2. **Dataset Locations** come from training data
   - Locations are WiFi fingerprint labels from `training_data_records`
   - Admins assign these locations to graph nodes
   - Only assigned locations are navigable

3. **Navigable Nodes** are nodes with `dataset_location` set
   - These appear as searchable destinations
   - Used for pathfinding endpoints
   - Shown as markers on map

### Coordinate System
- **Normalized**: 0.0 to 1.0 (stored in database)
- **Pixel**: Actual screen/image coordinates (used for rendering)
- **Conversion**: Always convert when drawing or saving

**Why Normalized?**
- Resolution-independent
- Works on all devices
- Scales automatically

---

## 📊 Data Models (`frontend/lib/models/graph_models.dart`)

### GraphNode (UPDATED)
```dart
class GraphNode {
  final String id;                    // UUID
  final double x;                     // 0.0 to 1.0 (normalized)
  final double y;                     // 0.0 to 1.0 (normalized)
  final String? label;                // Optional label
  final String? datasetLocation;      // Dataset location name (NEW)
  final bool isDefault;               // Default node flag (NEW)
  
  // Computed properties
  bool get isMapped => datasetLocation != null && datasetLocation!.isNotEmpty;
  bool get isCorridorOnly => !isMapped && !isDefault;
  
  // Methods
  factory GraphNode.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  GraphNode copyWith({...})
  Offset toPixelOffset(Size imageSize)
  factory GraphNode.fromPixelOffset({...})
}
```

### NavigableNode (NEW)
```dart
class NavigableNode {
  final String nodeId;                // Graph node ID
  final String locationName;          // Dataset location name
  final double x;                     // 0.0 to 1.0 (normalized)
  final double y;                     // 0.0 to 1.0 (normalized)
  final int floor;                    // Floor number
  final bool isDefault;               // Default node flag
  final int recordCount;              // Training data count
  
  // Methods
  factory NavigableNode.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  Offset toPixelOffset(Size imageSize)
  String get displayText => '$locationName ($recordCount records)';
}
```

### GraphEdge
```dart
class GraphEdge {
  final String id;                    // UUID
  final String fromNodeId;            // Node ID
  final String toNodeId;              // Node ID
  final double? weight;               // Auto-calculated on backend
  
  // Methods
  factory GraphEdge.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  GraphEdge copyWith({...})
  bool connectsTo(String nodeId)
  String? getOtherNode(String nodeId)
}
```

### NavigationPath
```dart
class NavigationPath {
  final List<Offset> points;         // Normalized coordinates
  final double totalDistance;
  final int estimatedSeconds;
  final bool found;
  final String? message;
  
  // Methods
  factory NavigationPath.fromJson(Map<String, dynamic> json)
  List<Offset> toPixelCoordinates(Size imageSize)
  int get estimatedMinutes
  bool get isEmpty
  int get waypointCount
}
```

---

## 🔌 API Endpoints Reference

### Authentication
- `POST /auth/login` - User login
  - Body: `{username, password}`
  - Returns: `{success, user: {username, role, display_name}}`

### Map Management
- `GET /admin/map_base64/{floor}` - Get map as base64
- `POST /admin/upload_map/{floor}` - Upload new map

### Graph Management
- `GET /admin/graph/{floor}` - Get walkable graph
  - Returns: `{exists, nodes: [{id, x, y, label, dataset_location, is_default}], edges: [...]}`
- `POST /admin/graph/{floor}` - Save graph (with validation)
  - Body: `{nodes: [...], edges: [...]}`
  - Validates: Only one `is_default` per floor, unique `dataset_location` per floor
- `DELETE /admin/graph/{floor}` - Delete graph

### Navigation Node Routes (NEW - Replaces locations collection)
- `GET /navigation/nodes/{floor}` - Get navigable nodes for floor
  - Returns: `[{node_id, location_name, x, y, floor, is_default, record_count}]`
- `GET /navigation/nodes/all` - Get all navigable nodes
- `GET /navigation/default/{floor}` - Get default node for floor
  - Returns: `{node_id, x, y, floor}` or null

### Admin Node Data Routes (NEW)
- `GET /admin/node-data/{floor}` - Get WiFi data groups per node
  - Returns: `[{node_id, location_name, x, y, is_default, wifi_groups: [...], total_records}]`
- `GET /admin/dataset-locations/{floor}` - Get all dataset locations with assignment status
  - Returns: `[{location, floor, record_count, assigned_node_id, is_assigned}]`
- `PUT /admin/graph/{floor}/node/{node_id}/assign-location` - Assign dataset location to node
  - Body: `{dataset_location: "Room 101"}`
  - Ensures uniqueness: unassigns from previous node if needed
- `PUT /admin/graph/{floor}/node/{node_id}/unassign-location` - Remove assignment

### Pathfinding
- `POST /navigation/path` - Calculate shortest path
  - Body: `{floor, from_location, to_location}`
  - Returns: `{found, path_nodes: [{x, y}], total_distance, estimated_seconds, reason?, missing?}`
  - Reasons: `no_graph`, `not_mapped`, `no_path`, `error`

### Location Prediction (UPDATED)
- `POST /getlocation` - Predict location from WiFi
  - Body: `[{BSSID, Signal Strength dBm}]`
  - Returns: `[{predicted, source, is_navigable, node_id?, node_x?, node_y?, floor?, default_node_x?, default_node_y?}]`
  - `is_navigable`: true if location is mapped to a node
  - `node_x/y`: Coordinates if navigable
  - `default_node_x/y`: Fallback coordinates if not navigable

### Training Data
- `POST /admin/training-data` - Submit training data
- `GET /admin/training-records` - Get paginated records
- `GET /admin/training-records/grouped` - Get grouped records
- `GET /admin/training-records/locations` - Get location list
- `PUT /admin/training-records/{id}` - Update record
- `DELETE /admin/training-records/{id}` - Delete record
- `PUT /admin/training-records/bulk` - Bulk update
- `DELETE /admin/training-records/bulk` - Bulk delete
- `POST /admin/training-records/merge` - Merge locations
- `GET /admin/training-records/export` - Export CSV

### Model Training
- `GET /admin/training-stats` - Get training statistics
- `POST /admin/retrain` - Trigger model retraining

---

## 🗄️ Database Schema

### walkable_graph Collection (UPDATED)
```json
{
  "_id": ObjectId,
  "floor": int,
  "nodes": [
    {
      "id": "string (UUID)",
      "x": float,
      "y": float,
      "label": "string",
      "dataset_location": "string (optional)",
      "is_default": bool
    }
  ],
  "edges": [
    {
      "id": "string (UUID)",
      "from_node": "string (UUID)",
      "to_node": "string (UUID)",
      "weight": float
    }
  ],
  "updated_at": ISODate
}
```

### training_data_records Collection
```json
{
  "_id": ObjectId,
  "ssid": "string",
  "bssid": "string (lowercase)",
  "signal": int,
  "location": "string",
  "landmark": "string",
  "floor": int,
  "frequency": int,
  "bandwidth": int,
  "estimated_distance": float,
  "capabilities": "string",
  "source": "train" | "test",
  "collected_at": ISODate,
  "created_at": ISODate
}
```

### users Collection
```json
{
  "_id": ObjectId,
  "username": "string",
  "password": "string (hashed)",
  "role": "admin" | "student",
  "display_name": "string"
}
```

### maps Collection (GridFS)
```json
{
  "_id": ObjectId,
  "floor": "string",
  "file_id": ObjectId,
  "width": int,
  "height": int,
  "uploaded_at": ISODate
}
```

---

## 🎬 Key Workflows

### Workflow 1: Admin Sets Up Navigation

1. **Upload Floor Map**
   - Go to Floor Plan Screen
   - Upload map image for each floor
   - System stores in GridFS

2. **Create Walkable Graph**
   - Switch to "Edit Paths" mode
   - Add nodes at walkable points
   - Connect nodes with edges
   - Mark one node as default (fallback position)
   - Save graph

3. **Assign Dataset Locations to Nodes**
   - Go to Location Marking Screen (now "Node Data Manager")
   - View list of dataset locations from training data
   - For each location:
     - Select location from list
     - Click "Assign to Node"
     - Select target node on map
   - System validates uniqueness

4. **Test Navigation**
   - Go to Map Screen
   - Search for assigned locations
   - Test pathfinding between locations

### Workflow 2: User Navigates

1. **Find Current Location**
   - Tap "Locate" button
   - System scans WiFi
   - ML model predicts location
   - If navigable: Shows marker at node position
   - If not navigable: Shows marker at default node position

2. **Select Destination**
   - Use search bar
   - Type location name
   - Select from autocomplete
   - System shows destination marker

3. **Get Directions**
   - Tap "Get Directions"
   - System calculates shortest path
   - Animated path displays on map
   - Shows estimated time

### Workflow 3: Collect Training Data

1. **Go to Training Data Screen**
   - Enter location name
   - Enter landmark (optional)
   - Select floor

2. **Scan WiFi**
   - Tap "Scan WiFi"
   - System collects all visible networks
   - Shows SSID, BSSID, signal strength

3. **Submit**
   - Tap "Submit"
   - Data saved to MongoDB
   - Model retrains automatically

---

## 🔧 Backend Services

### PathfindingService (pathfinding_service.py)

**Key Methods**:

```python
def build_graph(floor: int) -> Dict:
    """Load graph from MongoDB and build adjacency structure"""
    
def dijkstra(adjacency: Dict, start_node: str, end_node: str) -> List[str]:
    """Dijkstra's shortest path algorithm"""
    
def calculate_path(floor: int, from_location: str, to_location: str) -> Dict:
    """Calculate path between two dataset locations"""
    
def get_navigable_nodes(floor: Optional[int] = None) -> List[Dict]:
    """Get nodes with dataset_location assigned"""
    
def get_default_node(floor: int) -> Optional[Dict]:
    """Get the default node for a floor"""
    
def get_dataset_locations(floor: int) -> List[Dict]:
    """Get all dataset locations with assignment status"""
    
def assign_dataset_location(floor: int, node_id: str, dataset_location: str) -> Dict:
    """Assign a dataset location to a node (ensures uniqueness)"""
    
def unassign_dataset_location(floor: int, node_id: str) -> Dict:
    """Remove dataset_location assignment from a node"""
    
def get_node_data_groups(floor: int) -> List[Dict]:
    """Get WiFi data groups linked to each named node"""
```

**Validation Rules**:
- Only one node per floor can have `is_default=true`
- Only one node per floor can have any given `dataset_location`
- Enforced in `save_graph()` method

### ModelService (model_service.py)

**Key Methods**:
```python
def train(X, y):
    """Train Random Forest classifier"""
    
def predict(bssid_to_signal: Dict) -> str:
    """Predict location from WiFi scan"""
```

---

## 🎨 Screen Details

### Map Screen (map_screen.dart) - 1175 lines

**Purpose**: Main user interface for navigation

**Key Features**:
- Interactive map with zoom/pan
- WiFi-based location prediction
- Search for navigable locations
- Animated pathfinding
- Floor switching
- Test mode for validation

**Marker Types**:
- **Current Location**: Blue person pin (if navigable) or at default node (if not)
- **Destination**: Red flag
- **All Navigable Locations**: Small purple dots

**Info Cards**:
- **Current Location Card**: Shows predicted location with "Navigable" or "Not mapped" badge
- **Directions Banner**: Appears when destination selected

**APIs Used**:
- `GET /admin/map_base64/{floor}`
- `GET /navigation/nodes/{floor}` (NEW)
- `GET /navigation/nodes/all` (NEW)
- `GET /navigation/default/{floor}` (NEW)
- `POST /getlocation`
- `POST /navigation/path`

### Floor Plan Screen (floor_plan_screen.dart) - 950+ lines

**Purpose**: Manage floor maps and create walkable graphs

**Modes**:
1. **Gallery View**: Grid of floor cards
2. **View Map Mode**: Read-only overlay with graph visualization
3. **Edit Paths Mode**: Professional graph editor

**Path Editor Features**:
- Add nodes (tap map)
- Add edges (select two nodes)
- Delete nodes/edges
- Mark node as default (NEW)
- Assign dataset locations (NEW)
- Save with validation

**Toolbar**:
- Add Node (teal)
- Add Edge (teal)
- Delete (orange)
- Clear All (red)
- Save Graph (blue)

### Location Marking Screen (location_marking_screen.dart) - 1230+ lines

**Purpose**: Node Data Manager - Assign dataset locations to graph nodes

**NEW Functionality**:
- Shows list of dataset locations from training data
- Shows which locations are assigned to nodes
- Allows assigning/unassigning locations to nodes
- Shows WiFi data groups per node
- Visual feedback for assigned vs unassigned

**Layout**:
- **Left Panel**: Map with graph overlay
- **Right Panel**: List of dataset locations

**Actions**:
- Assign location to node
- Unassign location from node
- View WiFi data for location
- View node details

---

## 🚀 API Service Methods (api_service.dart)

### Navigation Node Methods (NEW)
```dart
static Future<List<NavigableNode>> getNavigableNodes(int floor)
static Future<List<NavigableNode>> getAllNavigableNodes()
static Future<NavigableNode?> getDefaultNode(int floor)
```

### Admin Node Data Methods (NEW)
```dart
static Future<List<Map<String, dynamic>>> getNodeData(int floor)
static Future<List<Map<String, dynamic>>> getDatasetLocations(int floor)
```

### Graph Management
```dart
static Future<Map<String, dynamic>?> getWalkableGraph(int floor)
static Future<bool> saveWalkableGraph(int floor, List<Map> nodes, List<Map> edges)
static Future<bool> clearWalkableGraph(int floor)
```

### Pathfinding
```dart
static Future<Map<String, dynamic>?> getNavigationPath({
  required int floor,
  required String fromLocation,
  required String toLocation,
})
```

---

## ⚠️ Important Notes

### Deprecated Features
- **Old locations collection**: Removed in favor of node-based system
- **Separate location markers**: Now integrated with graph nodes
- **Manual location positioning**: Replaced with node assignment

### Migration Path
If you have old data:
1. Create walkable graph with nodes
2. Mark one node as default per floor
3. Assign dataset locations to nodes
4. Old location markers are no longer used

### Validation Rules
- **is_default**: Only one per floor
- **dataset_location**: Only one node per location per floor
- **Enforced**: Backend validates on save

### Best Practices
1. Always create a default node per floor
2. Assign dataset locations only to nodes with training data
3. Test pathfinding after assigning locations
4. Use normalized coordinates (0-1) for all positions
5. Handle "not navigable" case in UI

---

## 🧪 Testing Checklist

### Backend
- [ ] Graph CRUD with validation
- [ ] Node assignment/unassignment
- [ ] Pathfinding with dataset locations
- [ ] Default node retrieval
- [ ] Navigable nodes listing
- [ ] WiFi prediction with is_navigable flag

### Frontend
- [ ] Map screen shows navigable nodes
- [ ] Search works with navigable nodes
- [ ] Pathfinding works between assigned locations
- [ ] Default node fallback for unmapped predictions
- [ ] Node data manager shows dataset locations
- [ ] Assignment/unassignment works
- [ ] Validation prevents duplicate assignments

---

## 📝 Common Patterns

### API Call Pattern
```dart
Future<void> _loadData() async {
  try {
    final data = await ApiService.someMethod();
    if (data != null) {
      setState(() => _data = data);
    } else {
      _showError('Failed to load data');
    }
  } catch (e) {
    _showError('Error: $e');
  }
}
```

### Coordinate Conversion
```dart
// Normalized to Pixel
final pixelPos = node.toPixelOffset(_imageSize!);

// Pixel to Normalized
final normalizedPos = CoordinateConverter.pixelToNormalized(tapPos, _imageSize!);
```

### Validation Pattern
```dart
if (_nodes.isEmpty) {
  _showSnackBar('No nodes to save', Colors.orange);
  return;
}

// Check for duplicate assignments
final assignedLocations = _nodes
    .where((n) => n.datasetLocation != null)
    .map((n) => n.datasetLocation)
    .toList();
    
if (assignedLocations.length != assignedLocations.toSet().length) {
  _showSnackBar('Duplicate location assignments detected', Colors.red);
  return;
}
```

---

## 🎯 Quick Start for AI

When working on this project:

1. **Understand the node-based system**: Locations are assigned to graph nodes, not stored separately
2. **Use normalized coordinates**: Always 0.0-1.0 for positions
3. **Follow the design system**: Dark theme, specific colors, no gradients
4. **Handle both cases**: Navigable (mapped) and non-navigable (unmapped) locations
5. **Validate uniqueness**: is_default and dataset_location must be unique per floor
6. **Test pathfinding**: Ensure assigned locations can be used for navigation

---

## 📚 Key Files to Reference

### Backend
- `backend/routes/api.py` - All API endpoints (1000+ lines)
- `backend/services/pathfinding_service.py` - Navigation logic (500+ lines)
- `backend/services/model_service.py` - ML model

### Frontend
- `frontend/lib/api_service.dart` - API client (600+ lines)
- `frontend/lib/models/graph_models.dart` - Data models (700+ lines)
- `frontend/lib/map_screen.dart` - Main UI (1175 lines)
- `frontend/lib/admin/floor_plan_screen.dart` - Path editor (950+ lines)
- `frontend/lib/admin/location_marking_screen.dart` - Node data manager (1230+ lines)

---

## 🔄 Recent Changes (Parts 1-6)

### Part 1: Backend Refactor
- Removed old location routes
- Added navigation node routes
- Added admin node data routes
- Updated /getlocation response

### Part 2: PathfindingService Updates
- Added get_navigable_nodes()
- Added get_default_node()
- Added get_dataset_locations()
- Added assign/unassign methods
- Added get_node_data_groups()

### Part 3: Frontend API Service
- Added getNavigableNodes()
- Added getAllNavigableNodes()
- Added getDefaultNode()
- Added getNodeData()
- Added getDatasetLocations()

### Part 4: Map Screen Updates
- Uses NavigableNode instead of LocationMarker
- Handles is_navigable flag
- Shows default node fallback
- Updated search to use navigable nodes

### Part 5: GraphNode Model Updates
- Added isDefault field
- Added isCorridorOnly getter
- Updated fromJson/toJson
- Updated copyWith

### Part 6: NavigableNode Model
- New class for navigable destinations
- Includes node_id, location_name, floor
- Includes is_default and record_count
- Used by map screen and search

---

**Last Updated**: March 28, 2026  
**Version**: 2.0 (Node-Based System)  
**Total Lines**: 12,000+  
**Total Files**: 25+  
**Total Features**: 60+  
**Status**: ✅ Production-ready with complete node-based navigation
