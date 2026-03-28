# Advanced Path Editor - Complete Guide

## Overview

The enhanced path editor provides a professional graph editing experience with multiple interaction modes, visual feedback, and safety features.

---

## Two-Mode System

### Mode 1: View Map 🗺️

**Purpose:** View the complete navigation system without editing

**Features:**
- Full InteractiveViewer (zoom, pan)
- All existing locations shown as purple pins with labels
- All walkable path edges drawn as thin blue lines (40% opacity)
- All graph nodes shown as small hollow circles
- Read-only visualization

**Actions:**
- "Replace Map" button - Upload new floor plan
- "Go to Location Marking" button - Edit room locations

**Visual Elements:**
- Edges: `Color(0xFF2979FF)` with 40% opacity, 2px stroke
- Nodes: `Color(0xFF2979FF)` hollow circles, 6px radius
- Locations: `Color(0xFF7C4DFF)` pins with name labels

---

### Mode 2: Edit Paths ✏️

**Purpose:** Create and edit the walkable navigation graph

**Features:**
- Visual graph editor directly on map
- Four interaction modes (toolbar)
- Real-time visual feedback
- Unsaved changes warning
- Undo support for deletions

---

## Toolbar Modes

### 1. Add Node Mode

**Button:** `[ Add Node ]` with location icon

**Behavior:**
- Tap anywhere on map → place new node
- Node gets UUID automatically
- Appears immediately on canvas
- No confirmation needed
- Coordinates normalized (0-1)

**Visual Feedback:**
- New nodes appear as teal circles
- 10px radius, white border

**Use Case:**
- Place nodes at corridor intersections
- Add nodes at doorways
- Create nodes near room entrances
- Build the walkable network

---

### 2. Add Edge Mode

**Button:** `[ Add Edge ]` with timeline icon

**Behavior:**
1. **First tap:** Select "from" node (turns green)
2. **Second tap:** Select "to" node → edge created
3. **Same node twice:** Deselect
4. **Duplicate edge:** Show warning, deselect

**Visual Feedback:**
- First selected node: `Color(0xFF00C853)` (green)
- Edge created: Blue line appears
- Duplicate attempt: Orange snackbar

**Auto-Calculations:**
- Weight = Euclidean distance between nodes
- Calculated on save

**Duplicate Prevention:**
- Checks both directions (A→B and B→A)
- Shows "Edge already exists" message

---

### 3. Delete Mode

**Button:** `[ Delete ]` with delete icon

**Behavior:**

**Delete Node:**
- Tap node → Confirmation snackbar
- "Delete node and all its edges?"
- Undo action available
- Removes node + connected edges

**Delete Edge:**
- Tap edge → Immediate deletion
- Undo snackbar shown
- Edge removed from graph

**Detection Logic:**
- Nodes take priority if within 20px
- Edges detected using point-to-line distance ≤ 10px
- Smart hit detection

**Visual Feedback:**
- Orange snackbar for confirmations
- Undo button available

---

### 4. Clear All

**Button:** `[ Clear All ]` (red)

**Behavior:**
- Shows confirmation dialog
- "This will delete all nodes and edges"
- "This action cannot be undone"
- Clears entire graph on confirm

**Safety:**
- Requires explicit confirmation
- Cannot be undone
- Marks as unsaved changes

---

### 5. Save Graph

**Button:** `[ Save ]` (blue, accent)

**Behavior:**
- Collects all nodes and edges
- POST to `/admin/graph/{floor}`
- Replaces full graph
- Auto-calculates edge weights
- Shows success message

**Success Message:**
- "✅ Path graph saved — X nodes, Y edges"
- Green snackbar
- Clears unsaved changes flag

**Error Handling:**
- Shows error message
- Keeps local state
- Allows retry

---

## Visual Design

### Node Colors

**Default Node:**
- Color: `Color(0xFF00BCD4)` (teal)
- Size: 10px radius
- Border: White, 2px

**Selected Node (Add Edge):**
- Color: `Color(0xFF00C853)` (green)
- Indicates "from" node
- Size: 10px radius

**Selected Node (Other):**
- Color: `Color(0xFFFF6D00)` (orange)
- Indicates active selection
- Size: 10px radius

### Edge Colors

**Normal Edge:**
- Color: `Color(0xFF2979FF)` (blue)
- Opacity: 60%
- Stroke: 3px

**Selected Edge (Delete Mode):**
- Color: `Color(0xFFFF6D00)` (orange)
- Opacity: 100%
- Stroke: 3px

### Location Pins (Read-Only)

