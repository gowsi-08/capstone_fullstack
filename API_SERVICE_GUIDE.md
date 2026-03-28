# API Service & Data Models Guide

## Overview

This guide covers the complete API service and data models for the indoor navigation system, including graph management, pathfinding, and location management.

---

## API Service (`frontend/lib/api_service.dart`)

### Base URL Configuration

The API service automatically selects the appropriate base URL:

```dart
// Production (Render)
const bool useProduction = true;  // Set to false for local development

// Local development URLs
- Web: http://localhost:5000
- Android Emulator: http://10.0.2.2:5000
- iOS/Desktop: http://127.0.0.1:5000
```

---

## Graph Management APIs

### 1. Get Walkable Graph

Fetch the walkable graph for a specific floor.

```dart
Future<Map<String, dynamic>?> getWalkableGraph(int floor)
```

**Parameters**:
- `floor` (int): Floor number (1, 2, 3)

**Returns**:
```json
{
  "exists": true,
  "nodes": [
    {"id": "uuid", "x": 0.5, "y": 0.5, "label": ""}
  ],
  "edges": [
    {"id": "uuid", "from_node": "uuid", "to_node": "uuid", "weight": 0.1}
  ]
}
```

**Example**:
```dart
final graph = await ApiService.getWalkableGraph(1);
if (graph != null && graph['exists'] == true) {
  final nodes = graph['nodes'] as List<dynamic>;
  final edges = graph['edges'] as List<dynamic>;
  print('Loaded ${nodes.length} nodes and ${edges.length} edges');
}
```

### 2. Save Walkable Graph

Save or update the walkable graph for a floor.

```dart
Future<bool> saveWalkableGraph(int floor, List<Map<String, dynamic>> nodes, List<Map<String, dynamic>> edges)
```

**Parameters**:
- `floor` (int): Floor number
- `nodes` (List): List of node objects
- `edges` (List): List of edge objects

**Returns**: `bool` - Success status

**Example**:
```dart
final nodes = [
  {'id': 'node1', 'x': 0.3, 'y': 0.4, 'label': ''},
  {'id': 'node2', 'x': 0.6, 'y': 0.7, 'label': ''},
];

final edges = [
  {'id': 'edge1', 'from_node': 'node1', 'to_node': 'node2'},
];

final success = await ApiService.saveWalkableGraph(1, nodes, edges);
if (success) {
  print('Graph saved successfully!');
}
```

### 3. Clear Walkable Graph

Delete the walkable graph for a floor.

```dart
Future<bool> clearWalkableGraph(int floor)
```

**Parameters**:
- `floor` (int): Floor number

**Returns**: `bool` - Success status

**Example**:
```dart
final success = await ApiService.clearWalkableGraph(1);
if (success) {
  print('Graph cleared successfully!');
}
```

---

## Pathfinding APIs

### Calculate Navigation Path

Calculate the shortest path between two locations using Dijkstra's algorithm.

```dart
Future<Map<String, dynamic>?> getNavigationPath({
  required int floor,
  required String fromLocation,
  required String toLocation,
})
```

**Parameters**:
- `floor` (int): Floor number
- `fromLocation` (String): Starting location name
- `toLocation` (String): Destination location name

**Returns**:
```json
{
  "found": true,
  "path_nodes": [
    {"x": 0.34, "y": 0.56},
    {"x": 0.45, "y": 0.60},
    {"x": 0.52, "y": 0.72}
  ],
  "total_distance": 0.156,
  "estimated_seconds": 12
}
```

**Example**:
```dart
final path = await ApiService.getNavigationPath(
  floor: 1,
  fromLocation: 'Room 101',
  toLocation: 'Room 202',
);

if (path != null && path['found'] == true) {
  final pathNodes = path['path_nodes'] as List<dynamic>;
  final seconds = path['estimated_seconds'] as int;
  final minutes = (seconds / 60).ceil();
  print('Path found with ${pathNodes.length} waypoints');
  print('Estimated time: $minutes minutes');
} else {
  print('No path found between locations');
}
```

---

## Location Management APIs

### 1. Get Locations

Fetch all locations for a specific floor.

