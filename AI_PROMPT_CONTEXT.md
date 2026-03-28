# AI Prompt Context - Indoor Navigation System

## Project Overview

**Type**: Indoor Navigation Mobile App (Flutter + Flask)
**Purpose**: WiFi-based indoor positioning and navigation for multi-floor buildings
**Tech Stack**: Flutter (Frontend), Flask (Backend), MongoDB (Database)
**ML Model**: Random Forest for WiFi fingerprinting
**Navigation**: Graph-based pathfinding with Dijkstra's algorithm
**Coordinates**: Normalized 0.0-1.0 (resolution-independent)

---

## System Architecture

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
- **Collections**: users, maps, locations, training_data_records, walkable_graph
- **GridFS**: Map images storage
- **Indexing**: By floor, location, timestamp

---

## Design System

### Color Palette
```dart
Background:  Color(0xFF0A1929)  // Navy
Cards:       Color(0xFF132F4C)  // Dark Navy
Blue:        Color(0xFF2979FF)  // Primary actions
Teal:        Color(0xFF00BCD4)  // Secondary/paths
Green:       Color(0xFF00C853)  // Success/selected
Orange:      Color(0xFFFF6D00)  // Warning/delete
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

## File Structure


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
│   ├── pathfinding_service.py     # Dijkstra's algorithm (300+ lines)
│   └── training_service.py        # Model training
├── routes/
│   └── api.py                     # All API endpoints (40+ endpoints)
└── utils/
    ├── csv_handler.py             # CSV operations
    └── image_processing.py        # Image utilities
```

### Frontend Structure
```
frontend/lib/
├── main.dart                      # App entry point
├── app_state.dart                 # Global state (Provider)
├── api_service.dart               # API client (500+ lines, 50+ methods)
├── navigation_service.dart        # Legacy navigation (deprecated)
├── login_screen.dart              # Login page
├── map_screen.dart                # Main user interface (965 lines)
├── admin_dashboard_screen.dart    # Admin hub (6 sections)
├── admin/
│   ├── floor_plan_screen.dart           # Path editor (950+ lines)
│   ├── location_marking_screen.dart     # Location manager (1230+ lines)
│   ├── training_data_screen.dart        # Data collection
│   ├── training_data_management_screen.dart  # CRUD operations
│   ├── model_training_screen.dart       # Model retraining
│   └── statistics_screen.dart           # Analytics
└── models/
    └── graph_models.dart          # Data models (600+ lines, 6 classes)
```

---

## Screen-by-Screen Feature Breakdown


### 1. Login Screen (`login_screen.dart`)

**Purpose**: Authentication for students and admins

**Features**:
- Username/password input fields
- Role-based login (student/admin)
- Remember me functionality
- Error handling with toast messages
- Auto-navigation to map screen on success

**UI Elements**:
- Dark navy card (Color(0xFF132F4C))
- Blue login button (Color(0xFF2979FF))
- Input fields with white.withOpacity(0.1) borders
- Logo/title at top
- Error messages in red

**API Endpoint**: `POST /auth/login`

**Navigation**:
- Success → Map Screen
- Admin → Can access Admin Dashboard

**State Management**: Updates AppState with user info

---

### 2. Map Screen (`map_screen.dart`) - 965 lines

**Purpose**: Main user interface for navigation and location finding

**Features**:

#### Top App Bar (Custom, 80px height)
- **Floor Selector**: Dropdown (L1, L2, L3) with blue accent
- **Search Bar**: Autocomplete for locations
  - Shows all locations across floors
  - Filters by name (case-insensitive)
  - Displays floor badge
  - Auto-switches floor on selection
  - Animates camera to location
- **Admin Button**: Settings icon (teal) - only for admins
- **User Menu**: Account icon with logout option
  - Shows username and role
  - Logout button (red)

#### Map Viewer (InteractiveViewer)
- **Zoom**: 0.1x to 4.0x
- **Pan**: Unlimited with 1000px boundary margin
- **Map Image**: Base64 from backend, decoded to Uint8List
- **Transform Controller**: For programmatic camera control

#### Location Markers
- **All Locations**: Small dots (8px, indigo, 40% opacity)
- **Current Location**: Blue person pin (48px) with pulse animation
  - Animation: 0.7-1.0 scale, 600ms
  - Radiating circle effect
- **Selected Destination**: Red flag (48px) with pulse animation
  - Animation: 0.7-1.0 scale, 600ms

#### Animated Path Display
- **Path Line**: Teal (Color(0xFF00BCD4)), 4px stroke
- **Animation**: Progressive drawing over 1.2 seconds
- **Waypoint Dots**: White 4px circles with teal border
- **Start Marker**: Blue dot (8px) with radiating circle
- **End Marker**: Pulsing green circle (16-24px) with white center
- **Shadow**: 8px blur, 30% opacity

#### Bottom Info Card (75px from bottom)
- Shows current location name
- Blue location icon
- White text on dark navy card

#### Directions Banner (24px from bottom)
- Appears when destination selected
- Shows destination name and floor
- **Info Button**: Outlined, white
- **Get Directions Button**: Blue, with icon
- **Close Button**: X icon to clear destination

#### Floating Action Buttons (110px from bottom)
- **Locate Button**: Blue (Color(0xFF2979FF))
  - Icon: my_location or signal_wifi_off
  - Triggers WiFi scan and ML prediction
  - Animates camera to predicted location
  - Disabled if WiFi off (gray)
- **Test Random Button**: Green/Red toggle
  - Green when stopped, Red when running
  - Tests random location from test data
  - Shows ground truth vs prediction
  - Runs every 5 seconds when active

**APIs Used**:
- `GET /admin/map_base64/{floor}` - Load map image
- `GET /admin/locations/{floor}` - Load locations
- `POST /getlocation` - Predict location from WiFi
- `POST /navigation/path` - Calculate shortest path
- `GET /admin/testdata` - Load test data