**Pin Style:**
- Color: `Color(0xFF7C4DFF)` (purple)
- Opacity: 50% in edit mode
- Size: 6px radius
- Label: White text, 9px

**Purpose:**
- Show where rooms are located
- Help align nodes with locations
- Read-only overlay

---

## State Management

### Local State Variables

```dart
List<GraphNode> _nodes = [];
List<GraphEdge> _edges = [];
String _activeMode = 'none'; // 'add_node' | 'add_edge' | 'delete' | 'none'
String? _selectedNodeId; // For edge creation
bool _hasUnsavedChanges = false;
```

### State Lifecycle

**On Screen Load:**
1. Fetch existing graph: `GET /admin/graph/{floor}`
2. Populate `_nodes` and `_edges`
3. Load locations for overlay
4. Calculate image size

**On User Action:**
1. Update local state
2. Set `_hasUnsavedChanges = true`
3. Trigger repaint

**On Save:**
1. POST all nodes and edges
2. Backend calculates weights
3. Set `_hasUnsavedChanges = false`
4. Show success message

**On Navigation Away:**
1. Check `_hasUnsavedChanges`
2. Show warning dialog if true
3. Allow cancel or proceed

---

## Interaction Logic

### Add Node Flow

```
User taps map
  ↓
Get tap position (localPosition)
  ↓
Normalize coordinates (x/imageWidth, y/imageHeight)
  ↓
Create GraphNode with UUID
  ↓
Add to _nodes list
  ↓
Set _hasUnsavedChanges = true
  ↓
Repaint canvas
```

### Add Edge Flow

```
User taps node (first time)
  ↓
Find node at position
  ↓
Set _selectedNodeId = node.id
  ↓
Node turns green
  ↓
User taps another node
  ↓
Check if edge already exists
  ↓
If not exists:
  Create GraphEdge with UUID
  Add to _edges list
  Clear _selectedNodeId
  Set _hasUnsavedChanges = true
  Repaint canvas
```

### Delete Flow

```
User taps in delete mode
  ↓
Check for node at position (priority)
  ↓
If node found:
  Show confirmation snackbar
  User taps DELETE
  Remove node from _nodes
  Remove all edges connected to node
  Set _hasUnsavedChanges = true
  Repaint canvas
  ↓
If no node, check for edge
  ↓
If edge found:
  Remove edge from _edges
  Show undo snackbar
  Set _hasUnsavedChanges = true
  Repaint canvas
```

---

## Safety Features

### 1. Unsaved Changes Warning

**Trigger:** User tries to navigate away with unsaved changes

**Dialog:**
- Title: "Unsaved Changes"
- Message: "You have unsaved changes. Do you want to leave without saving?"
- Actions: Cancel | Leave

**Implementation:**
```dart
WillPopScope(
  onWillPop: () async {
    if (_hasUnsavedChanges) {
      return await showDialog(...) ?? false;
    }
    return true;
  },
  child: ...
)
```

### 2. Clear All Confirmation

**Trigger:** User taps "Clear All" button

**Dialog:**
- Title: "Clear All?"
- Message: "This will delete all nodes and edges. This action cannot be undone."
- Actions: Cancel | Clear All

### 3. Delete Node Confirmation

**Trigger:** User taps node in delete mode

**Snackbar:**
- Message: "Delete node and all its edges?"
- Action: DELETE button
- Prevents accidental deletions

### 4. Duplicate Edge Prevention

**Trigger:** User tries to create existing edge

**Snackbar:**
- Message: "Edge already exists"
- Color: Orange warning
- Auto-deselects nodes

---

## Hit Detection

### Node Detection

**Algorithm:**
```dart
for (var node in _nodes) {
  final nodePos = Offset(node.x * imageWidth, node.y * imageHeight);
  final distance = (tapPosition - nodePos).distance;
  if (distance <= 20) return node.id;
}
```

**Threshold:** 20 pixels
**Priority:** Nodes checked first

### Edge Detection

**Algorithm:**
```dart
for (var edge in _edges) {
  final from = getNodePosition(edge.fromNodeId);
  final to = getNodePosition(edge.toNodeId);
  final distance = pointToLineDistance(tapPosition, from, to);
  if (distance <= 10) return edge.id;
}
```

**Threshold:** 10 pixels
**Method:** Point-to-line distance calculation