```dart
Future<List<Map<String, dynamic>>> getLocations(int floor)
```

**Parameters**:
- `floor` (int): Floor number

**Returns**: List of location objects

**Example**:
```dart
final locations = await ApiService.getLocations(1);
for (var loc in locations) {
  print('${loc['name']} at (${loc['x']}, ${loc['y']})');
}
```

### 2. Create Location

Create a new location on a floor.

```dart
Future<bool> createLocation(int floor, Map<String, dynamic> data)
```

**Parameters**:
- `floor` (int): Floor number
- `data` (Map): Location data

**Data Structure**:
```dart
{
  'name': 'Room 101',
  'landmark': 'Near main entrance',  // optional
  'x': 0.34,
  'y': 0.56,
  'node_id': 'uuid',  // optional
}
```

**Example**:
```dart
final success = await ApiService.createLocation(1, {
  'name': 'Room 101',
  'landmark': 'Computer Lab',
  'x': 0.34,
  'y': 0.56,
  'node_id': 'node-uuid-123',
});

if (success) {
  print('Location created successfully!');
}
```

### 3. Update Location

Update an existing location.

```dart
Future<bool> updateLocation(String id, Map<String, dynamic> data)
```

**Parameters**:
- `id` (String): Location ID
- `data` (Map): Updated location data

**Example**:
```dart
final success = await ApiService.updateLocation('loc-123', {
  'name': 'Room 101A',
  'x': 0.35,
  'y': 0.57,
});

if (success) {
  print('Location updated successfully!');
}
```

### 4. Delete Location

Delete a location.

```dart
Future<bool> deleteLocation(String id)
```

**Parameters**:
- `id` (String): Location ID

**Example**:
```dart
final success = await ApiService.deleteLocation('loc-123');
if (success) {
  print('Location deleted successfully!');
}
```

### 5. Link Location to Node

Link a location to a graph node for pathfinding.

```dart
Future<bool> linkLocationToNode(String locationId, String nodeId)
```

**Parameters**:
- `locationId` (String): Location ID
- `nodeId` (String): Graph node ID

**Example**:
```dart
final success = await ApiService.linkLocationToNode('loc-123', 'node-456');
if (success) {
  print('Location linked to node successfully!');
}
```

---

## Data Models (`frontend/lib/models/graph_models.dart`)

### 1. GraphNode

Represents a node in the walkable graph.

**Properties**:
```dart
class GraphNode {
  final String id;
  final double x;      // normalized 0.0 to 1.0
  final double y;      // normalized 0.0 to 1.0
  final String? label;
}
```

**Methods**:
```dart
// Create from JSON
GraphNode.fromJson(Map<String, dynamic> json)

// Convert to JSON
Map<String, dynamic> toJson()

// Copy with updated fields
GraphNode copyWith({String? id, double? x, double? y, String? label})

// Convert to pixel coordinates
Offset toPixelOffset(Size imageSize)

// Create from pixel coordinates
GraphNode.fromPixelOffset({
  required String id,
  required Offset position,
  required Size imageSize,
  String? label,
})
```

**Example**:
```dart
// Create node
final node = GraphNode(
  id: 'node-1',
  x: 0.5,
  y: 0.5,
  label: 'Hallway',
);

// Convert to pixel coordinates
final imageSize = Size(1000, 800);
final pixelPos = node.toPixelOffset(imageSize);
print('Pixel position: ${pixelPos.dx}, ${pixelPos.dy}');

// Create from pixel position
final node2 = GraphNode.fromPixelOffset(
  id: 'node-2',
  position: Offset(500, 400),
  imageSize: imageSize,
);
print('Normalized: ${node2.x}, ${node2.y}');
```

### 2. GraphEdge

Represents an edge connecting two nodes.

**Properties**:
```dart
class GraphEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final double? weight;  // optional, calculated on backend
}
```

**Methods**:
```dart
// Create from JSON
GraphEdge.fromJson(Map<String, dynamic> json)

// Convert to JSON
Map<String, dynamic> toJson()

// Copy with updated fields
GraphEdge copyWith({String? id, String? fromNodeId, String? toNodeId, double? weight})

// Check if edge connects to a node
bool connectsTo(String nodeId)

// Get the other node ID
String? getOtherNode(String nodeId)
```