**State Variables**:
```dart
Map<String, Offset> roomPositions = {};
String selectedDestination = '';
String predictedRoom = '';
String currentFloor = '1';
List<Offset> _shortestPath = [];
Uint8List? _mapImageBytes;
bool _isLoading = true;
bool _isTesting = false;
bool _wifiDisabled = false;
```

**Animations**:
- User marker pulse (600ms)
- Destination marker pulse (600ms)
- Path drawing (1200ms)
- Camera zoom/pan (smooth)

---


### 3. Admin Dashboard (`admin_dashboard_screen.dart`)

**Purpose**: Central hub for all admin features

**Features**:

#### App Bar
- Title: "Admin Dashboard"
- Subtitle: Username
- Back button to map screen

#### 6 Main Cards (Grid Layout)

**1. Floor Plans & Navigation**
- Icon: map (purple)
- Navigate to: Floor Plan Screen
- Purpose: Manage maps and create walkable graphs

**2. Location Marking**
- Icon: location_on (teal)
- Navigate to: Location Marking Screen
- Purpose: Mark and edit room positions

**3. Training Data Collection**
- Icon: wifi (blue)
- Navigate to: Training Data Screen
- Purpose: Collect WiFi fingerprints

**4. Training Data Management**
- Icon: storage (orange)
- Navigate to: Training Data Management Screen
- Purpose: View, edit, delete training records

**5. Model Retraining**
- Icon: model_training (green)
- Navigate to: Model Training Screen
- Purpose: Retrain ML model

**6. Statistics Dashboard**
- Icon: analytics (pink)
- Navigate to: Statistics Screen
- Purpose: View system analytics

**UI Design**:
- 2 columns on tablet, 1 on mobile
- Cards: Dark navy (Color(0xFF132F4C))
- Hover effect: Slight scale
- Icon size: 48px
- Card padding: 24px
- Spacing: 16px

---

### 4. Floor Plan Screen (`floor_plan_screen.dart`) - 950+ lines

**Purpose**: Manage floor maps and create walkable graphs

**Structure**: 3 screens in one file

#### Screen 1: Gallery View (FloorPlanScreen)

**Features**:
- Grid of 3 floor cards (Floor 1, 2, 3)
- Each card shows map preview or upload prompt
- Tap card to open detail view
- Refresh button in app bar

**UI Elements**:
- Grid: 2 columns on tablet, 2 on mobile
- Card aspect ratio: 0.75
- Floor badge: Bottom-left corner
- Colors: Floor 1 (blue), Floor 2 (teal), Floor 3 (purple)
- Empty state: Upload icon with "No map uploaded"

**APIs**:
- `GET /admin/map_base64/{floor}` - Load all maps
- `POST /admin/upload_map/{floor}` - Upload new map

#### Screen 2: Detail View (FloorDetailScreen)

**Features**:
- Two-mode toggle: View Map / Edit Paths
- Mode buttons in app bar bottom
- Switches between MapViewMode and PathEditorView

**Mode Buttons**:
- View Map: map_outlined icon
- Edit Paths: edit_road icon
- Selected: Blue background
- Unselected: Transparent with border

#### Screen 3A: View Map Mode (MapViewMode)

**Features**:
- Interactive viewer with zoom/pan
- Read-only overlay showing:
  - Purple location pins (Color(0xFF7C4DFF), 50% opacity)
  - Blue edges (40% opacity, 2px)
  - Hollow node circles (6px, white border)
  - Location name labels

**Bottom Buttons**:
- Replace Map: Blue button with upload icon
- Go to Locations: Teal button with location icon

**Custom Painter**: MapViewPainter
- Draws edges as lines
- Draws nodes as circles
- Draws location pins as custom shapes (circle + triangle)
- Draws text labels

#### Screen 3B: Edit Paths Mode (PathEditorView)

**Purpose**: Professional graph editor for creating walkable networks

**Toolbar** (Top, horizontal):
- **Add Node**: Toggle button, teal when active
- **Add Edge**: Toggle button, teal when active
- **Delete**: Toggle button, orange when active
- **Clear All**: Red button with confirmation
- **Save Graph**: Blue accent button

**Interaction Modes**:

1. **Add Node Mode**:
   - Tap anywhere on map to place node
   - Node appears as teal circle (10px radius)
   - UUID generated automatically
   - Coordinates normalized (0-1)
   - No confirmation needed

2. **Add Edge Mode**:
   - First tap: Select "from" node (turns green)
   - Second tap: Select "to" node (creates edge)
   - Same node twice: Deselect
   - Duplicate edge: Show warning, don't create
   - Edge appears as blue line (3px, 60% opacity)

3. **Delete Mode**:
   - Tap node: Show confirmation snackbar with undo
   - Tap edge: Delete immediately with undo
   - Deleting node: Also deletes connected edges
   - Hit detection: 20px for nodes, 10px for edges

**Visual Feedback**:
- Default nodes: Teal (Color(0xFF00BCD4))
- Selected node (edge mode): Green (Color(0xFF00C853))
- Selected node (other): Orange (Color(0xFFFF6D00))
- Edges: Blue (Color(0xFF2979FF)), 60% opacity
- Location pins: Purple (Color(0xFF7C4DFF)), 50% opacity, read-only

**Safety Features**:
- Unsaved changes warning (WillPopScope)
- Delete node confirmation
- Clear all confirmation dialog
- Duplicate edge prevention
- Real-time stats display (nodes/edges count)

**Stats Display** (Top-right):
- Shows: X nodes, Y edges
- Shows: "Unsaved changes" if modified
- Updates in real-time

**Custom Painter**: PathEditorPainter
- Draws edges with hover detection
- Draws nodes with selection states
- Draws location pins (read-only)
- Handles hit detection

**APIs**:
- `GET /admin/graph/{floor}` - Load graph
- `POST /admin/graph/{floor}` - Save graph
- `GET /admin/locations/{floor}` - Load locations