**Point-to-Line Distance:**
```dart
double pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
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

---

## Bottom Stats Bar

**Display:**
- Node count with tree icon
- Edge count with timeline icon
- Unsaved changes indicator (orange dot)

**Example:**
```
🌳 12 nodes  📈 18 edges  🟠 Unsaved
```

**Colors:**
- Nodes: `Color(0xFF2979FF)` (blue)
- Edges: `Color(0xFF00BCD4)` (teal)
- Unsaved: `Color(0xFFFF6D00)` (orange)

---

## Keyboard Shortcuts (Future)

**Planned:**
- `N` - Add Node mode
- `E` - Add Edge mode
- `D` - Delete mode
- `Esc` - Deselect / None mode
- `Ctrl+S` - Save
- `Ctrl+Z` - Undo
- `Ctrl+Shift+Z` - Redo

---

## Best Practices

### For Admins

**Node Placement:**
1. Start at building entrances
2. Place nodes at corridor intersections
3. Add nodes at doorways
4. Create nodes near room locations
5. Ensure full connectivity

**Edge Creation:**
1. Connect adjacent nodes
2. Follow actual walkable paths
3. Don't create diagonal shortcuts through walls
4. Ensure bidirectional access

**Graph Quality:**
- More nodes = more accurate paths
- Aim for 5-10 meter spacing
- Test paths between distant locations
- Verify no isolated sections

### For Developers

**Performance:**
- Limit to 200 nodes per floor
- Use normalized coordinates
- Batch updates when possible
- Debounce save operations

**Data Integrity:**
- Validate node positions (0-1 range)
- Check for orphaned edges
- Prevent duplicate edges
- Maintain UUID uniqueness

---

## Troubleshooting

### Issue: Nodes not appearing

**Solutions:**
- Check image size is calculated
- Verify coordinates are normalized
- Ensure CustomPainter is rendering
- Check _nodes list is populated

### Issue: Edges not connecting

**Solutions:**
- Verify both nodes exist
- Check node IDs match
- Ensure edge mode is active
- Look for duplicate edge warning

### Issue: Can't delete nodes

**Solutions:**
- Ensure delete mode is active
- Tap directly on node (within 20px)
- Check confirmation snackbar appears
- Verify DELETE button is tapped

### Issue: Unsaved changes not detected

**Solutions:**
- Check _hasUnsavedChanges flag
- Verify state updates trigger flag
- Ensure WillPopScope is working
- Test navigation away

---

## API Integration

### Load Graph

```dart
GET /admin/graph/{floor}

Response:
{
  "floor": 1,
  "nodes": [{"id": "uuid", "x": 0.5, "y": 0.5, "label": ""}],
  "edges": [{"id": "uuid", "from_node": "uuid", "to_node": "uuid"}],
  "exists": true
}
```

### Save Graph

```dart
POST /admin/graph/{floor}
Content-Type: application/json

Body:
{
  "nodes": [{"id": "uuid", "x": 0.5, "y": 0.5, "label": ""}],
  "edges": [{"id": "uuid", "from_node": "uuid", "to_node": "uuid"}]
}

Response:
{
  "success": true,
  "message": "Graph saved with 12 nodes and 18 edges"
}
```

### Load Locations

```dart
GET /admin/locations/{floor}

Response:
[
  {"id": "id", "name": "Room 101", "x": 100.0, "y": 200.0, "node_id": "uuid"},
  ...
]
```

---

## Testing Checklist

### View Map Mode
- [ ] Map displays correctly
- [ ] Locations shown as purple pins
- [ ] Edges shown as thin blue lines
- [ ] Nodes shown as hollow circles
- [ ] Zoom and pan work smoothly
- [ ] Replace Map button works
- [ ] Go to Locations button works

### Add Node Mode
- [ ] Mode activates on button tap
- [ ] Nodes appear on map tap
- [ ] Coordinates normalized correctly
- [ ] Multiple nodes can be added
- [ ] Nodes visible immediately
- [ ] Mode deactivates on button tap

### Add Edge Mode
- [ ] First tap selects node (green)
- [ ] Second tap creates edge
- [ ] Edge appears immediately
- [ ] Same node tap deselects
- [ ] Duplicate edge prevented
- [ ] Warning shown for duplicates

### Delete Mode
- [ ] Node tap shows confirmation
- [ ] DELETE button removes node
- [ ] Connected edges removed
- [ ] Edge tap deletes immediately
- [ ] Undo snackbar appears
- [ ] Hit detection accurate

### Save/Load
- [ ] Graph saves to backend
- [ ] Success message shown
- [ ] Graph loads on screen open
- [ ] Unsaved changes detected
- [ ] Warning shown on navigation
- [ ] Clear All works with confirmation

---

## Success! 🎉

The advanced path editor is now complete with professional interaction modes, visual feedback, and safety features. Admins can create sophisticated navigation graphs with ease!