**Example**:
```dart
final edge = GraphEdge(
  id: 'edge-1',
  fromNodeId: 'node-1',
  toNodeId: 'node-2',
  weight: 0.15,
);

// Check connection
if (edge.connectsTo('node-1')) {
  print('Edge connects to node-1');
}

// Get other end
final otherId = edge.getOtherNode('node-1');
print('Other node: $otherId');  // 'node-2'
```

### 3. WalkableGraph

Represents a complete walkable graph for a floor.

**Properties**:
```dart
class WalkableGraph {
  final int floor;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final DateTime? updatedAt;
}
```

**Methods**:
```dart
// Create from JSON
WalkableGraph.fromJson(Map<String, dynamic> json)

// Convert to JSON
Map<String, dynamic> toJson()

// Check if empty
bool get isEmpty
bool get isNotEmpty

// Get node by ID
GraphNode? getNode(String nodeId)

// Get edges for a node
List<GraphEdge> getEdgesForNode(String nodeId)

// Get neighboring nodes
List<GraphNode> getNeighbors(String nodeId)
```

**Example**:
```dart
final graph = WalkableGraph(
  floor: 1,
  nodes: [node1, node2, node3],
  edges: [edge1, edge2],
);

// Get node
final node = graph.getNode('node-1');

// Get neighbors
final neighbors = graph.getNeighbors('node-1');
print('Node has ${neighbors.length} neighbors');

// Get connected edges
final connectedEdges = graph.getEdgesForNode('node-1');
print('Node has ${connectedEdges.length} edges');
```

### 4. NavigationPath

Represents a calculated navigation path.

**Properties**:
```dart
class NavigationPath {
  final List<Offset> points;        // normalized coordinates
  final double totalDistance;
  final int estimatedSeconds;
  final bool found;
  final String? message;
}
```

**Methods**:
```dart
// Create from API response
NavigationPath.fromJson(Map<String, dynamic> json)

// Convert to pixel coordinates
List<Offset> toPixelCoordinates(Size imageSize)

// Get estimated time in minutes
int get estimatedMinutes

// Check if empty
bool get isEmpty
bool get isNotEmpty

// Get waypoint count
int get waypointCount
```

**Example**:
```dart
// From API response
final pathData = await ApiService.getNavigationPath(
  floor: 1,
  fromLocation: 'A',
  toLocation: 'B',
);

final path = NavigationPath.fromJson(pathData!);

if (path.found) {
  print('Path found with ${path.waypointCount} waypoints');
  print('Distance: ${path.totalDistance.toStringAsFixed(2)}');
  print('Time: ${path.estimatedMinutes} minutes');
  
  // Convert to pixel coordinates for drawing
  final imageSize = Size(1000, 800);
  final pixelPath = path.toPixelCoordinates(imageSize);
  
  // Draw path on canvas
  for (var point in pixelPath) {
    // Draw point at (point.dx, point.dy)
  }
}
```

### 5. LocationMarker

Represents a location marker on the map.

**Properties**:
```dart
class LocationMarker {
  final String id;
  final String name;
  final String? landmark;
  final int floor;
  final double x;        // normalized 0.0 to 1.0
  final double y;        // normalized 0.0 to 1.0
  final String? nodeId;  // linked graph node
}
```

**Methods**:
```dart
// Create from JSON
LocationMarker.fromJson(Map<String, dynamic> json)

// Convert to JSON
Map<String, dynamic> toJson()

// Copy with updated fields
LocationMarker copyWith({...})

// Convert to pixel coordinates
Offset toPixelOffset(Size imageSize)

// Create from pixel coordinates
LocationMarker.fromPixelOffset({...})

// Check if linked to node
bool get isLinked

// Get display text
String get displayText
```

**Example**:
```dart
final location = LocationMarker(
  id: 'loc-1',
  name: 'Room 101',
  landmark: 'Computer Lab',
  floor: 1,
  x: 0.34,
  y: 0.56,
  nodeId: 'node-123',
);

// Check if linked
if (location.isLinked) {
  print('Location is linked to node ${location.nodeId}');
}

// Get display text
print(location.displayText);  // "Room 101 (Computer Lab)"

// Convert to pixel position
final imageSize = Size(1000, 800);
final pixelPos = location.toPixelOffset(imageSize);
print('Draw marker at: ${pixelPos.dx}, ${pixelPos.dy}');
```

