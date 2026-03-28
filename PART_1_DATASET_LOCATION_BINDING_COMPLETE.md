# Part 1 Complete - Dataset Location → Graph Node Binding ✅

## Problem Solved

Previously, the system had three disconnected components:
1. `training_data_records` - Real location names from WiFi dataset
2. `walkable_graph` - Nodes with (x, y) coordinates
3. `locations` collection - Name + coordinates

**The Gap**: Graph nodes didn't know which dataset location they represented, so WiFi prediction couldn't find where to start pathfinding.

**The Solution**: Direct Dataset Location → Graph Node binding. Each graph node can now be assigned a `dataset_location` that matches training data.

---

## Backend Changes Implemented

### 1. Updated walkable_graph Schema

Each node now has an optional `dataset_location` field:

```json
{
  "id": "uuid",
  "x": 0.45,
  "y": 0.62,
  "label": "optional corridor label",
  "dataset_location": "Room 101"
}
```

**Rules**:
- `dataset_location` is optional (null for corridor/junction nodes)
- Must match exact string from `training_data_records.location`
- **Uniqueness enforced**: Only one node per floor can have a given dataset_location
- When assigning to a new node, previous assignment is automatically removed

---

### 2. New Methods in PathfindingService

**File**: `backend/services/pathfinding_service.py`

#### `find_node_by_dataset_location(nodes, dataset_location)`
```python
def find_node_by_dataset_location(self, nodes: Dict, dataset_location: str) -> Optional[str]:
    """Find node ID that has the given dataset_location assigned"""
```

#### `get_dataset_locations(floor)`
```python
def get_dataset_locations(self, floor: int) -> List[Dict]:
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
```

#### `assign_dataset_location(floor, node_id, dataset_location)`
```python
def assign_dataset_location(self, floor: int, node_id: str, dataset_location: str) -> Dict:
    """
    Assign a dataset location to a node
    Ensures uniqueness: only one node per floor can have a given dataset_location
    Returns: {
        'success': bool,
        'message': str,
        'previous_node_id': str or None
    }
    """
```

**Features**:
- Checks if another node already has this dataset_location
- Unassigns from previous node automatically
- Assigns to target node
- Returns previous node ID if reassignment occurred

#### `unassign_dataset_location(floor, node_id)`
```python
def unassign_dataset_location(self, floor: int, node_id: str) -> Dict:
    """
    Remove dataset_location assignment from a node
    Returns: {'success': bool, 'message': str}
    """
```

#### `get_navigable_locations(floor=None)`
```python
def get_navigable_locations(self, floor: Optional[int] = None) -> List[Dict]:
    """
    Get only nodes that have dataset_location assigned (navigable destinations)
    Args:
        floor: Specific floor number, or None for all floors
    Returns: [{
        'location_name': str,
        'node_id': str,
        'x': float,
        'y': float,
        'floor': int,
        'record_count': int
    }]
    """
```

---

### 3. Updated calculate_path Method

**File**: `backend/services/pathfinding_service.py`

**Changes**:
- Now accepts `from_location` and `to_location` as dataset location name strings
- Looks up which node has `dataset_location == from_location`
- Looks up which node has `dataset_location == to_location`
- Returns `reason: 'location_not_mapped'` if either location is not assigned to a node
- Runs Dijkstra between the found nodes

**New Response Format**:
```json
{
  "path_nodes": [{"x": 0.34, "y": 0.56}, ...],
  "total_distance": 0.156,
  "estimated_seconds": 12,
  "found": true
}
```

**Or if location not mapped**:
```json
{
  "path_nodes": [],
  "total_distance": 0,
  "estimated_seconds": 0,
  "found": false,
  "reason": "location_not_mapped",
  "error": "Start location \"Room 101\" is not mapped to any graph node"
}
```

**Possible reasons**:
- `no_graph` - No walkable graph for floor
- `location_not_mapped` - Location not assigned to any node
- `no_path` - No walkable path between nodes
- `error` - Exception occurred

---

### 4. New API Endpoints

**File**: `backend/routes/api.py`

#### GET /admin/dataset-locations/{floor}

Get all distinct dataset locations for a floor with assignment status.

