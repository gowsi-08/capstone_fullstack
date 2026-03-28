import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../api_service.dart';

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
    
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
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
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2500,
      maxHeight: 2500,
      imageQuality: 85,
    );
    
    if (picked == null) return;

    setState(() => _loadingStates[floor] = true);
    
    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', picked.path));

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
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openFloorDetail(int floor, Uint8List? imageBytes) {
    if (imageBytes == null) {
      _uploadMapForFloor(floor);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FloorDetailScreen(
          floor: floor,
          imageBytes: imageBytes,
          onMapUpdated: () => _loadSingleFloorMap(floor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF132F4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Floor Plans & Navigation', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
            Text('Tap to edit paths and locations', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadAllFloorMaps),
        ],
      ),
      body: _isInitialLoading
          ? _buildLoadingSkeleton()
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _floors.length,
              itemBuilder: (context, index) => _buildFloorCard(_floors[index]),
            ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
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
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF), strokeWidth: 2))
            else if (imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.upload_file, size: 40, color: Colors.white.withOpacity(0.3)),
                    ),
                    const SizedBox(height: 12),
                    Text('No map uploaded', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getFloorColor(floor)),
                ),
                child: Text('Floor $floor', style: GoogleFonts.inter(color: _getFloorColor(floor), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
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

  const FloorDetailScreen({
    Key? key,
    required this.floor,
    required this.imageBytes,
    required this.onMapUpdated,
  }) : super(key: key);

  @override
  State<FloorDetailScreen> createState() => _FloorDetailScreenState();
}

class _FloorDetailScreenState extends State<FloorDetailScreen> {
  bool _isEditMode = false; // false = View Map, true = Edit Paths

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
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.map_outlined,
                    label: 'View Map',
                    isSelected: !_isEditMode,
                    onTap: () => setState(() => _isEditMode = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.edit_road,
                    label: 'Edit Paths',
                    isSelected: _isEditMode,
                    onTap: () => setState(() => _isEditMode = true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isEditMode
          ? PathEditorView(floor: widget.floor, imageBytes: widget.imageBytes)
          : MapViewMode(floor: widget.floor, imageBytes: widget.imageBytes, onMapUpdated: widget.onMapUpdated),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Map View Mode (existing functionality)
class MapViewMode extends StatelessWidget {
  final int floor;
  final Uint8List imageBytes;
  final VoidCallback onMapUpdated;

  const MapViewMode({Key? key, required this.floor, required this.imageBytes, required this.onMapUpdated}) : super(key: key);

  Future<void> _replaceMap(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2500, maxHeight: 2500, imageQuality: 85);
    if (picked == null) return;

    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)..files.add(await http.MultipartFile.fromPath('file', picked.path));

    try {
      final resp = await req.send();
      final respBody = await resp.stream.bytesToString();
      final respJson = jsonDecode(respBody);

      if (resp.statusCode == 200 && respJson['success'] == true) {
        onMapUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Map replaced successfully!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00C853)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Center(child: Image.memory(imageBytes, fit: BoxFit.contain)),
        ),
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _replaceMap(context),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text('Replace Map', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/admin/location_marking'),
                  icon: const Icon(Icons.location_on, size: 18),
                  label: Text('Locations', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Path Editor View (NEW)
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
  String? _selectedNodeId;
  bool _isLoading = true;
  bool _isSaving = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadGraph();
    _calculateImageSize();
  }

  void _calculateImageSize() {
    final image = Image.memory(widget.imageBytes);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
          });
        }
      }),
    );
  }

  Future<void> _loadGraph() async {
    setState(() => _isLoading = true);
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
              _nodes.add(GraphNode(
                id: nodeData['id'],
                x: nodeData['x'].toDouble(),
                y: nodeData['y'].toDouble(),
                label: nodeData['label'] ?? '',
              ));
            }
            
            for (var edgeData in data['edges'] ?? []) {
              _edges.add(GraphEdge(
                id: edgeData['id'],
                fromNodeId: edgeData['from_node'],
                toNodeId: edgeData['to_node'],
              ));
            }
          });
        }
      }
    } catch (e) {
      print('Error loading graph: $e');
    } finally {
      setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Graph saved successfully!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00C853)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Save failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addNode(Offset localPosition) {
    if (_imageSize == null) return;
    
    // Normalize coordinates
    final normalizedX = localPosition.dx / _imageSize!.width;
    final normalizedY = localPosition.dy / _imageSize!.height;
    
    final newNode = GraphNode(
      id: const Uuid().v4(),
      x: normalizedX,
      y: normalizedY,
      label: '',
    );
    
    setState(() {
      // If a node is selected, create edge to new node
      if (_selectedNodeId != null) {
        _edges.add(GraphEdge(
          id: const Uuid().v4(),
          fromNodeId: _selectedNodeId!,
          toNodeId: newNode.id,
        ));
      }
      _nodes.add(newNode);
      _selectedNodeId = newNode.id;
    });
  }

  void _deleteNode(String nodeId) {
    setState(() {
      _nodes.removeWhere((n) => n.id == nodeId);
      _edges.removeWhere((e) => e.fromNodeId == nodeId || e.toNodeId == nodeId);
      if (_selectedNodeId == nodeId) _selectedNodeId = null;
    });
  }

  void _deleteEdge(String edgeId) {
    setState(() => _edges.removeWhere((e) => e.id == edgeId));
  }

  void _clearGraph() {
    setState(() {
      _nodes.clear();
      _edges.clear();
      _selectedNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    return Stack(
      children: [
        // Map with graph overlay
        InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 5.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1000),
          child: GestureDetector(
            onTapDown: (details) => _addNode(details.localPosition),
            child: Stack(
              children: [
                Image.memory(widget.imageBytes, fit: BoxFit.none),
                if (_imageSize != null)
                  CustomPaint(
                    size: _imageSize!,
                    painter: GraphPainter(
                      nodes: _nodes,
                      edges: _edges,
                      selectedNodeId: _selectedNodeId,
                      imageSize: _imageSize!,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Top toolbar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF132F4C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap to add nodes • Tap node to select • Auto-connects to last selected',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Bottom action bar
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132F4C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree, size: 16, color: const Color(0xFF2979FF)),
                    const SizedBox(width: 8),
                    Text('${_nodes.length} nodes', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Icon(Icons.timeline, size: 16, color: const Color(0xFF00BCD4)),
                    const SizedBox(width: 8),
                    Text('${_edges.length} edges', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nodes.isEmpty ? null : _clearGraph,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text('Clear', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveGraph,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save Graph', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Graph data models
class GraphNode {
  final String id;
  final double x; // Normalized 0-1
  final double y; // Normalized 0-1
  final String label;

  GraphNode({required this.id, required this.x, required this.y, required this.label});
}

class GraphEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;

  GraphEdge({required this.id, required this.fromNodeId, required this.toNodeId});
}

// Custom painter for graph visualization
class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedNodeId;
  final Size imageSize;

  GraphPainter({required this.nodes, required this.edges, this.selectedNodeId, required this.imageSize});

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
      
      // Outer circle
      final outerPaint = Paint()
        ..color = isSelected ? const Color(0xFF00C853) : const Color(0xFF2979FF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, isSelected ? 12 : 10, outerPaint);
      
      // Inner circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, isSelected ? 6 : 4, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