### 6. CoordinateConverter

Helper class for coordinate conversion.

**Methods**:
```dart
// Convert normalized to pixel
static Offset normalizedToPixel(double x, double y, Size imageSize)

// Convert pixel to normalized
static Offset pixelToNormalized(Offset position, Size imageSize)

// Convert list of normalized to pixel
static List<Offset> normalizedListToPixel(List<Offset> points, Size imageSize)

// Convert list of pixel to normalized
static List<Offset> pixelListToNormalized(List<Offset> points, Size imageSize)

// Clamp coordinates to valid range (0-1)
static Offset clampNormalized(Offset position)
```

**Example**:
```dart
final imageSize = Size(1000, 800);

// Normalized to pixel
final pixel = CoordinateConverter.normalizedToPixel(0.5, 0.5, imageSize);
print('Pixel: ${pixel.dx}, ${pixel.dy}');  // 500, 400

// Pixel to normalized
final normalized = CoordinateConverter.pixelToNormalized(
  Offset(500, 400),
  imageSize,
);
print('Normalized: ${normalized.dx}, ${normalized.dy}');  // 0.5, 0.5

// Clamp coordinates
final clamped = CoordinateConverter.clampNormalized(Offset(1.5, -0.2));
print('Clamped: ${clamped.dx}, ${clamped.dy}');  // 1.0, 0.0
```

---

## Complete Usage Example

### Building a Path Editor

```dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models/graph_models.dart';

class PathEditorExample extends StatefulWidget {
  final int floor;
  final Size imageSize;

  const PathEditorExample({
    required this.floor,
    required this.imageSize,
  });

  @override
  State<PathEditorExample> createState() => _PathEditorExampleState();
}

class _PathEditorExampleState extends State<PathEditorExample> {
  List<GraphNode> nodes = [];
  List<GraphEdge> edges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    setState(() => isLoading = true);
    
    final graphData = await ApiService.getWalkableGraph(widget.floor);
    
    if (graphData != null && graphData['exists'] == true) {
      setState(() {
        nodes = (graphData['nodes'] as List)
            .map((n) => GraphNode.fromJson(n))
            .toList();
        edges = (graphData['edges'] as List)
            .map((e) => GraphEdge.fromJson(e))
            .toList();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveGraph() async {
    final nodesJson = nodes.map((n) => n.toJson()).toList();
    final edgesJson = edges.map((e) => e.toJson()).toList();
    
    final success = await ApiService.saveWalkableGraph(
      widget.floor,
      nodesJson,
      edgesJson,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Graph saved successfully!')),
      );
    }
  }

  void _addNode(Offset tapPosition) {
    final node = GraphNode.fromPixelOffset(
      id: 'node-${DateTime.now().millisecondsSinceEpoch}',
      position: tapPosition,
      imageSize: widget.imageSize,
    );
    
    setState(() => nodes.add(node));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Map image
        GestureDetector(
          onTapDown: (details) => _addNode(details.localPosition),
          child: CustomPaint(
            painter: GraphPainter(
              nodes: nodes,
              edges: edges,
              imageSize: widget.imageSize,
            ),
          ),
        ),
        
        // Save button
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _saveGraph,
            child: Icon(Icons.save),
          ),
        ),
      ],
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Size imageSize;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.fromNodeId);
      final toNode = nodes.firstWhere((n) => n.id == edge.toNodeId);
      
      final from = fromNode.toPixelOffset(imageSize);
      final to = toNode.toPixelOffset(imageSize);
      
      canvas.drawLine(from, to, edgePaint);
    }

    // Draw nodes
    final nodePaint = Paint()
      ..color = Colors.teal
      ..style = PaintingStyle.fill;

    for (var node in nodes) {
      final pos = node.toPixelOffset(imageSize);
      canvas.drawCircle(pos, 10, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

### Building a Navigation Screen

```dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models/graph_models.dart';