**State Variables**:
```dart
List<GraphNode> _nodes = [];
List<GraphEdge> _edges = [];
List<LocationPin> _locations = [];
String _activeMode = 'none';
String? _selectedNodeId;
bool _hasUnsavedChanges = false;
Size? _imageSize;
```

---


### 5. Location Marking Screen (`location_marking_screen.dart`) - 1230+ lines

**Purpose**: Mark and manage location positions on floor maps

**Layout**: Two-panel responsive design

#### Top Section: Floor Selector
- 3 segmented chips: Floor 1, 2, 3
- Selected: Blue background
- Unselected: Transparent with border
- Full width, equal spacing

#### Main Area: Two Panels

**Desktop/Tablet**: Side-by-side (60% map, 40% list)
**Mobile**: Top/bottom (60% map, 40% list)

#### Left/Top Panel: Map Panel

**Features**:
- Interactive viewer with zoom/pan (0.5x to 5.0x)
- Transform controller for programmatic camera
- Tap to select locations
- Shows graph overlay (faint)

**Visual Elements**:
- **Location Pins**: Custom painted (circle + triangle, 24px)
  - Default: Blue (Color(0xFF2979FF))
  - Selected: Green (Color(0xFF00C853)) with pulse
  - Pulse animation: 0.9-1.1 scale, 800ms
- **Graph Nodes**: Hollow circles (4px, 30% opacity)
- **Graph Edges**: Thin blue lines (1px, 20% opacity)

**Placement Mode**:
- Banner appears: "Tap map to place location"
- Cursor changes
- Tap map → Opens bottom sheet
- Cancel button to exit mode

**Custom Painter**: LocationMapPainter
- Draws graph edges (faint)
- Draws graph nodes (hollow)
- Draws location pins with pulse
- Draws location name labels

#### Right/Bottom Panel: List Panel

**Features**:
- Scrollable list of all locations
- Each item shows:
  - Location name (bold)
  - Landmark (subtitle)
  - Floor badge
  - Connection status icon (linked/unlinked)
- Tap item: Selects and centers on map
- Swipe left: Delete with confirmation
- Long press: Enter multi-select mode

**Multi-Select Mode**:
- Long press any item to enter
- Checkboxes appear
- Select multiple locations
- Bulk delete button in app bar
- Exit by tapping back or cancel

**Empty State**:
- Illustrated card
- "No locations marked on this floor"
- "Tap + to add your first location"

#### Floating Action Button
- Label: "Add Location"
- Icon: add_location_alt
- Color: Teal (Color(0xFF00BCD4))
- Action: Enter placement mode

#### Bottom Sheet: Add Location

**Triggered by**: Tapping map in placement mode

**Fields**:
1. **Location Name** (required)
   - Text field
   - Hint: "e.g. Room 101, Lab, Corridor"
   - Validation: Cannot be empty

2. **Landmark** (optional)
   - Text field
   - Hint: "e.g. Near main entrance"

3. **Connect to Node** (optional)
   - Dropdown
   - Shows 3 nearest nodes
   - Format: "Node at (X%, Y%) - Zpx away"
   - Auto-calculated distances

**Buttons**:
- Cancel: Text button
- Add Location: Blue elevated button

**API**: `POST /admin/locations/{floor}`

#### Location Detail Peek Card

**Triggered by**: Tapping location pin on map

**Position**: Bottom of screen, slides up

**Content**:
- Location icon (green)
- Location name (bold)
- Connection status:
  - If linked: "Connected to node at (X%, Y%)"
  - If not: "Not connected to any node" (orange)

**Action Buttons** (3 buttons, equal width):
1. **Edit**: Blue outlined
   - Opens edit sheet
   - Can change name
   - Can move on map
   
2. **Snap**: Teal outlined
   - Opens node picker
   - Shows 5 nearest nodes with distances
   - Re-links to different node
   
3. **Delete**: Red outlined
   - Shows confirmation dialog
   - Deletes location

**Close Button**: X icon top-right

#### Edit Location Sheet

**Fields**:
- Name (editable)
- Landmark (editable)
- X position (read-only, shown for reference)
- Y position (read-only, shown for reference)

**Buttons**:
- Move on Map: Enters move mode
- Cancel: Dismisses sheet
- Save: Updates location

**Move Mode**:
- Sheet dismisses
- Banner appears: "Tap new position"
- Tap map: Moves location
- Auto-saves and exits mode

**API**: `PUT /admin/location/{id}`

#### Snap to Node Sheet

**Content**:
- Shows 5 nearest nodes
- Each item:
  - Node position (X%, Y%)
  - Distance in pixels
  - Current connection indicator
- Tap to select

**API**: `PUT /admin/location/{id}/link-node`

#### APIs Used
- `GET /admin/map_base64/{floor}` - Load map
- `GET /admin/locations/{floor}` - Load locations
- `GET /admin/graph/{floor}` - Load graph
- `POST /admin/locations/{floor}` - Create location
- `PUT /admin/location/{id}` - Update location
- `DELETE /admin/location/{id}` - Delete location
- `PUT /admin/location/{id}/link-node` - Link to node

**State Variables**:
```dart
int _currentFloor = 1;
List<LocationMarker> _locations = [];
List<GraphNode> _graphNodes = [];
List<GraphEdge> _graphEdges = [];
String? _selectedLocationId;
bool _isPlacementMode = false;
bool _isMoveMode = false;
String? _movingLocationId;
bool _isMultiSelectMode = false;
Set<String> _selectedLocationIds = {};
Size? _imageSize;
```

---


### 6. Training Data Screen (`training_data_screen.dart`)

**Purpose**: Collect WiFi fingerprints for ML training

**Features**:

#### Top Section
- Floor selector (1, 2, 3)
- Location name input
- Landmark input (optional)