**Response**:
```json
[
  {
    "location": "Room 101",
    "floor": 1,
    "record_count": 45,
    "assigned_node_id": "uuid-or-null",
    "is_assigned": true
  },
  {
    "location": "Lab A",
    "floor": 1,
    "record_count": 32,
    "assigned_node_id": null,
    "is_assigned": false
  }
]
```

**Usage**: Populate dropdown in path editor for assigning locations to nodes.

---

#### PUT /admin/graph/{floor}/node/{node_id}/assign-location

Assign a dataset location to a node.

**Request**:
```json
{
  "dataset_location": "Room 101"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Assigned \"Room 101\" to node abc123 (unassigned from xyz789)",
  "previous_node_id": "xyz789"
}
```

**Features**:
- Enforces uniqueness (one location per node per floor)
- Automatically unassigns from previous node
- Returns previous node ID if reassignment occurred

---

#### PUT /admin/graph/{floor}/node/{node_id}/unassign-location

Remove dataset_location assignment from a node.

**Response**:
```json
{
  "success": true,
  "message": "Unassigned dataset location from node abc123"
}
```

---

#### GET /navigation/locations/{floor}

Get only nodes that have dataset_location set (navigable destinations) for a specific floor.

**Response**:
```json
[
  {
    "location_name": "Room 101",
    "node_id": "uuid",
    "x": 0.45,
    "y": 0.62,
    "floor": 1,
    "record_count": 45
  },
  {
    "location_name": "Lab A",
    "node_id": "uuid2",
    "x": 0.55,
    "y": 0.72,
    "floor": 1,
    "record_count": 32
  }
]
```

**Usage**: Map screen search - only show locations that are actually navigable.

---

#### GET /navigation/locations/all

Same as above but across all floors.

**Response**: Same format, includes all floors.

**Usage**: Map screen search across all floors.

---

### 5. Updated Location Prediction Endpoint

**Endpoint**: `POST /getlocation`

**New Response Format**:
```json
[{
  "predicted": "Room 101",
  "source": "flask_server",
  "is_navigable": true,
  "node_id": "uuid",
  "node_x": 0.45,
  "node_y": 0.62,
  "floor": 1
}]
```

**New Fields**:
- `is_navigable` (bool) - Whether location is mapped to a graph node
- `node_id` (str or null) - Graph node ID if mapped
- `node_x` (float or null) - Node x coordinate if mapped
- `node_y` (float or null) - Node y coordinate if mapped
- `floor` (int or null) - Floor number from training data

**Logic**:
1. Predict location from WiFi scan
2. Look up floor from training_data_records
3. Check if location is assigned to any node in that floor's graph
4. Return navigability information

---

## Testing the Backend

### 1. Get Dataset Locations for Floor 1

```bash
curl http://localhost:5000/admin/dataset-locations/1
```

**Expected**: List of all locations from training data with assignment status.

---

### 2. Assign Location to Node

```bash
curl -X PUT http://localhost:5000/admin/graph/1/node/node-uuid-123/assign-location \
  -H "Content-Type: application/json" \
  -d '{"dataset_location": "Room 101"}'
```

**Expected**:
```json
{
  "success": true,
  "message": "Assigned \"Room 101\" to node node-uuid-123",
  "previous_node_id": null
}
```

---

### 3. Get Navigable Locations

```bash
curl http://localhost:5000/navigation/locations/1
```

**Expected**: Only locations that are assigned to nodes.

---

### 4. Calculate Path with Dataset Locations

```bash
curl -X POST http://localhost:5000/navigation/path \
  -H "Content-Type: application/json" \
  -d '{
    "floor": 1,
    "from_location": "Room 101",
    "to_location": "Lab A"
  }'
```

**Expected** (if both mapped):
```json
{
  "path_nodes": [{"x": 0.45, "y": 0.62}, ...],
  "total_distance": 0.156,
  "estimated_seconds": 12,
  "found": true
}
```

**Expected** (if not mapped):
```json
{
  "path_nodes": [],
  "total_distance": 0,
  "estimated_seconds": 0,
  "found": false,
  "reason": "location_not_mapped",
  "error": "Start location \"Room 101\" is not mapped to any graph node"
}
```

---

### 5. Test Location Prediction with Navigability

