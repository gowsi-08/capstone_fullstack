import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../api_service.dart';

// Main Floor Plan Screen - Gallery View
class FloorPlanScreen extends StatefulWidget {
  const FloorPlanScreen({Key? key}) : super(key: key);

  @override
  State<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  final List<int> _floors = [1, 2, 3];
  final Map<int, Uint8List?> _floorMaps = {};
  final Map<int, bool> _loadingStates = {};
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFloorMaps();
  }

  Future<void> _loadAllFloorMaps() async {
    setState(() => _isInitialLoading = true);
    for (final floor in _floors) {
      setState(() => _loadingStates[floor] = true);
      final b64 = await ApiService.getMapBase64(floor.toString());
      if (mounted) {
        setState(() {
          _floorMaps[floor] = b64 != null ? base64Decode(b64) : null;
          _loadingStates[floor] = false;
        });
      }
    }
    if (mounted) setState(() => _isInitialLoading = false);
  }


  Future<void> _loadSingleFloorMap(int floor) async {
    setState(() => _loadingStates[floor] = true);
    final b64 = await ApiService.getMapBase64(floor.toString());
    if (mounted) {
      setState(() {
        _floorMaps[floor] = b64 != null ? base64Decode(b64) : null;
        _loadingStates[floor] = false;
      });
    }
  }

  Future<void> _uploadMapForFloor(int floor) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2500, maxHeight: 2500, imageQuality: 85);
    if (picked == null) return;

    setState(() => _loadingStates[floor] = true);
    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)..files.add(await http.MultipartFile.fromPath('file', picked.path));

    try {
      final resp = await req.send();
      final respBody = await resp.stream.bytesToString();
      final respJson = jsonDecode(respBody);
      if (!mounted) return;
      if (resp.statusCode == 200 && respJson['success'] == true) {
        await _loadSingleFloorMap(floor);
        _showSnackBar('✅ Floor $floor map uploaded successfully!', const Color(0xFF00C853));
      } else {
        setState(() => _loadingStates[floor] = false);
        _showSnackBar('❌ Upload failed: ${respJson['error'] ?? 'Unknown'}', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStates[floor] = false);
      _showSnackBar('❌ Upload failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.inter(color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  void _openFloorDetail(int floor, Uint8List? imageBytes) {
    if (imageBytes == null) {
      _uploadMapForFloor(floor);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => FloorDetailScreen(floor: floor, imageBytes: imageBytes, onMapUpdated: () => _loadSingleFloorMap(floor))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF132F4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Floor Plans & Navigation', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Tap to edit paths and locations', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadAllFloorMaps)],
      ),
      body: _isInitialLoading ? _buildLoadingSkeleton() : GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
        itemCount: _floors.length,
        itemBuilder: (context, index) => _buildFloorCard(_floors[index]),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(color: const Color(0xFF132F4C), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF), strokeWidth: 2)),
      ),
    );
  }

  Widget _buildFloorCard(int floor) {
    final imageBytes = _floorMaps[floor];
    final isLoading = _loadingStates[floor] ?? false;

    return GestureDetector(
      onTap: () => _openFloorDetail(floor, imageBytes),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF132F4C), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Stack(
          children: [
            if (isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF), strokeWidth: 2))
            else if (imageBytes != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
            else Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.2), width: 2), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.upload_file, size: 40, color: Colors.white.withOpacity(0.3))),
              const SizedBox(height: 12),
              Text('No map uploaded', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ])),
            Positioned(bottom: 12, left: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF132F4C).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: _getFloorColor(floor))),
              child: Text('Floor $floor', style: GoogleFonts.inter(color: _getFloorColor(floor), fontSize: 12, fontWeight: FontWeight.w600)),
            )),
          ],
        ),
      ),
    );
  }

  Color _getFloorColor(int floor) {
    switch (floor) {
      case 1: return const Color(0xFF2979FF);
      case 2: return const Color(0xFF00BCD4);
      case 3: return const Color(0xFF7C4DFF);
      default: return Colors.grey;
    }
  }
}