#### WiFi Scan Section
- **Scan Button**: Large blue button
- **Status**: Shows "Scanning..." or "Ready"
- **Results**: List of detected WiFi networks
  - SSID
  - BSSID
  - Signal strength (dBm)
  - Frequency
  - Capabilities

#### Scan Results Display
- Card for each network
- Color-coded by signal strength:
  - Strong (>-50 dBm): Green
  - Medium (-50 to -70 dBm): Orange
  - Weak (<-70 dBm): Red
- Shows network details

#### Submit Section
- **Submit Button**: Green button
- Validates: Location name required
- Shows success/error toast
- Clears form on success

**APIs**:
- `POST /admin/training-data` - Submit scans

**WiFi Scanning**:
- Uses wifi_scan package
- Requests permissions
- Scans all available networks
- Extracts: SSID, BSSID, signal, frequency, bandwidth

---

### 7. Training Data Management Screen (`training_data_management_screen.dart`)

**Purpose**: View, edit, and delete training records

**Features**:

#### Top Filters
- **Floor Filter**: Dropdown (All, 1, 2, 3)
- **Source Filter**: Dropdown (All, train, test)
- **Location Filter**: Dropdown (All locations)
- **Search**: Text field for BSSID/SSID

#### Data Display Modes

**1. List View**:
- Paginated table (50 records per page)
- Columns: SSID, BSSID, Signal, Location, Floor, Source, Date
- Sort by any column
- Select rows for bulk operations

**2. Grouped View**:
- Groups by location + floor
- Shows count per group
- Expandable cards
- Bulk operations per group

#### Actions

**Single Record**:
- Edit: Opens dialog to change location/floor
- Delete: Confirmation dialog

**Bulk Operations**:
- Select multiple records
- Bulk edit: Change location/floor for all
- Bulk delete: Delete all selected
- Merge locations: Combine multiple locations into one

#### Pagination
- Page numbers at bottom
- Previous/Next buttons
- Shows: "Showing X-Y of Z records"

#### Export
- Export to CSV button
- Filters applied to export
- Downloads file

**APIs**:
- `GET /admin/training-records` - Paginated list
- `GET /admin/training-records/grouped` - Grouped view
- `GET /admin/training-records/locations` - Location list
- `PUT /admin/training-records/{id}` - Update record
- `DELETE /admin/training-records/{id}` - Delete record
- `PUT /admin/training-records/bulk` - Bulk update
- `DELETE /admin/training-records/bulk` - Bulk delete
- `POST /admin/training-records/merge` - Merge locations
- `GET /admin/training-records/export` - Export CSV

---

### 8. Model Training Screen (`model_training_screen.dart`)

**Purpose**: Retrain ML model with new data

**Features**:

#### Stats Display
- Total training records
- Total test records
- Locations count
- Last trained date

#### Training Section
- **Retrain Button**: Large green button
- Shows progress during training
- Success/error messages
- Estimated time display

#### Model Info
- Current model accuracy
- Training date
- Model file size
- Feature count

**APIs**:
- `GET /admin/training-stats` - Get stats
- `POST /admin/retrain` - Trigger retraining

**Training Process**:
1. Fetches all training data
2. Preprocesses features
3. Trains Random Forest model
4. Saves model to disk
5. Returns accuracy metrics

---

### 9. Statistics Screen (`statistics_screen.dart`)

**Purpose**: View system analytics

**Features**:

#### Overview Cards
- Total locations
- Total training records
- Total users
- Model accuracy

#### Charts
- Locations per floor (bar chart)
- Training data distribution (pie chart)
- Signal strength distribution (histogram)
- Accuracy over time (line chart)

#### Recent Activity
- Recent predictions
- Recent training data additions
- Recent location updates

**APIs**:
- `GET /admin/training-stats` - Get statistics
- Custom aggregation queries

---


## API Endpoints Reference

### Authentication
- `POST /auth/login` - User login
  - Body: `{username, password}`
  - Returns: `{success, user: {username, role, display_name}}`

### Map Management
- `GET /admin/map_base64/{floor}` - Get map as base64
  - Returns: `{base64: "..."}`
- `POST /admin/upload_map/{floor}` - Upload new map
  - Body: Multipart form with file
  - Returns: `{success, message}`

### Location Management
- `GET /locations/all` - Get all locations (all floors)
- `GET /admin/locations/{floor}` - Get locations for floor
  - Returns: `[{id, name, x, y, floor, landmark, node_id}]`
- `POST /admin/locations/{floor}` - Create/update locations
  - Body: `[{name, x, y, landmark?, node_id?}]`
  - Returns: `{success, message}`
- `PUT /admin/location/{id}` - Update single location
  - Body: `{name, x, y, landmark?, node_id?}`
  - Returns: `{success, message}`
- `DELETE /admin/location/{id}` - Delete location
  - Returns: `{success, message}`
- `PUT /admin/location/{id}/link-node` - Link to graph node
  - Body: `{node_id}`
  - Returns: `{success, message}`

### Graph Management
- `GET /admin/graph/{floor}` - Get walkable graph
  - Returns: `{exists, nodes: [{id, x, y, label}], edges: [{id, from_node, to_node, weight}]}`
- `POST /admin/graph/{floor}` - Save graph
  - Body: `{nodes: [...], edges: [...]}`
  - Returns: `{success, message}`
- `DELETE /admin/graph/{floor}` - Delete graph
  - Returns: `{success, message}`

### Pathfinding
- `POST /navigation/path` - Calculate shortest path
  - Body: `{floor, from_location, to_location}`
  - Returns: `{found, path_nodes: [{x, y}], total_distance, estimated_seconds}`

### Location Prediction
- `POST /getlocation` - Predict location from WiFi
  - Body: `[{BSSID, Signal Strength dBm}]`
  - Returns: `[{predicted, source}]`

### Training Data
- `POST /admin/training-data` - Submit training data
  - Body: `{location, landmark, floor, scans: [{ssid, bssid, signal, ...}]}`
  - Returns: `{success, message, records_added}`
