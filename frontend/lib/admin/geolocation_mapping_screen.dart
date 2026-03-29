import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../api_service.dart';
import '../models/graph_models.dart';

class GeolocationMappingScreen extends StatefulWidget {
  const GeolocationMappingScreen({Key? key}) : super(key: key);

  @override
  State<GeolocationMappingScreen> createState() => _GeolocationMappingScreenState();
}

class _GeolocationMappingScreenState extends State<GeolocationMappingScreen> {
  int _currentFloor = 1;
  List<GraphNode> _graphNodes = [];
  List<GraphEdge> _graphEdges = [];
  bool _isLoading = true;
  Uint8List? _mapImageBytes;
  Size? _imageSize;
  String? _selectedNodeId;
  Position? _currentPosition;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadFloorData();
  }

  Future<void> _loadFloorData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadMapImage(),
        _loadGraph(),
      ]);
    } catch (e) {
      print('Error loading floor data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMapImage() async {
    try {
      final b64 = await ApiService.getMapBase64(_currentFloor.toString());
      if (b64 != null && mounted) {
        final bytes = base64Decode(b64);
        setState(() => _mapImageBytes = bytes);
        _calculateImageSize(bytes);
      }
    } catch (e) {
      print('Error loading map: $e');
    }
  }

  void _calculateImageSize(Uint8List bytes) {
    final image = Image.memory(bytes);
    image.image.resolve(const ImageConfiguration()).addListener(
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

  Future<void> _loadGraph() async {
    try {
      final graphData = await ApiService.getWalkableGraph(_currentFloor);
      if (graphData != null && graphData['exists'] == true && mounted) {
        setState(() {
          _graphNodes.clear();
          _graphEdges.clear();
          
          for (var nodeData in graphData['nodes'] ?? []) {
            _graphNodes.add(GraphNode.fromJson(nodeData));
          }
          
          for (var edgeData in graphData['edges'] ?? []) {
            _graphEdges.add(GraphEdge.fromJson(edgeData));
          }
        });
      }
    } catch (e) {
      print('Error loading graph: $e');
    }
  }

  void _changeFloor(int floor) {
    setState(() {
      _currentFloor = floor;
      _selectedNodeId = null;
      _currentPosition = null;
    });
    _loadFloorData();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('❌ Location permissions denied', Colors.red);
          setState(() => _isGettingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('❌ Location permissions permanently denied', Colors.red);
        setState(() => _isGettingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });

      _showSnackBar(
        '✅ Location acquired: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        const Color(0xFF00C853),
      );
    } catch (e) {
      setState(() => _isGettingLocation = false);
      _showSnackBar('❌ Failed to get location: $e', Colors.red);
    }
  }

  Future<void> _assignLocationToNode() async {
    if (_selectedNodeId == null || _currentPosition == null) return;

    try {
      // Find the node and update it
      final nodeIndex = _graphNodes.indexWhere((n) => n.id == _selectedNodeId);
      if (nodeIndex == -1) {
        throw Exception('Node not found');
      }

      _graphNodes[nodeIndex] = _graphNodes[nodeIndex].copyWith(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      // Save the graph
      final nodesJson = _graphNodes.map((n) => n.toJson()).toList();
      final edgesJson = _graphEdges.map((e) => e.toJson()).toList();

      final success = await ApiService.saveWalkableGraph(_currentFloor, nodesJson, edgesJson);

      if (success) {
        await _loadGraph();
        
        if (mounted) {
          final node = _graphNodes[nodeIndex];
          _showSnackBar(
            '✅ GPS coordinates assigned to node at (${(node.x * 100).toStringAsFixed(0)}%, ${(node.y * 100).toStringAsFixed(0)}%)',
            const Color(0xFF00C853),
          );
          
          setState(() {
            _selectedNodeId = null;
            _currentPosition = null;
          });
        }
      } else {
        throw Exception('Failed to save graph');
      }
    } catch (e) {
      _showSnackBar('❌ Failed to assign location: $e', Colors.red);
    }
  }

  void _handleNodeTap(String nodeId) {
    setState(() {
      _selectedNodeId = nodeId;
    });
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
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Geolocation Mapping',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Text(
                'Assign GPS coordinates to nodes',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadFloorData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFloorSelector(),
          _buildInstructionBanner(),
          Expanded(child: _buildMapPanel()),
          _buildBottomControls(),
        ],
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
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  'Floor $floor',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF2979FF).withOpacity(0.2),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2979FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Get GPS → Select Node → Assign',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    if (_mapImageBytes == null || _imageSize == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'No map loaded for Floor $_currentFloor',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
              minScale: 0.5,
              maxScale: 5.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              child: GestureDetector(
                onTapDown: (details) {
                  // Find tapped node
                  for (var node in _graphNodes) {
                    final nodePos = Offset(
                      node.x * _imageSize!.width,
                      node.y * _imageSize!.height,
                    );
                    final distance = (details.localPosition - nodePos).distance;
                    
                    if (distance <= 20) {
                      _handleNodeTap(node.id);
                      return;
                    }
                  }
                },
                child: Stack(
                  children: [
                    Image.memory(_mapImageBytes!, fit: BoxFit.none),
                    CustomPaint(
                      size: _imageSize!,
                      painter: GeoLocationMapPainter(
                        nodes: _graphNodes,
                        edges: _graphEdges,
                        imageSize: _imageSize!,
                        selectedNodeId: _selectedNodeId,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Legend
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legend',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      color: const Color(0xFF00C853),
                      label: 'Has GPS',
                      isFilled: true,
                    ),
                    const SizedBox(height: 4),
                    _buildLegendItem(
                      color: const Color(0xFF2979FF),
                      label: 'No GPS',
                      isFilled: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isFilled,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isFilled ? 0 : 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final selectedNode = _selectedNodeId != null
        ? _graphNodes.firstWhere((n) => n.id == _selectedNodeId, orElse: () => _graphNodes.first)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status Row
          Row(
            children: [
              // GPS Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _currentPosition != null
                        ? const Color(0xFF00C853).withOpacity(0.1)
                        : const Color(0xFF0A1929),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentPosition != null
                          ? const Color(0xFF00C853)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.gps_fixed : Icons.gps_off,
                            color: _currentPosition != null
                                ? const Color(0xFF00C853)
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentPosition != null ? 'GPS Ready' : 'No GPS',
                            style: GoogleFonts.inter(
                              color: _currentPosition != null
                                  ? const Color(0xFF00C853)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_currentPosition != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '±${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Node Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedNode != null
                        ? const Color(0xFF7C4DFF).withOpacity(0.1)
                        : const Color(0xFF0A1929),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedNode != null
                          ? const Color(0xFF7C4DFF)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selectedNode != null ? Icons.location_on : Icons.location_off,
                            color: selectedNode != null
                                ? const Color(0xFF7C4DFF)
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedNode != null ? 'Node Selected' : 'No Node',
                              style: GoogleFonts.inter(
                                color: selectedNode != null
                                    ? const Color(0xFF7C4DFF)
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (selectedNode != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedNode.datasetLocation ?? 'Corridor',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1929),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_graphNodes.where((n) => n.hasGeoLocation).length}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2979FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'GPS',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(
                    _isGettingLocation ? 'Getting...' : 'Get GPS',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_currentPosition != null && _selectedNodeId != null)
                      ? _assignLocationToNode
                      : null,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(
                    'Assign',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.1),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Geolocation Map
class GeoLocationMapPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Size imageSize;
  final String? selectedNodeId;

  GeoLocationMapPainter({
    required this.nodes,
    required this.edges,
    required this.imageSize,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.2)
      ..strokeWidth = 1.5
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
      final hasGPS = node.hasGeoLocation;

      if (isSelected) {
        // Selected node: Large pulsing purple circle
        final highlightPaint = Paint()
          ..color = const Color(0xFF7C4DFF).withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 20, highlightPaint);

        final selectedPaint = Paint()
          ..color = const Color(0xFF7C4DFF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 10, selectedPaint);

        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(pos, 10, borderPaint);
      } else if (hasGPS) {
        // Node with GPS: Green filled circle
        final gpsPaint = Paint()
          ..color = const Color(0xFF00C853)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 6, gpsPaint);

        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 6, borderPaint);

        // Small glow
        final glowPaint = Paint()
          ..color = const Color(0xFF00C853).withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 10, glowPaint);
      } else {
        // Node without GPS: Hollow blue circle
        final nodePaint = Paint()
          ..color = const Color(0xFF2979FF).withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 4, nodePaint);

        final centerPaint = Paint()
          ..color = const Color(0xFF2979FF).withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 1.5, centerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