// Floor Detail Screen with Mode Toggle
class FloorDetailScreen extends StatefulWidget {
  final int floor;
  final Uint8List imageBytes;
  final VoidCallback onMapUpdated;

  const FloorDetailScreen({Key? key, required this.floor, required this.imageBytes, required this.onMapUpdated}) : super(key: key);

  @override
  State<FloorDetailScreen> createState() => _FloorDetailScreenState();
}

class _FloorDetailScreenState extends State<FloorDetailScreen> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF132F4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Floor ${widget.floor}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _buildModeButton(icon: Icons.map_outlined, label: 'View Map', isSelected: !_isEditMode, onTap: () => setState(() => _isEditMode = false))),
                const SizedBox(width: 12),
                Expanded(child: _buildModeButton(icon: Icons.edit_road, label: 'Edit Paths', isSelected: _isEditMode, onTap: () => setState(() => _isEditMode = true))),
              ],
            ),
          ),
        ),
      ),
      body: _isEditMode ? PathEditorView(floor: widget.floor, imageBytes: widget.imageBytes) : MapViewMode(floor: widget.floor, imageBytes: widget.imageBytes, onMapUpdated: widget.onMapUpdated),
    );
  }

  Widget _buildModeButton({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white60),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }
}


// Map View Mode
class MapViewMode extends StatefulWidget {
  final int floor;
  final Uint8List imageBytes;
  final VoidCallback onMapUpdated;

  const MapViewMode({Key? key, required this.floor, required this.imageBytes, required this.onMapUpdated}) : super(key: key);

  @override
  State<MapViewMode> createState() => _MapViewModeState();
}

class _MapViewModeState extends State<MapViewMode> {
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];
  final List<LocationPin> _locations = [];
  bool _isLoading = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _calculateImageSize();
    _loadData();
  }

  void _calculateImageSize() {
    final image = Image.memory(widget.imageBytes);
    image.image.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadGraph(), _loadLocations()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadGraph() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/graph/${widget.floor}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['exists'] == true) {
          setState(() {
            _nodes.clear();
            _edges.clear();
            for (var nodeData in data['nodes'] ?? []) {
              _nodes.add(GraphNode(id: nodeData['id'], x: nodeData['x'].toDouble(), y: nodeData['y'].toDouble(), label: nodeData['label'] ?? ''));
            }
            for (var edgeData in data['edges'] ?? []) {
              _edges.add(GraphEdge(id: edgeData['id'], fromNodeId: edgeData['from_node'], toNodeId: edgeData['to_node']));
            }
          });
        }
      }
    } catch (e) {
      print('Error loading graph: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/${widget.floor}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          _locations.clear();
          for (var loc in data) {
            _locations.add(LocationPin(name: loc['name'], x: loc['x'].toDouble(), y: loc['y'].toDouble()));
          }
        });
      }
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  Future<void> _replaceMap() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2500, maxHeight: 2500, imageQuality: 85);
    if (picked == null) return;

    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/${widget.floor}');
    final req = http.MultipartRequest('POST', uri)..files.add(await http.MultipartFile.fromPath('file', picked.path));

    try {
      final resp = await req.send();
      final respBody = await resp.stream.bytesToString();
      final respJson = jsonDecode(respBody);
      if (resp.statusCode == 200 && respJson['success'] == true) {
        widget.onMapUpdated();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Map replaced successfully!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00C853)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageSize == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Stack(
            children: [
              Image.memory(widget.imageBytes, fit: BoxFit.none),
              CustomPaint(size: _imageSize!, painter: MapViewPainter(nodes: _nodes, edges: _edges, locations: _locations, imageSize: _imageSize!)),
            ],
          ),
        ),
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: Row(
            children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _replaceMap,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text('Replace Map', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/admin/location_marking'),
                icon: const Icon(Icons.location_on, size: 18),
                label: Text('Locations', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              )),
            ],
          ),
        ),
      ],
    );
  }
}


// Path Editor View with Advanced Modes
class PathEditorView extends StatefulWidget {
  final int floor;
  final Uint8List imageBytes;