- `GET /admin/training-records` - Get paginated records
  - Query: `?page=1&limit=50&floor=1&location=Room&source=train`
  - Returns: `{records: [...], total, page, limit, pages}`
- `GET /admin/training-records/grouped` - Get grouped records
  - Query: `?floor=1`
  - Returns: `{location: {count, records: [...]}}`
- `GET /admin/training-records/locations` - Get location list
  - Returns: `[{location, floor, count}]`
- `PUT /admin/training-records/{id}` - Update record
  - Body: `{location?, floor?, ...}`
  - Returns: `{success, message}`
- `DELETE /admin/training-records/{id}` - Delete record
  - Returns: `{success, message}`
- `PUT /admin/training-records/bulk` - Bulk update
  - Body: `{ids: [...], updates: {...}}`
  - Returns: `{success, modified_count}`
- `DELETE /admin/training-records/bulk` - Bulk delete
  - Body: `{ids: [...]}`
  - Returns: `{success, deleted_count}`
- `DELETE /admin/training-records/group/{location}` - Delete group
  - Query: `?floor=1`
  - Returns: `{success, deleted_count}`
- `POST /admin/training-records/merge` - Merge locations
  - Body: `{source_locations: [...], target_location, floor, delete_sources}`
  - Returns: `{success, merged_count}`
- `GET /admin/training-records/export` - Export CSV
  - Query: `?floor=1&source=train`
  - Returns: CSV file (bytes)

### Model Training
- `GET /admin/training-stats` - Get training statistics
  - Returns: `{total_records, total_test, locations_count, last_trained}`
- `POST /admin/retrain` - Trigger model retraining
  - Returns: `{success, message, accuracy?}`

### Test Data
- `GET /admin/testdata` - Get test data
  - Returns: `[{Location, BSSID, Signal Strength dBm, ...}]`

---


## Data Models (`frontend/lib/models/graph_models.dart`)

### GraphNode
```dart
class GraphNode {
  final String id;           // UUID
  final double x;            // 0.0 to 1.0 (normalized)
  final double y;            // 0.0 to 1.0 (normalized)
  final String? label;       // Optional label
  
  // Methods
  factory GraphNode.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  GraphNode copyWith({...})
  Offset toPixelOffset(Size imageSize)
  factory GraphNode.fromPixelOffset({...})
}
```

### GraphEdge
```dart
class GraphEdge {
  final String id;           // UUID
  final String fromNodeId;   // Node ID
  final String toNodeId;     // Node ID
  final double? weight;      // Optional, calculated on backend
  
  // Methods
  factory GraphEdge.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  GraphEdge copyWith({...})
  bool connectsTo(String nodeId)
  String? getOtherNode(String nodeId)
}
```

### WalkableGraph
```dart
class WalkableGraph {
  final int floor;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final DateTime? updatedAt;
  
  // Methods
  factory WalkableGraph.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  bool get isEmpty
  bool get isNotEmpty
  GraphNode? getNode(String nodeId)
  List<GraphEdge> getEdgesForNode(String nodeId)
  List<GraphNode> getNeighbors(String nodeId)
}
```

### NavigationPath
```dart
class NavigationPath {
  final List<Offset> points;        // Normalized coordinates
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

### LocationMarker
```dart
class LocationMarker {
  final String id;
  final String name;
  final String? landmark;
  final int floor;
  final double x;              // 0.0 to 1.0 (normalized)
  final double y;              // 0.0 to 1.0 (normalized)
  final String? nodeId;        // Linked graph node
  