```bash
curl -X POST http://localhost:5000/getlocation \
  -H "Content-Type: application/json" \
  -d '[
    {"BSSID": "aa:bb:cc:dd:ee:ff", "Signal Strength dBm": -45},
    {"BSSID": "11:22:33:44:55:66", "Signal Strength dBm": -60}
  ]'
```

**Expected**:
```json
[{
  "predicted": "Room 101",
  "source": "flask_server",
  "is_navigable": true,
  "node_id": "node-uuid-123",
  "node_x": 0.45,
  "node_y": 0.62,
  "floor": 1
}]
```

---

## Database Changes

### walkable_graph Collection

**Before**:
```json
{
  "floor": 1,
  "nodes": [
    {"id": "uuid", "x": 0.5, "y": 0.5, "label": ""}
  ],
  "edges": [...]
}
```

**After**:
```json
{
  "floor": 1,
  "nodes": [
    {
      "id": "uuid",
      "x": 0.5,
      "y": 0.5,
      "label": "",
      "dataset_location": "Room 101"
    }
  ],
  "edges": [...]
}
```

**Migration**: Existing graphs will work fine. The `dataset_location` field is optional and defaults to null.

---

## Key Features

### 1. Uniqueness Enforcement
- Only one node per floor can have a given dataset_location
- Automatic reassignment when assigning to a new node
- Previous node is unassigned automatically

### 2. Navigability Check
- WiFi prediction now returns whether location is navigable
- Map screen can filter search to only show navigable locations
- Clear error messages when location is not mapped

### 3. Dataset Integration
- Direct link between training data and graph nodes
- Record counts shown for each location
- Easy to see which locations are mapped vs unmapped

### 4. Backward Compatible
- Existing graphs work without modification
- `dataset_location` is optional
- Old API calls still work (with new fields added)

---

## Error Handling

### Location Not Mapped
```json
{
  "found": false,
  "reason": "location_not_mapped",
  "error": "Start location \"Room 101\" is not mapped to any graph node"
}
```

### No Graph for Floor
```json
{
  "found": false,
  "reason": "no_graph",
  "error": "No walkable graph found for this floor"
}
```

### No Path Between Nodes
```json
{
  "found": false,
  "reason": "no_path",
  "error": "No walkable path found between locations"
}
```

---

## Console Logging

All operations include detailed logging:

```
📊 DATASET LOCATIONS: Floor 1 - 15 locations
✅ ASSIGNED: Room 101 → Node abc123 (Floor 1)
   Unassigned from: xyz789
🗺️ NAVIGABLE LOCATIONS: Floor 1 - 8 locations
🗺️ PATHFINDING: Floor 1, Room 101 → Lab A
✅ PATH FOUND: 5 nodes, 0.16 distance
❌ NO PATH: Start location "Room 101" is not mapped to any graph node
```

---

## Files Modified

1. **backend/services/pathfinding_service.py**
   - Added `dataset_location` to node schema
   - Added `find_node_by_dataset_location()` method
   - Added `get_dataset_locations()` method
   - Added `assign_dataset_location()` method
   - Added `unassign_dataset_location()` method
   - Added `get_navigable_locations()` method
   - Updated `calculate_path()` to use dataset locations
   - Updated `build_graph()` to include dataset_location

2. **backend/routes/api.py**
   - Added `GET /admin/dataset-locations/{floor}`
   - Added `PUT /admin/graph/{floor}/node/{node_id}/assign-location`
   - Added `PUT /admin/graph/{floor}/node/{node_id}/unassign-location`
   - Added `GET /navigation/locations/{floor}`
   - Added `GET /navigation/locations/all`
   - Updated `POST /getlocation` to include navigability info

---

## Next Steps (Part 2)

Part 2 will implement the frontend UI for:
1. Path editor: Assign dataset locations to nodes
2. Map screen: Use navigable locations for search
3. Visual indicators for mapped vs unmapped nodes
4. Error handling for unmapped locations

---

## Status

✅ **Backend Complete**
- Schema updated
- All methods implemented
- All endpoints added
- Error handling complete
- Logging added
- No diagnostics errors

**Ready for Part 2: Frontend Implementation**

---

**Lines Added**: 400+
**Methods Added**: 5
**Endpoints Added**: 5
**Endpoints Updated**: 2