  const PathEditorView({Key? key, required this.floor, required this.imageBytes}) : super(key: key);

  @override
  State<PathEditorView> createState() => _PathEditorViewState();
}

class _PathEditorViewState extends State<PathEditorView> {
  final TransformationController _transformController = TransformationController();
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];
  final List<LocationPin> _locations = [];
  String _activeMode = 'none'; // 'add_node' | 'add_edge' | 'delete' | 'none'
  String? _selectedNodeId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _calculateImageSize();
    _loadData();
  }

  void _calculateImageSize() {
    final image = Image.memory(widget.imageBytes);
    image.image.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadGraph(), _loadLocations()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadGraph() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/graph/${widget.floor}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['exists'] == true) {
          setState(() {
            _nodes.clear();
            _edges.clear();
            for (var nodeData in data['nodes'] ?? []) {
              _nodes.add(GraphNode(id: nodeData['id'], x: nodeData['x'].toDouble(), y: nodeData['y'].toDouble(), label: nodeData['label'] ?? ''));
            }
            for (var edgeData in data['edges'] ?? []) {
              _edges.add(GraphEdge(id: edgeData['id'], fromNodeId: edgeData['from_node'], toNodeId: edgeData['to_node']));
            }
          });
        }
      }
    } catch (e) {
      print('Error loading graph: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/${widget.floor}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          _locations.clear();
          for (var loc in data) {
            _locations.add(LocationPin(name: loc['name'], x: loc['x'].toDouble(), y: loc['y'].toDouble()));
          }
        });
      }
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  Future<void> _saveGraph() async {
    setState(() => _isSaving = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/graph/${widget.floor}');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nodes': _nodes.map((n) => {'id': n.id, 'x': n.x, 'y': n.y, 'label': n.label}).toList(),
          'edges': _edges.map((e) => {'id': e.id, 'from_node': e.fromNodeId, 'to_node': e.toNodeId}).toList(),
        }),
      );
      if (resp.statusCode == 200) {
        setState(() => _hasUnsavedChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Path graph saved — ${_nodes.length} nodes, ${_edges.length} edges', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00C853)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Save failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _handleMapTap(Offset localPosition) {
    if (_imageSize == null) return;

    if (_activeMode == 'add_node') {
      _addNode(localPosition);
    } else if (_activeMode == 'add_edge') {
      _handleEdgeCreation(localPosition);
    } else if (_activeMode == 'delete') {
      _handleDelete(localPosition);
    }
  }

  void _addNode(Offset localPosition) {
    final normalizedX = localPosition.dx / _imageSize!.width;
    final normalizedY = localPosition.dy / _imageSize!.height;
    final newNode = GraphNode(id: const Uuid().v4(), x: normalizedX, y: normalizedY, label: '');
    setState(() {
      _nodes.add(newNode);
      _hasUnsavedChanges = true;
    });
  }

  void _handleEdgeCreation(Offset localPosition) {
    final tappedNodeId = _findNodeAtPosition(localPosition);
    if (tappedNodeId == null) return;

    if (_selectedNodeId == null) {
      // First tap - select "from" node
      setState(() => _selectedNodeId = tappedNodeId);
    } else if (_selectedNodeId == tappedNodeId) {
      // Same node tapped - deselect
      setState(() => _selectedNodeId = null);
    } else {
      // Second tap - create edge
      final edgeExists = _edges.any((e) => (e.fromNodeId == _selectedNodeId && e.toNodeId == tappedNodeId) || (e.fromNodeId == tappedNodeId && e.toNodeId == _selectedNodeId));
      if (!edgeExists) {
        setState(() {
          _edges.add(GraphEdge(id: const Uuid().v4(), fromNodeId: _selectedNodeId!, toNodeId: tappedNodeId));
          _selectedNodeId = null;
          _hasUnsavedChanges = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edge already exists', style: GoogleFonts.inter()), backgroundColor: Colors.orange));
        setState(() => _selectedNodeId = null);
      }
    }
  }

  void _handleDelete(Offset localPosition) {
    final tappedNodeId = _findNodeAtPosition(localPosition);
    if (tappedNodeId != null) {
      _deleteNode(tappedNodeId);
      return;
    }
    final tappedEdgeId = _findEdgeAtPosition(localPosition);
    if (tappedEdgeId != null) {
      _deleteEdge(tappedEdgeId);
    }
  }

  String? _findNodeAtPosition(Offset position) {
    for (var node in _nodes) {
      final nodePos = Offset(node.x * _imageSize!.width, node.y * _imageSize!.height);
      final distance = (position - nodePos).distance;
      if (distance <= 20) return node.id;
    }
    return null;
  }

  String? _findEdgeAtPosition(Offset position) {
    for (var edge in _edges) {
      final fromNode = _nodes.firstWhere((n) => n.id == edge.fromNodeId, orElse: () => _nodes.first);
      final toNode = _nodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => _nodes.first);
      final from = Offset(fromNode.x * _imageSize!.width, fromNode.y * _imageSize!.height);
      final to = Offset(toNode.x * _imageSize!.width, toNode.y * _imageSize!.height);
      final distance = _pointToLineDistance(position, from, to);
      if (distance <= 10) return edge.id;
    }
    return null;
  }

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

  void _deleteNode(String nodeId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delete node and all its edges?', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFFF6D00),
        action: SnackBarAction(label: 'DELETE', textColor: Colors.white, onPressed: () {
          setState(() {
            _nodes.removeWhere((n) => n.id == nodeId);
            _edges.removeWhere((e) => e.fromNodeId == nodeId || e.toNodeId == nodeId);
            _hasUnsavedChanges = true;
          });
        }),
      ),
    );
  }

  void _deleteEdge(String edgeId) {
    setState(() {
      _edges.removeWhere((e) => e.id == edgeId);
      _hasUnsavedChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edge deleted', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFFF6D00),
        action: SnackBarAction(label: 'UNDO', textColor: Colors.white, onPressed: () {
          // TODO: Implement undo
        }),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('This will delete all nodes and edges. This action cannot be undone.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _nodes.clear();
                _edges.clear();
                _selectedNodeId = null;
                _hasUnsavedChanges = true;
              });
            },
            child: Text('Clear All', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageSize == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Unsaved Changes', style: GoogleFonts.outfit(color: Colors.white)),
              content: Text('You have unsaved changes. Do you want to leave without saving?', style: GoogleFonts.inter(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Leave', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Stack(
        children: [
          // Toolbar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF132F4C), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(
                children: [
                  _buildToolButton(icon: Icons.add_location_alt, label: 'Add Node', mode: 'add_node'),
                  const SizedBox(width: 8),
                  _buildToolButton(icon: Icons.timeline, label: 'Add Edge', mode: 'add_edge'),
                  const SizedBox(width: 8),
                  _buildToolButton(icon: Icons.delete_outline, label: 'Delete', mode: 'delete'),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _nodes.isEmpty ? null : _clearAll,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: Text('Clear', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveGraph,
                    icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  )),
                ],
              ),
            ),
          ),
          // Map Canvas
          Positioned.fill(
            top: 80,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 5.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              child: GestureDetector(
                onTapDown: (details) => _handleMapTap(details.localPosition),
                child: Stack(
                  children: [
                    Image.memory(widget.imageBytes, fit: BoxFit.none),
                    CustomPaint(size: _imageSize!, painter: PathEditorPainter(nodes: _nodes, edges: _edges, locations: _locations, imageSize: _imageSize!, selectedNodeId: _selectedNodeId, activeMode: _activeMode)),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Stats
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF132F4C), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_tree, size: 16, color: const Color(0xFF2979FF)),
                  const SizedBox(width: 6),
                  Text('${_nodes.length} nodes', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Icon(Icons.timeline, size: 16, color: const Color(0xFF00BCD4)),
                  const SizedBox(width: 6),
                  Text('${_edges.length} edges', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (_hasUnsavedChanges) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.circle, size: 8, color: const Color(0xFFFF6D00)),
                    const SizedBox(width: 6),
                    Text('Unsaved', style: GoogleFonts.inter(color: const Color(0xFFFF6D00), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required String label, required String mode}) {
    final isActive = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeMode = isActive ? 'none' : mode;
          if (_activeMode != 'add_edge') _selectedNodeId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white60),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: isActive ? Colors.white : Colors.white60, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}


// Data Models
class GraphNode {
  final String id;
  final double x;
  final double y;
  final String label;

  GraphNode({required this.id, required this.x, required this.y, required this.label});
}

class GraphEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;

  GraphEdge({required this.id, required this.fromNodeId, required this.toNodeId});
}

class LocationPin {
  final String name;
  final double x;
  final double y;

  LocationPin({required this.name, required this.x, required this.y});
}

// Map View Painter (View Mode)
class MapViewPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<LocationPin> locations;
  final Size imageSize;

  MapViewPainter({required this.nodes, required this.edges, required this.locations, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges (thin lines)
    final edgePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.fromNodeId, orElse: () => nodes.first);
      final toNode = nodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => nodes.first);
      final from = Offset(fromNode.x * imageSize.width, fromNode.y * imageSize.height);
      final to = Offset(toNode.x * imageSize.width, toNode.y * imageSize.height);
      canvas.drawLine(from, to, edgePaint);
    }

    // Draw nodes (small hollow circles)
    for (var node in nodes) {
      final pos = Offset(node.x * imageSize.width, node.y * imageSize.height);
      final outerPaint = Paint()..color = const Color(0xFF2979FF)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawCircle(pos, 6, outerPaint);
    }

    // Draw location pins
    for (var location in locations) {
      final pos = Offset(location.x, location.y);
      
      // Pin (triangle + circle)
      final pinPaint = Paint()..color = const Color(0xFF7C4DFF)..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 8, pinPaint);
      
      final path = Path();
      path.moveTo(pos.dx, pos.dy);
      path.lineTo(pos.dx - 6, pos.dy + 12);
      path.lineTo(pos.dx + 6, pos.dy + 12);
      path.close();
      canvas.drawPath(path, pinPaint);
      
      // Label
      final textPainter = TextPainter(
        text: TextSpan(text: location.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final labelBg = Paint()..color = const Color(0xFF7C4DFF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx - textPainter.width / 2 - 4, pos.dy + 16, textPainter.width + 8, textPainter.height + 4),
          const Radius.circular(4),
        ),
        labelBg,
      );
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Path Editor Painter (Edit Mode)
class PathEditorPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<LocationPin> locations;
  final Size imageSize;
  final String? selectedNodeId;
  final String activeMode;

  PathEditorPainter({required this.nodes, required this.edges, required this.locations, required this.imageSize, this.selectedNodeId, required this.activeMode});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.fromNodeId, orElse: () => nodes.first);
      final toNode = nodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => nodes.first);
      final from = Offset(fromNode.x * imageSize.width, fromNode.y * imageSize.height);
      final to = Offset(toNode.x * imageSize.width, toNode.y * imageSize.height);
      canvas.drawLine(from, to, edgePaint);
    }

    // Draw nodes
    for (var node in nodes) {
      final pos = Offset(node.x * imageSize.width, node.y * imageSize.height);
      final isSelected = node.id == selectedNodeId;
      
      Color nodeColor = const Color(0xFF00BCD4);
      if (isSelected && activeMode == 'add_edge') {
        nodeColor = const Color(0xFF00C853); // Green for "from" node
      } else if (isSelected) {
        nodeColor = const Color(0xFFFF6D00); // Orange for selected
      }
      
      // Filled circle
      final fillPaint = Paint()..color = nodeColor..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 10, fillPaint);
      
      // White border
      final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawCircle(pos, 10, borderPaint);
    }

    // Draw location pins (read-only)
    for (var location in locations) {
      final pos = Offset(location.x, location.y);
      final pinPaint = Paint()..color = const Color(0xFF7C4DFF).withOpacity(0.5)..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 6, pinPaint);
      
      final textPainter = TextPainter(
        text: TextSpan(text: location.name, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