  // Methods
  factory LocationMarker.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
  LocationMarker copyWith({...})
  Offset toPixelOffset(Size imageSize)
  factory LocationMarker.fromPixelOffset({...})
  bool get isLinked
  String get displayText
}
```

### CoordinateConverter
```dart
class CoordinateConverter {
  static Offset normalizedToPixel(double x, double y, Size imageSize)
  static Offset pixelToNormalized(Offset position, Size imageSize)
  static List<Offset> normalizedListToPixel(List<Offset> points, Size imageSize)
  static List<Offset> pixelListToNormalized(List<Offset> points, Size imageSize)
  static Offset clampNormalized(Offset position)
}
```

---

## Database Schema

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

### locations Collection
```json
{
  "_id": ObjectId,
  "id": "string (UUID)",
  "floor": int,
  "name": "string",
  "x": float,
  "y": float,
  "landmark": "string (optional)",
  "node_id": "string (optional)"
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

### walkable_graph Collection
```json
{
  "_id": ObjectId,
  "floor": int,
  "nodes": [
    {
      "id": "string (UUID)",
      "x": float,
      "y": float,
      "label": "string"
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

---


## Key Algorithms

### 1. Dijkstra's Shortest Path
**File**: `backend/services/pathfinding_service.py`

**Implementation**:
```python
def dijkstra(self, adjacency: Dict, start_node: str, end_node: str) -> Optional[List[str]]:
    # Priority queue: (distance, node_id)
    # Tracks: distances, previous nodes, visited
    # Returns: List of node IDs in path order
```

**Complexity**: O((V + E) log V)
- V = number of nodes
- E = number of edges

**Features**:
- Handles disconnected graphs
- Returns None if no path exists
- Calculates total distance
- Estimates time (assuming 1.4 m/s walking speed)

### 2. WiFi Fingerprinting (Random Forest)
**File**: `backend/services/model_service.py`

**Features**:
- Extracts features: BSSID, signal strength
- Trains Random Forest classifier
- Predicts location from WiFi scan
- Returns confidence score

**Training Data Format**:
```python
X = [[bssid1_signal, bssid2_signal, ...], ...]
y = ['Room 101', 'Room 102', ...]
```

### 3. Nearest Node Finding
**File**: `backend/services/pathfinding_service.py`

**Implementation**:
```python
def find_nearest_node(self, nodes: Dict, x: float, y: float) -> Optional[str]:
    # Calculates Euclidean distance to all nodes
    # Returns ID of closest node
```

**Formula**: `distance = sqrt((x1-x2)^2 + (y1-y2)^2)`

### 4. Edge Weight Calculation
**Automatic on backend when saving graph**

**Formula**: Euclidean distance between nodes
```python
weight = sqrt((x1-x2)^2 + (y1-y2)^2)
```

---

## Animation Details

### 1. Pulse Animation (Location Markers)
```dart
AnimationController(
  vsync: this,
  duration: Duration(milliseconds: 800),
  lowerBound: 0.9,
  upperBound: 1.1,
)..repeat(reverse: true);
```

**Usage**: Selected locations, destination markers

### 2. Marker Pulse Animation (User/Destination)
```dart
AnimationController(
  vsync: this,
  duration: Duration(milliseconds: 600),
  lowerBound: 0.7,
  upperBound: 1.0,
)..repeat(reverse: true);
```

**Usage**: Current location, selected destination

### 3. Path Drawing Animation
```dart
AnimationController(
  vsync: this,
  duration: Duration(milliseconds: 1200),
);

// In CustomPainter
final pathMetrics = path.computeMetrics().first;
final totalLength = pathMetrics.length;
final currentLength = totalLength * animation.value;
final extractedPath = pathMetrics.extractPath(0, currentLength);
```

**Effect**: Progressive path drawing from start to end

### 4. Camera Animation
```dart
final Matrix4 endMatrix = Matrix4.identity()
  ..translate(transX, transY)
  ..scale(targetScale);

_transformationController.value = endMatrix;
```

**Effect**: Smooth zoom and pan to location

---

## Common Patterns

### 1. Loading State Pattern
```dart
bool _isLoading = true;

@override
void initState() {
  super.initState();
  _loadData();
}

Future<void> _loadData() async {
  setState(() => _isLoading = true);
  // Load data
  setState(() => _isLoading = false);
}

@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return Center(child: CircularProgressIndicator());
  }
  return ActualContent();
}
```

### 2. API Call Pattern
```dart
Future<void> _saveData() async {
  try {
    final success = await ApiService.saveWalkableGraph(floor, nodes, edges);
    if (success) {
      _showSnackBar('Saved successfully!', Colors.green);
    } else {
      _showSnackBar('Failed to save', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}
```

### 3. Confirmation Dialog Pattern
```dart
void _deleteWithConfirmation() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF1E293B),
      title: Text('Confirm Delete', style: GoogleFonts.outfit(color: Colors.white)),
      content: Text('Are you sure?', style: GoogleFonts.inter(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () {
            Navigator.pop(context);
            _performDelete();
          },
          child: Text('Delete'),
        ),
      ],
    ),
  );
}
```

### 4. SnackBar Pattern
```dart
void _showSnackBar(String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
```

### 5. Bottom Sheet Pattern
```dart
Future<Map<String, dynamic>?> _showBottomSheet() async {
  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: YourContent(),
      ),
    ),
  );
}
```

---


## Important Technical Details

### Coordinate System
- **Normalized**: 0.0 to 1.0 (stored in database)
- **Pixel**: Actual screen/image coordinates (used for rendering)
- **Conversion**: Always convert when drawing or saving

**Why Normalized?**
- Resolution-independent
- Works on all devices
- Scales automatically

**Conversion Examples**:
```dart
// Normalized to Pixel
final pixelX = normalizedX * imageWidth;
final pixelY = normalizedY * imageHeight;

// Pixel to Normalized
final normalizedX = pixelX / imageWidth;
final normalizedY = pixelY / imageHeight;
```

### Image Handling
1. Backend stores in GridFS
2. API returns base64 string
3. Frontend decodes to Uint8List
4. Displays with Image.memory()

```dart
final b64 = await ApiService.getMapBase64(floor);
final bytes = base64Decode(b64);
setState(() => _mapImageBytes = bytes);
```

### Image Size Detection
```dart
void _calculateImageSize(Uint8List bytes) {
  final image = Image.memory(bytes);
  image.image.resolve(ImageConfiguration()).addListener(
    ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }
    }),
  );
}
```

### Hit Detection

**Nodes** (20px threshold):
```dart
String? _findNodeAtPosition(Offset position) {
  for (var node in _nodes) {
    final nodePos = Offset(node.x * _imageSize.width, node.y * _imageSize.height);
    final distance = (position - nodePos).distance;
    if (distance <= 20) return node.id;
  }
  return null;
}
```

**Edges** (10px point-to-line distance):
```dart
double _pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
  final dx = lineEnd.dx - lineStart.dx;
  final dy = lineEnd.dy - lineStart.dy;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return (point - lineStart).distance;
  
  final t = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / lengthSquared;
  final clampedT = t.clamp(0.0, 1.0);
  final projection = Offset(lineStart.dx + clampedT * dx, lineStart.dy + clampedT * dy);
  
  return (point - projection).distance;
}
```

### WiFi Scanning (Android)
```dart
// Check permission
final canScan = await WiFiScan.instance.canStartScan();

if (canScan == CanStartScan.yes) {
  // Start scan
  await WiFiScan.instance.startScan();
  
  // Get results
  final results = await WiFiScan.instance.getScannedResults();
  
  // Extract data
  final payload = results.map((ap) => {
    'BSSID': ap.bssid,
    'Signal Strength dBm': ap.level,
  }).toList();
}
```

### State Management (Provider)
```dart
// app_state.dart
class AppState extends ChangeNotifier {
  String _userType = '';
  bool _isAdmin = false;
  
  String get userType => _userType;
  bool get isAdmin => _isAdmin;
  
  void setUser(String username, bool isAdmin) {
    _userType = username;
    _isAdmin = isAdmin;
    notifyListeners();
  }
  
  Future<void> logout() async {
    _userType = '';
    _isAdmin = false;
    notifyListeners();
  }
}