class NavigationExample extends StatefulWidget {
  final int floor;
  final Size imageSize;

  const NavigationExample({
    required this.floor,
    required this.imageSize,
  });

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample>
    with SingleTickerProviderStateMixin {
  NavigationPath? currentPath;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _calculatePath(String from, String to) async {
    final pathData = await ApiService.getNavigationPath(
      floor: widget.floor,
      fromLocation: from,
      toLocation: to,
    );

    if (pathData != null) {
      final path = NavigationPath.fromJson(pathData);
      
      if (path.found) {
        setState(() => currentPath = path);
        _animationController.forward(from: 0);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Route found! Estimated time: ${path.estimatedMinutes} min',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No path found between locations'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map with animated path
        CustomPaint(
          painter: AnimatedPathPainter(
            path: currentPath,
            imageSize: widget.imageSize,
            animation: _animationController,
          ),
        ),
        
        // Navigation controls
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton(
            onPressed: () => _calculatePath('Room 101', 'Room 202'),
            child: Text('Get Directions'),
          ),
        ),
      ],
    );
  }
}

class AnimatedPathPainter extends CustomPainter {
  final NavigationPath? path;
  final Size imageSize;
  final Animation<double> animation;

  AnimatedPathPainter({
    required this.path,
    required this.imageSize,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (path == null || !path!.found) return;

    final pixelPath = path!.toPixelCoordinates(imageSize);
    if (pixelPath.length < 2) return;

    // Create path
    final pathObj = Path();
    pathObj.moveTo(pixelPath[0].dx, pixelPath[0].dy);
    for (int i = 1; i < pixelPath.length; i++) {
      pathObj.lineTo(pixelPath[i].dx, pixelPath[i].dy);
    }

    // Animate path drawing
    final pathMetrics = pathObj.computeMetrics().first;
    final totalLength = pathMetrics.length;
    final currentLength = totalLength * animation.value;
    final extractedPath = pathMetrics.extractPath(0, currentLength);

    // Draw path
    final pathPaint = Paint()
      ..color = Color(0xFF00BCD4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extractedPath, pathPaint);

    // Draw waypoints
    for (int i = 1; i < pixelPath.length - 1; i++) {
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(pixelPath[i], 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

---

## Error Handling

All API methods include comprehensive error handling:

```dart
try {
  final result = await ApiService.getWalkableGraph(1);
  if (result != null) {
    // Success
  } else {
    // API returned null (error occurred)
  }
} catch (e) {
  // Network error or exception
  print('Error: $e');
}
```

**Common Error Scenarios**:
- Network timeout (10-15 seconds)
- Server error (500)
- Not found (404)
- Invalid data format
- Connection refused

---

## Best Practices

### 1. Always Check for Null

```dart
final graph = await ApiService.getWalkableGraph(1);
if (graph != null && graph['exists'] == true) {
  // Process graph
}
```

### 2. Use Models for Type Safety

```dart
// Good
final node = GraphNode.fromJson(nodeData);
final x = node.x;  // Type-safe

// Avoid
final x = nodeData['x'];  // Dynamic type
```

### 3. Handle Loading States

```dart
setState(() => isLoading = true);
final data = await ApiService.getWalkableGraph(1);
setState(() => isLoading = false);
```

### 4. Show User Feedback

```dart
final success = await ApiService.saveWalkableGraph(1, nodes, edges);
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(success ? 'Saved!' : 'Failed to save'),
    backgroundColor: success ? Colors.green : Colors.red,
  ),
);
```

### 5. Dispose Controllers

```dart
@override
void dispose() {
  _animationController.dispose();
  _transformController.dispose();
  super.dispose();
}
```

---

## Conclusion

The API service and data models provide a complete, type-safe interface for:
- Graph management (create, read, update, delete)
- Pathfinding with Dijkstra's algorithm
- Location management with node linking
- Coordinate conversion (normalized ↔ pixel)
- Animated path rendering

All methods include error handling, logging, and comprehensive documentation.

---

**Status**: ✅ Complete and production-ready
**Files**: 
- `frontend/lib/api_service.dart` (500+ lines)
- `frontend/lib/models/graph_models.dart` (600+ lines)
