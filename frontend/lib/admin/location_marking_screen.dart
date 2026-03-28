import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';

class LocationMarkingScreen extends StatefulWidget {
  const LocationMarkingScreen({Key? key}) : super(key: key);

  @override
  State<LocationMarkingScreen> createState() => _LocationMarkingScreenState();
}

class _LocationMarkingScreenState extends State<LocationMarkingScreen> with TickerProviderStateMixin {
  int _currentFloor = 1;
  final List<LocationMarker> _locations = [];
  final List<GraphNode> _graphNodes = [];
  final List<GraphEdge> _graphEdges = [];
  String? _selectedLocationId;
  bool _isPlacementMode = false;
  bool _isMoveMode = false;
  String? _movingLocationId;
  bool _isLoading = true;
  Uint8List? _mapImageBytes;
  Size? _imageSize;
  final TransformationController _transformController = TransformationController();
  late AnimationController _pulseController;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedLocationIds = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800), lowerBound: 0.9, upperBound: 1.1)..repeat(reverse: true);
    _loadFloorData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadMapImage(), _loadLocations(), _loadGraph()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadMapImage() async {
    final b64 = await ApiService.getMapBase64(_currentFloor.toString());
    if (b64 != null && mounted) {
      final bytes = base64Decode(b64);
      setState(() => _mapImageBytes = bytes);
      _calculateImageSize(bytes);
    }
  }


  void _calculateImageSize(Uint8List bytes) {
    final image = Image.memory(bytes);
    image.image.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }));
  }

  Future<void> _loadLocations() async {
    try {
      // OLD ENDPOINT REMOVED - Use getNodeDataGroups instead
      // This is a temporary stub until screen is rebuilt in Part 2
      setState(() {
        _locations.clear();
      });
      print('⚠️ Location marking screen needs rebuild - old endpoints removed');
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  Future<void> _loadGraph() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/graph/$_currentFloor');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['exists'] == true) {
          setState(() {
            _graphNodes.clear();
            _graphEdges.clear();
            for (var nodeData in data['nodes'] ?? []) {
              _graphNodes.add(GraphNode(id: nodeData['id'], x: nodeData['x'].toDouble(), y: nodeData['y'].toDouble(), label: nodeData['label'] ?? ''));
            }
            for (var edgeData in data['edges'] ?? []) {
              _graphEdges.add(GraphEdge(id: edgeData['id'], fromNodeId: edgeData['from_node'], toNodeId: edgeData['to_node']));
            }
          });
        }
      }
    } catch (e) {
      print('Error loading graph: $e');
    }
  }

  void _changeFloor(int floor) {
    setState(() {
      _currentFloor = floor;
      _selectedLocationId = null;
      _isPlacementMode = false;
      _isMoveMode = false;
      _isMultiSelectMode = false;
      _selectedLocationIds.clear();
    });
    _loadFloorData();
  }

  void _enterPlacementMode() {
    setState(() {
      _isPlacementMode = true;
      _selectedLocationId = null;
    });
  }

  void _handleMapTap(Offset localPosition) {
    if (_imageSize == null) return;

    if (_isPlacementMode) {
      _showAddLocationSheet(localPosition);
    } else if (_isMoveMode && _movingLocationId != null) {
      _moveLocation(_movingLocationId!, localPosition);
    } else {
      _selectLocationAtPosition(localPosition);
    }
  }

  void _selectLocationAtPosition(Offset position) {
    for (var location in _locations) {
      final locPos = Offset(location.x, location.y);
      final distance = (position - locPos).distance;
      if (distance <= 30) {
        setState(() => _selectedLocationId = location.id);
        _centerOnLocation(location);
        return;
      }
    }
    setState(() => _selectedLocationId = null);
  }

  void _centerOnLocation(LocationMarker location) {
    if (_imageSize == null) return;
    const double targetScale = 2.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final transX = (screenWidth / 2) - (location.x * targetScale);
    final transY = (screenHeight / 2) - (location.y * targetScale);
    final endMatrix = Matrix4.identity()..translate(transX, transY)..scale(targetScale);
    _transformController.value = endMatrix;
  }

  Future<void> _showAddLocationSheet(Offset position) async {
    final nameController = TextEditingController();
    final landmarkController = TextEditingController();
    String? selectedNodeId;

    final nearestNodes = _findNearestNodes(position, 3);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_location_alt, color: Color(0xFF00BCD4), size: 28),
                    const SizedBox(width: 12),
                    Text('Add Location', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Location Name *',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    hintText: 'e.g. Room 101, Lab, Corridor',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: landmarkController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Landmark (Optional)',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    hintText: 'e.g. Near main entrance',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2)),
                  ),
                ),
                if (nearestNodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Connect to Node', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedNodeId,
                        hint: Text('Select nearest node', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4))),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white),
                        items: nearestNodes.map((node) {
                          final distance = _calculateDistance(position, Offset(node.x * (_imageSize?.width ?? 1), node.y * (_imageSize?.height ?? 1)));
                          return DropdownMenuItem(
                            value: node.id,
                            child: Text('Node at (${(node.x * 100).toStringAsFixed(0)}%, ${(node.y * 100).toStringAsFixed(0)}%) - ${distance.toStringAsFixed(0)}px away', style: GoogleFonts.inter(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (value) => setModalState(() => selectedNodeId = value),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location name is required', style: GoogleFonts.inter())));
                            return;
                          }
                          Navigator.pop(context, {
                            'name': nameController.text.trim(),
                            'landmark': landmarkController.text.trim(),
                            'nodeId': selectedNodeId,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Add Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      await _addLocation(position, result['name'], result['landmark'], result['nodeId']);
    }

    setState(() => _isPlacementMode = false);
  }

  List<GraphNode> _findNearestNodes(Offset position, int count) {
    if (_graphNodes.isEmpty || _imageSize == null) return [];
    final nodes = List<GraphNode>.from(_graphNodes);
    nodes.sort((a, b) {
      final aDist = _calculateDistance(position, Offset(a.x * _imageSize!.width, a.y * _imageSize!.height));
      final bDist = _calculateDistance(position, Offset(b.x * _imageSize!.width, b.y * _imageSize!.height));
      return aDist.compareTo(bDist);
    });
    return nodes.take(count).toList();
  }

  double _calculateDistance(Offset a, Offset b) {
    return math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
  }

  Future<void> _addLocation(Offset position, String name, String landmark, String? nodeId) async {
    try {
      // OLD ENDPOINT REMOVED - This functionality will be replaced in Part 2 rebuild
      _showSnackBar('⚠️ Location marking screen needs rebuild', Colors.orange);
      print('⚠️ Old location endpoints removed - screen needs Part 2 rebuild');
    } catch (e) {
      _showSnackBar('❌ Failed to add location: $e', Colors.red);
    }
  }

  Future<void> _moveLocation(String locationId, Offset newPosition) async {
    try {
      // OLD ENDPOINT REMOVED - This functionality will be replaced in Part 2 rebuild
      _showSnackBar('⚠️ Location marking screen needs rebuild', Colors.orange);
      setState(() {
        _isMoveMode = false;
        _movingLocationId = null;
      });
    } catch (e) {
      _showSnackBar('❌ Failed to move location: $e', Colors.red);
    }
  }

  Future<void> _deleteLocation(String locationId) async {
    try {
      // OLD ENDPOINT REMOVED - This functionality will be replaced in Part 2 rebuild
      _showSnackBar('⚠️ Location marking screen needs rebuild', Colors.orange);
      setState(() => _selectedLocationId = null);
    } catch (e) {
      _showSnackBar('❌ Failed to delete location: $e', Colors.red);
    }
  }

  Future<void> _bulkDelete() async {
    for (var id in _selectedLocationIds) {
      await _deleteLocation(id);
    }
    setState(() {
      _isMultiSelectMode = false;
      _selectedLocationIds.clear();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.inter(color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF132F4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Marking', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
            Text('Mark and edit room positions', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
          ],
        ),
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Delete Selected',
              onPressed: _selectedLocationIds.isEmpty ? null : () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Delete ${_selectedLocationIds.length} locations?', style: GoogleFonts.outfit(color: Colors.white)),
                    content: Text('This action cannot be undone.', style: GoogleFonts.inter(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          Navigator.pop(context);
                          _bulkDelete();
                        },
                        child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadFloorData),
        ],
      ),
      body: Column(
        children: [
          _buildFloorSelector(),
          if (_isPlacementMode) _buildPlacementBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
                : isTablet
                    ? Row(children: [Expanded(flex: 6, child: _buildMapPanel()), Expanded(flex: 4, child: _buildListPanel())])
                    : Column(children: [Expanded(flex: 6, child: _buildMapPanel()), Expanded(flex: 4, child: _buildListPanel())]),
          ),
        ],
      ),
      floatingActionButton: _isPlacementMode || _isMoveMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _enterPlacementMode,
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt),
              label: Text('Add Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildFloorSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [1, 2, 3].map((floor) {
          final isSelected = floor == _currentFloor;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeFloor(floor),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.1)),
                ),
                child: Text('Floor $floor', textAlign: TextAlign.center, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlacementBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF00BCD4).withOpacity(0.2),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Color(0xFF00BCD4), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Tap map to place location', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () => setState(() => _isPlacementMode = false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel() {
    if (_mapImageBytes == null || _imageSize == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No map loaded for Floor $_currentFloor', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 5.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              child: GestureDetector(
                onTapDown: (details) => _handleMapTap(details.localPosition),
                child: Stack(
                  children: [
                    Image.memory(_mapImageBytes!, fit: BoxFit.none),
                    CustomPaint(
                      size: _imageSize!,
                      painter: LocationMapPainter(
                        locations: _locations,
                        graphNodes: _graphNodes,
                        graphEdges: _graphEdges,
                        imageSize: _imageSize!,
                        selectedLocationId: _selectedLocationId,
                        pulseAnimation: _pulseController,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedLocationId != null) _buildLocationDetailPeek(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetailPeek() {
    final location = _locations.firstWhere((l) => l.id == _selectedLocationId);
    final connectedNode = _graphNodes.where((n) => n.id == location.nodeId).firstOrNull;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on, color: Color(0xFF00C853), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      if (connectedNode != null)
                        Text('Connected to node at (${(connectedNode.x * 100).toStringAsFixed(0)}%, ${(connectedNode.y * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 11))
                      else
                        Text('Not connected to any node', style: GoogleFonts.inter(color: Colors.orange.withOpacity(0.8), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white60, size: 20), onPressed: () => setState(() => _selectedLocationId = null)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditLocationSheet(location),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2979FF), side: const BorderSide(color: Color(0xFF2979FF)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSnapToNodeSheet(location),
                    icon: const Icon(Icons.link, size: 16),
                    label: Text('Snap', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00BCD4), side: const BorderSide(color: Color(0xFF00BCD4)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text('Delete Location?', style: GoogleFonts.outfit(color: Colors.white)),
                          content: Text('Delete "${location.name}"? This action cannot be undone.', style: GoogleFonts.inter(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteLocation(location.id);
                              },
                              child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text('Delete', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildListPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.list, color: Color(0xFF2979FF), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Locations (${_locations.length})', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                if (_isMultiSelectMode)
                  TextButton(
                    onPressed: () => setState(() {
                      _isMultiSelectMode = false;
                      _selectedLocationIds.clear();
                    }),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF2979FF), fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _locations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_location, size: 48, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text('No locations marked on this floor', style: GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Tap + to add your first location', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _locations.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    itemBuilder: (context, index) {
                      final location = _locations[index];
                      final isSelected = _selectedLocationId == location.id;
                      final isMultiSelected = _selectedLocationIds.contains(location.id);
                      final connectedNode = _graphNodes.where((n) => n.id == location.nodeId).firstOrNull;

                      return Dismissible(
                        key: Key(location.id),
                        direction: _isMultiSelectMode ? DismissDirection.none : DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text('Delete Location?', style: GoogleFonts.outfit(color: Colors.white)),
                              content: Text('Delete "${location.name}"?', style: GoogleFonts.inter(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteLocation(location.id),
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF00C853).withOpacity(0.1),
                          leading: _isMultiSelectMode
                              ? Checkbox(
                                  value: isMultiSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedLocationIds.add(location.id);
                                      } else {
                                        _selectedLocationIds.remove(location.id);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF2979FF),
                                )
                              : CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? const Color(0xFF00C853).withOpacity(0.2) : const Color(0xFF2979FF).withOpacity(0.2),
                                  child: Icon(Icons.location_on, size: 18, color: isSelected ? const Color(0xFF00C853) : const Color(0xFF2979FF)),
                                ),
                          title: Text(location.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF2979FF).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text('Floor $_currentFloor', style: GoogleFonts.inter(color: const Color(0xFF2979FF), fontSize: 10, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(connectedNode != null ? Icons.link : Icons.link_off, size: 12, color: connectedNode != null ? const Color(0xFF00C853) : Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(connectedNode != null ? 'Linked' : 'Unlinked', style: GoogleFonts.inter(color: connectedNode != null ? const Color(0xFF00C853) : Colors.orange, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                          trailing: _isMultiSelectMode ? null : const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
                          onTap: () {
                            if (_isMultiSelectMode) {
                              setState(() {
                                if (isMultiSelected) {
                                  _selectedLocationIds.remove(location.id);
                                } else {
                                  _selectedLocationIds.add(location.id);
                                }
                              });
                            } else {
                              setState(() => _selectedLocationId = location.id);
                              _centerOnLocation(location);
                            }
                          },
                          onLongPress: () {
                            if (!_isMultiSelectMode) {
                              setState(() {
                                _isMultiSelectMode = true;
                                _selectedLocationIds.add(location.id);
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditLocationSheet(LocationMarker location) async {
    final nameController = TextEditingController(text: location.name);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_location_alt, color: Color(0xFF2979FF), size: 28),
                  const SizedBox(width: 12),
                  Text('Edit Location', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Location Name',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Position (Read-only)', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('X: ${location.x.toStringAsFixed(1)}px', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                    Text('Y: ${location.y.toStringAsFixed(1)}px', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isMoveMode = true;
                    _movingLocationId = location.id;
                  });
                  _showSnackBar('Tap map to move location', const Color(0xFF00BCD4));
                },
                icon: const Icon(Icons.open_with, size: 18),
                label: Text('Move on Map', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 0),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'name': nameController.text.trim()}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result['name'] != location.name) {
      try {
        // OLD ENDPOINT REMOVED - This functionality will be replaced in Part 2 rebuild
        _showSnackBar('⚠️ Location marking screen needs rebuild', Colors.orange);
      } catch (e) {
        _showSnackBar('❌ Failed to update location: $e', Colors.red);
      }
    }
  }

  Future<void> _showSnapToNodeSheet(LocationMarker location) async {
    final nearestNodes = _findNearestNodes(Offset(location.x, location.y), 5);
    String? selectedNodeId = location.nodeId;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFF00BCD4), size: 28),
                    const SizedBox(width: 12),
                    Text('Snap to Node', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Select a graph node to connect this location:', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                const SizedBox(height: 16),
                ...nearestNodes.map((node) {
                  final distance = _calculateDistance(Offset(location.x, location.y), Offset(node.x * (_imageSize?.width ?? 1), node.y * (_imageSize?.height ?? 1)));
                  final isSelected = selectedNodeId == node.id;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedNodeId = node.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00BCD4).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFF00BCD4) : Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF00BCD4) : Colors.white.withOpacity(0.4), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Node at (${(node.x * 100).toStringAsFixed(0)}%, ${(node.y * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text('${distance.toStringAsFixed(0)}px away', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, selectedNodeId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Connect', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result != location.nodeId) {
      try {
        // OLD ENDPOINT REMOVED - This functionality will be replaced in Part 2 rebuild
        _showSnackBar('⚠️ Location marking screen needs rebuild', Colors.orange);
      } catch (e) {
        _showSnackBar('❌ Failed to connect: $e', Colors.red);
      }
    }
  }
}


// Data Models
class LocationMarker {
  final String id;
  final String name;
  final double x;
  final double y;
  final String? nodeId;

  LocationMarker({required this.id, required this.name, required this.x, required this.y, this.nodeId});
}

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

// Custom Painter for Location Map
class LocationMapPainter extends CustomPainter {
  final List<LocationMarker> locations;
  final List<GraphNode> graphNodes;
  final List<GraphEdge> graphEdges;
  final Size imageSize;
  final String? selectedLocationId;
  final Animation<double> pulseAnimation;

  LocationMapPainter({
    required this.locations,
    required this.graphNodes,
    required this.graphEdges,
    required this.imageSize,
    this.selectedLocationId,
    required this.pulseAnimation,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw graph edges (faint blue lines, read-only)
    final edgePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var edge in graphEdges) {
      final fromNode = graphNodes.firstWhere((n) => n.id == edge.fromNodeId, orElse: () => graphNodes.first);
      final toNode = graphNodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => graphNodes.first);
      final from = Offset(fromNode.x * imageSize.width, fromNode.y * imageSize.height);
      final to = Offset(toNode.x * imageSize.width, toNode.y * imageSize.height);
      canvas.drawLine(from, to, edgePaint);
    }

    // Draw graph nodes (tiny hollow circles, 30% opacity)
    final nodePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var node in graphNodes) {
      final pos = Offset(node.x * imageSize.width, node.y * imageSize.height);
      canvas.drawCircle(pos, 4, nodePaint);
    }

    // Draw location pins
    for (var location in locations) {
      final pos = Offset(location.x, location.y);
      final isSelected = location.id == selectedLocationId;
      final pinColor = isSelected ? const Color(0xFF00C853) : const Color(0xFF2979FF);
      final scale = isSelected ? pulseAnimation.value : 1.0;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(scale);

      // Draw pin (circle + downward triangle)
      final pinPaint = Paint()..color = pinColor..style = PaintingStyle.fill;

      // Circle
      canvas.drawCircle(Offset.zero, 12, pinPaint);

      // White center
      final centerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, 6, centerPaint);

      // Downward triangle
      final path = Path();
      path.moveTo(0, 12);
      path.lineTo(-8, 24);
      path.lineTo(8, 24);
      path.close();
      canvas.drawPath(path, pinPaint);

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset.zero, 12, shadowPaint);

      canvas.restore();

      // Draw location name label
      final textPainter = TextPainter(
        text: TextSpan(
          text: location.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelBg = Paint()..color = pinColor.withOpacity(0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pos.dx - textPainter.width / 2 - 6,
            pos.dy + 28,
            textPainter.width + 12,
            textPainter.height + 6,
          ),
          const Radius.circular(6),
        ),
        labelBg,
      );

      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 31));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