// Usage in widgets
final appState = Provider.of<AppState>(context, listen: false);
if (appState.isAdmin) {
  // Show admin features
}
```

### Navigation
```dart
// Named routes in main.dart
routes: {
  '/login': (context) => LoginScreen(),
  '/map': (context) => MapScreen(),
  '/admin_dashboard': (context) => AdminDashboardScreen(),
  '/admin/floor_plans': (context) => FloorPlanScreen(),
  '/admin/location_marking': (context) => LocationMarkingScreen(),
  // ... more routes
}

// Navigate
Navigator.pushNamed(context, '/admin_dashboard');

// Navigate and remove all previous
Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
```

---

## Performance Considerations

### 1. Image Loading
- Use base64 caching
- Decode once, reuse Uint8List
- Don't reload on every rebuild

### 2. Custom Painters
- Only repaint when necessary
- Use `shouldRepaint()` wisely
- Cache paint objects

```dart
@override
bool shouldRepaint(covariant CustomPainter oldDelegate) {
  return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
}
```

### 3. List Performance
- Use `ListView.builder()` for long lists
- Implement pagination for large datasets
- Use `const` constructors where possible

### 4. Animation Performance
- Dispose controllers in `dispose()`
- Use `vsync: this` with `TickerProviderStateMixin`
- Limit concurrent animations

### 5. API Calls
- Implement timeouts (10-15 seconds)
- Show loading indicators
- Cache responses when appropriate
- Debounce search inputs

---

## Error Handling Best Practices

### 1. API Errors
```dart
try {
  final result = await ApiService.someMethod();
  if (result != null) {
    // Success
  } else {
    // API returned null (error occurred)
    _showSnackBar('Operation failed', Colors.red);
  }
} catch (e) {
  // Network error or exception
  _showSnackBar('Error: $e', Colors.red);
  print('Error details: $e');
}
```

### 2. User Input Validation
```dart
void _validateAndSubmit() {
  if (_nameController.text.trim().isEmpty) {
    _showSnackBar('Name is required', Colors.orange);
    return;
  }
  
  if (_coordinates == null) {
    _showSnackBar('Please select a position', Colors.orange);
    return;
  }
  
  _submit();
}
```

### 3. Null Safety
```dart
// Use null-aware operators
final name = location?.name ?? 'Unknown';

// Check before accessing
if (imageSize != null) {
  final pixel = node.toPixelOffset(imageSize);
}

// Use whereType to filter nulls
final validNodes = nodes.map((n) => getNode(n.id)).whereType<GraphNode>().toList();
```

---

## Testing Checklist

### Backend Testing
- [ ] All API endpoints return correct status codes
- [ ] Authentication works for admin and student
- [ ] Graph CRUD operations work
- [ ] Pathfinding returns correct paths
- [ ] WiFi prediction works
- [ ] Training data CRUD works
- [ ] Model retraining works

### Frontend Testing
- [ ] Login works for both roles
- [ ] Map loads and displays correctly
- [ ] Location prediction works
- [ ] Search and autocomplete work
- [ ] Floor switching works
- [ ] Path editor: Add node works
- [ ] Path editor: Add edge works
- [ ] Path editor: Delete works
- [ ] Path editor: Save works
- [ ] Location marking: Add works
- [ ] Location marking: Edit works
- [ ] Location marking: Delete works
- [ ] Location marking: Snap to node works
- [ ] Animated path displays correctly
- [ ] All animations are smooth (60 FPS)
- [ ] No memory leaks (controllers disposed)

### Integration Testing
- [ ] End-to-end: Create graph → Mark locations → Navigate
- [ ] End-to-end: Collect data → Train model → Predict
- [ ] Multi-floor navigation works
- [ ] Offline handling works
- [ ] Error messages are user-friendly

---


## Common Issues and Solutions

### Issue 1: Map Not Loading
**Symptoms**: Blank screen, no map image
**Causes**:
- Backend not running
- Wrong base URL
- Map not uploaded for floor
- Base64 decode error

**Solutions**:
```dart
// Check backend connection
print('API URL: ${ApiService.baseUrl}');

// Check response
final b64 = await ApiService.getMapBase64(floor);
if (b64 == null) {
  print('No map data received');
  return;
}

// Check decode
try {
  final bytes = base64Decode(b64);
  print('Decoded ${bytes.length} bytes');
} catch (e) {
  print('Decode error: $e');
}
```

### Issue 2: Coordinates Not Converting Correctly
**Symptoms**: Markers in wrong positions
**Causes**:
- Image size not calculated
- Using pixel coordinates instead of normalized
- Wrong conversion formula

**Solutions**:
```dart
// Always check image size first
if (_imageSize == null) {
  print('Image size not calculated yet');
  return;
}

// Use helper methods
final pixelPos = node.toPixelOffset(_imageSize!);
final normalizedPos = CoordinateConverter.pixelToNormalized(tapPos, _imageSize!);
```

### Issue 3: Path Not Animating
**Symptoms**: Path appears instantly or not at all
**Causes**:
- Animation controller not initialized
- Animation not started
- Path points empty

**Solutions**:
```dart
// Initialize controller
_pathAnimationController = AnimationController(
  vsync: this,
  duration: Duration(milliseconds: 1200),
);

// Start animation
_pathAnimationController.reset();
_pathAnimationController.forward();

// Check path
if (_shortestPath.isEmpty) {
  print('No path to animate');
  return;
}
```

### Issue 4: WiFi Scan Not Working
**Symptoms**: No networks found
**Causes**:
- Permissions not granted
- WiFi disabled
- Android version issues

**Solutions**:
```dart
// Check WiFi status
final results = await Connectivity().checkConnectivity();
if (!results.contains(ConnectivityResult.wifi)) {
  print('WiFi is disabled');
  AppSettings.openAppSettings(type: AppSettingsType.wifi);
  return;
}

