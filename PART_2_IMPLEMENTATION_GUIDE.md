# Part 2 Implementation Guide - Path Editor Node Assignment

## Changes Required in floor_plan_screen.dart

### 1. Update _loadGraph() method

**Current**:
```dart
_nodes.add(GraphNode(id: nodeData['id'], x: nodeData['x'].toDouble(), y: nodeData['y'].toDouble(), label: nodeData['label'] ?? ''));
```

**Change to**:
```dart
_nodes.add(GraphNode(
  id: nodeData['id'],
  x: nodeData['x'].toDouble(),
  y: nodeData['y'].toDouble(),
  label: nodeData['label'] ?? '',
  datasetLocation: nodeData['dataset_location'],
));
```

### 2. Update _saveGraph() method

**Current**:
```dart
'nodes': _nodes.map((n) => {'id': n.id, 'x': n.x, 'y': n.y, 'label': n.label}).toList(),
```

**Change to**:
```dart
'nodes': _nodes.map((n) => n.toJson()).toList(),
```

### 3. Add new state variables

Add after existing state variables:
```dart
List<Map<String, dynamic>> _datasetLocations = [];
int _mappedNodesCount = 0;
```

### 4. Add new method to load dataset locations

```dart
Future<void> _loadDatasetLocations() async {
  try {
    final locations = await ApiService.getDatasetLocations(widget.floor);
    if (mounted) {
      setState(() {
        _datasetLocations = locations;
        _updateMappedCount();
      });
    }
  } catch (e) {
    print('Error loading dataset locations: $e');
  }
}

void _updateMappedCount() {
  _mappedNodesCount = _nodes.where((n) => n.isMapped).length;
}
```

### 5. Update _loadData() to include dataset locations

**Change**:
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  await Future.wait([_loadGraph(), _loadLocations(), _loadDatasetLocations()]);
  setState(() => _isLoading = false);
}
```

### 6. Update _addNode() to update mapped count

**Add at end**:
```dart
_updateMappedCount();
```

### 7. Add new mode 'select' to _activeMode

**Change**:
```dart
String _activeMode = 'none'; // 'add_node' | 'add_edge' | 'delete' | 'select' | 'none'
```

### 8. Update _handleMapTap() to handle select mode

**Add before existing conditions**:
```dart
if (_activeMode == 'select') {
  final ta