// Check scan permission
final canScan = await WiFiScan.instance.canStartScan();
if (canScan != CanStartScan.yes) {
  print('Cannot scan: $canScan');
  return;
}
```

### Issue 5: Graph Not Saving
**Symptoms**: Save button doesn't work
**Causes**:
- Empty nodes/edges
- Network error
- Backend error

**Solutions**:
```dart
// Validate data
if (_nodes.isEmpty) {
  _showSnackBar('No nodes to save', Colors.orange);
  return;
}

// Check response
final success = await ApiService.saveWalkableGraph(floor, nodesJson, edgesJson);
if (!success) {
  print('Save failed - check backend logs');
}
```

---

## Prompt Templates for AI

### Template 1: Add New Feature
```
I'm working on an indoor navigation app with Flutter and Flask.

CONTEXT:
- Frontend: Flutter with Material Design
- Backend: Flask REST API with MongoDB
- Design: Dark theme (Background: #0A1929, Cards: #132F4C)
- Typography: GoogleFonts.outfit() for headings, GoogleFonts.inter() for body
- Colors: Blue (#2979FF), Teal (#00BCD4), Green (#00C853), Orange (#FF6D00)
- No gradients, no blur effects, no box shadows

CURRENT FEATURE:
[Describe existing feature]

NEW FEATURE REQUEST:
[Describe what you want to add]

REQUIREMENTS:
- Follow existing design system
- Use normalized coordinates (0-1) for positions
- Include error handling
- Add loading states
- Follow existing code patterns

Please provide:
1. Code implementation
2. API endpoint (if needed)
3. Database schema changes (if needed)
4. Testing steps
```

### Template 2: Fix Bug
```
I'm working on an indoor navigation app with Flutter and Flask.

BUG DESCRIPTION:
[Describe the bug]

EXPECTED BEHAVIOR:
[What should happen]

ACTUAL BEHAVIOR:
[What actually happens]

RELEVANT CODE:
[Paste relevant code section]

ERROR MESSAGES:
[Paste any error messages]

CONTEXT:
- File: [filename]
- Screen: [screen name]
- Feature: [feature name]

Please provide:
1. Root cause analysis
2. Fix implementation
3. Prevention tips
```

### Template 3: Optimize Performance
```
I'm working on an indoor navigation app with Flutter and Flask.

PERFORMANCE ISSUE:
[Describe the performance problem]

CURRENT IMPLEMENTATION:
[Paste current code]

METRICS:
- Current FPS: [number]
- Load time: [seconds]
- Memory usage: [MB]

TARGET:
- Target FPS: 60
- Target load time: <2s
- Target memory: <100MB

Please provide:
1. Performance analysis
2. Optimization suggestions
3. Refactored code
4. Measurement approach
```

### Template 4: Add API Endpoint
```
I'm working on an indoor navigation app with Flask backend.

ENDPOINT REQUEST:
[Describe what the endpoint should do]

REQUEST FORMAT:
Method: [GET/POST/PUT/DELETE]
Path: [/api/path]
Body: [JSON structure]

RESPONSE FORMAT:
[Expected JSON response]

DATABASE:
Collection: [collection name]
Schema: [document structure]

REQUIREMENTS:
- Include error handling
- Add input validation
- Return appropriate status codes
- Add logging

Please provide:
1. Flask route implementation
2. Service layer code (if needed)
3. Database queries
4. Example curl command
```

### Template 5: Create New Screen
```
I'm working on an indoor navigation app with Flutter.

NEW SCREEN REQUEST:
[Describe the screen purpose]

FEATURES:
1. [Feature 1]
2. [Feature 2]
3. [Feature 3]

UI REQUIREMENTS:
- Design: Dark theme (Background: #0A1929, Cards: #132F4C)
- Typography: GoogleFonts.outfit() for headings, GoogleFonts.inter() for body
- Colors: Blue (#2979FF), Teal (#00BCD4), Green (#00C853)
- No gradients, no blur, no shadows

NAVIGATION:
- From: [source screen]
- Route: [route name]

API ENDPOINTS:
- [List required endpoints]

Please provide:
1. Complete screen implementation
2. State management
3. API integration
4. Navigation setup
5. Error handling
```

---

## Quick Reference

### Key Files
- **Main**: `frontend/lib/main.dart`
- **API**: `frontend/lib/api_service.dart`
- **Models**: `frontend/lib/models/graph_models.dart`
- **Map**: `frontend/lib/map_screen.dart`
- **Path Editor**: `frontend/lib/admin/floor_plan_screen.dart`
- **Locations**: `frontend/lib/admin/location_marking_screen.dart`
- **Backend**: `backend/app.py`, `backend/routes/api.py`
- **Pathfinding**: `backend/services/pathfinding_service.py`

### Key Commands
```bash
# Backend
cd backend && python app.py

# Frontend
cd frontend && flutter run

# Test API
curl -X POST http://localhost:5000/navigation/path \
  -H "Content-Type: application/json" \
  -d '{"floor":1,"from_location":"A","to_location":"B"}'
```

### Key Packages
**Frontend**:
- flutter
- http
- provider
- google_fonts
- wifi_scan
- connectivity_plus
- fluttertoast
- image_picker
- uuid

**Backend**:
- flask
- pymongo
- scikit-learn
- pandas
- numpy

---

## Summary

This document provides complete context for working with the indoor navigation system. Use it to:

1. **Understand the system**: Architecture, features, design
2. **Prepare AI prompts**: Use templates and context
3. **Debug issues**: Common problems and solutions
4. **Add features**: Follow patterns and best practices
5. **Maintain code**: Consistent style and structure

**Key Points**:
- Dark theme with specific colors
- Normalized coordinates (0-1)
- Graph-based pathfinding
- WiFi fingerprinting
- Professional UI/UX
- Comprehensive error handling

**Status**: ✅ Production-ready system with all core features complete

---

**Last Updated**: [Current Date]
**Version**: 1.0
**Total Lines**: 10,000+
**Total Files**: 20+
**Total Features**: 50+
