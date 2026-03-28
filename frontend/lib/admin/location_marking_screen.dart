import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';
import '../models/graph_models.dart';
import 'floor_plan_screen.dart'; // For GraphMapPainter

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
  bool _isLoadingMap = false; // NEW: Separate loading state for map
  Uint8List? _mapImageBytes;
  Size? _imageSize;
  final TransformationController _transformController = TransformationController();
  late AnimationController _pulseController;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedLocationIds = {};
  
  // NEW: Node selection mode for Add Location flow
  bool _isNodeSelectionMode = false;
  String? _selectedNodeForAssignment;

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
    setState(() {
      _isLoading = true;
      _isLoadingMap = true;
    });
    
    try {
      // Load all data for the current floor in parallel
      await Future.wait([
        _loadMapImage(),
        _loadNavigableNodes(),
        _loadGraph(),
      ]);
    } catch (e) {
      print('Error loading floor data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMap = false;
        });
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
      } else {
        // No map for this floor
        if (mounted) {
          setState(() => _mapImageBytes = null);
        }
      }
    } catch (e) {
      print('Error loading map image: $e');
      if (mounted) {
        setState(() => _mapImageBytes = null);
      }
    }
  }

  void _calculateImageSize(Uint8List bytes) {
    final image = Image.memory(bytes);
    image.image.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }));
  }

  Future<void> _loadNavigableNodes() async {
    try {
      final nodes = await ApiService.getNavigableNodes(_currentFloor);
      if (mounted) {
        setState(() {
          _locations.clear();
          for (var node in nodes) {
            _locations.add(LocationMarker(
              id: node.nodeId,
              name: node.locationName,
              landmark: '',
              floor: node.floor,
              x: node.x,
              y: node.y,
              nodeId: node.nodeId,
            ));
          }
        });
      }
      print('📍 Loaded ${_locations.length} navigable nodes for floor $_currentFloor');
    } catch (e) {
      print('Error loading navigable nodes: $e');
    }
  }

  Future<void> _loadGraph() async {
    try {
      final graphData = await ApiService.getWalkableGraph(_currentFloor);
      if (graphData != null && graphData['exists'] == true && mounted) {
        setState(() {
          _graphNodes.clear();
          _graphEdges.clear();
          
          for (var nodeData in graphData['nodes'] ?? []) {
            _graphNodes.add(GraphNode(
              id: nodeData['id'],
              x: nodeData['x'].toDouble(),
              y: nodeData['y'].toDouble(),
              label: nodeData['label'] ?? '',
              datasetLocation: nodeData['dataset_location'],
              isDefault: nodeData['is_default'] ?? false,
            ));
          }
          
          for (var edgeData in graphData['edges'] ?? []) {
            _graphEdges.add(GraphEdge(
              id: edgeData['id'],
              fromNodeId: edgeData['from_node'],
              toNodeId: edgeData['to_node'],
            ));
          }
        });
        print('📊 Loaded graph: ${_graphNodes.length} nodes, ${_graphEdges.length} edges for floor $_currentFloor');
      } else {
        if (mounted) {
          setState(() {
            _graphNodes.clear();
            _graphEdges.clear();
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
    // NEW: Enter node selection mode on main map
    setState(() {
      _isNodeSelectionMode = true;
      _selectedNodeForAssignment = null;
    });
  }

  // NEW: Step 1 - Node Selection Bottom Sheet
  Future<void> _showNodeSelectionSheet() async {
    String? pickedNodeId;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedNode = pickedNodeId != null
              ? _graphNodes.firstWhere((n) => n.id == pickedNodeId, orElse: () => _graphNodes.first)
              : null;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF132F4C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select a Node',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose an unassigned node to link a location',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Map panel (240px tall)
                Container(
                  height: 240,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1929),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: _mapImageBytes != null && _imageSize != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            panEnabled: true,
                            scaleEnabled: true,
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: GestureDetector(
                              onTapDown: (details) {
                                // Find tapped node
                                final tapPos = details.localPosition;
                                for (var node in _graphNodes) {
                                  final nodePos = Offset(
                                    node.x * _imageSize!.width,
                                    node.y * _imageSize!.height,
                                  );
                                  final distance = (tapPos - nodePos).distance;
                                  
                                  if (distance <= 20) {
                                    // Check if node is already assigned
                                    if (node.isMapped) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Already assigned to "${node.datasetLocation}"',
                                            style: GoogleFonts.inter(color: Colors.white),
                                          ),
                                          backgroundColor: const Color(0xFFFF6D00),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    // Select this node
                                    setModalState(() {
                                      pickedNodeId = node.id;
                                    });
                                    return;
                                  }
                                }
                              },
                              child: Stack(
                                children: [
                                  Image.memory(_mapImageBytes!, fit: BoxFit.contain),
                                  CustomPaint(
                                    size: _imageSize!,
                                    painter: GraphMapPainter(
                                      nodes: _graphNodes,
                                      edges: _graphEdges,
                                      locations: [],
                                      imageSize: _imageSize!,
                                      selectedNodeId: pickedNodeId,
                                      activeMode: null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            'No map available',
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                        ),
                ),
                
                // Instruction text
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tap an unassigned node on the map above',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Selected node indicator
                if (selectedNode != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00C853),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Node selected at (${(selectedNode.x * 100).toStringAsFixed(0)}%, ${(selectedNode.y * 100).toStringAsFixed(0)}%)',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              pickedNodeId = null;
                            });
                          },
                          child: Text(
                            'Change',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF00C853),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const Spacer(),
                
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: pickedNodeId != null
                              ? () {
                                  Navigator.pop(context);
                                  _showLocationNameSelectionSheet(pickedNodeId!);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2979FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Next →',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // NEW: Step 2 - Location Name Selection Bottom Sheet
  Future<void> _showLocationNameSelectionSheet(String nodeId) async {
    final selectedNode = _graphNodes.firstWhere((n) => n.id == nodeId);
    String? selectedLocationName;
    List<Map<String, dynamic>> datasetLocations = [];
    bool isLoading = true;
    String searchQuery = '';
    
    // Fetch dataset locations
    try {
      datasetLocations = await ApiService.getDatasetLocations(_currentFloor);
      isLoading = false;
    } catch (e) {
      print('Error fetching dataset locations: $e');
      isLoading = false;
    }
    
    if (!mounted) return;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filter locations based on search
          final filteredLocations = datasetLocations.where((loc) {
            final name = loc['location'] as String;
            return name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
          
          // Separate assigned and unassigned
          final unassignedLocations = filteredLocations.where((loc) => loc['is_assigned'] == false).toList();
          final assignedLocations = filteredLocations.where((loc) => loc['is_assigned'] == true).toList();
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFF132F4C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Location Name',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Node at (${(selectedNode.x * 100).toStringAsFixed(0)}%, ${(selectedNode.y * 100).toStringAsFixed(0)}%) · Floor $_currentFloor',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search locations...',
                      hintStyle: GoogleFonts.inter(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2979FF)),
                      filled: true,
                      fillColor: const Color(0xFF0A1929),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Location list
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF2979FF)),
                        )
                      : unassignedLocations.isEmpty && assignedLocations.isEmpty
                          ? Center(
                              child: Text(
                                'No dataset locations found for this floor',
                                style: GoogleFonts.inter(color: Colors.white70),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              children: [
                                // Unassigned locations
                                ...unassignedLocations.map((loc) {
                                  final name = loc['location'] as String;
                                  final count = loc['record_count'] as int;
                                  final isSelected = selectedLocationName == name;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF2979FF).withOpacity(0.2)
                                          : const Color(0xFF0A1929),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF2979FF)
                                            : Colors.white.withOpacity(0.1),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        setModalState(() {
                                          selectedLocationName = name;
                                        });
                                      },
                                      leading: Icon(
                                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                                        color: isSelected ? const Color(0xFF2979FF) : Colors.white54,
                                      ),
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BCD4).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$count records',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF00BCD4),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                
                                // Assigned locations (greyed out)
                                if (assignedLocations.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Already Assigned',
                                    style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...assignedLocations.map((loc) {
                                    final name = loc['location'] as String;
                                    final count = loc['record_count'] as int;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A1929).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.05),
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: const Icon(Icons.link, color: Colors.white24),
                                        title: Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            color: Colors.white38,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        trailing: Text(
                                          'Already linked',
                                          style: GoogleFonts.inter(
                                            color: Colors.white24,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ],
                            ),
                ),
                
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showNodeSelectionSheet();
                          },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text(
                            'Back',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: selectedLocationName != null
                              ? () async {
                                  Navigator.pop(context);
                                  await _assignLocationToNode(nodeId, selectedLocationName!);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Assign',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // NEW: Assign location to node and save
  Future<void> _assignLocationToNode(String nodeId, String locationName) async {
    try {
      // Find the node and update its dataset_location
      final nodeIndex = _graphNodes.indexWhere((n) => n.id == nodeId);
      if (nodeIndex == -1) {
        throw Exception('Node not found');
      }
      
      // Update the node
      _graphNodes[nodeIndex] = _graphNodes[nodeIndex].copyWith(
        datasetLocation: locationName,
      );
      
      // Save the updated graph
      final nodesJson = _graphNodes.map((n) => n.toJson()).toList();
      final edgesJson = _graphEdges.map((e) => e.toJson()).toList();
      
      final success = await ApiService.saveWalkableGraph(_currentFloor, nodesJson, edgesJson);
      
      if (success) {
        // Exit node selection mode
        setState(() {
          _isNodeSelectionMode = false;
          _selectedNodeForAssignment = null;
        });
        
        // Reload floor data
        await _loadFloorData();
        
        if (mounted) {
          final node = _graphNodes[nodeIndex];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$locationName assigned to node at (${(node.x * 100).toStringAsFixed(0)}%, ${(node.y * 100).toStringAsFixed(0)}%)',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF00C853),
            ),
          );
        }
      } else {
        throw Exception('Failed to save graph');
      }
    } catch (e) {
      print('Error assigning location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to assign location: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMapTap(Offset localPosition) {
    if (_imageSize == null) return;

    // NEW: Handle node selection mode for Add Location flow
    if (_isNodeSelectionMode) {
      _handleNodeSelection(localPosition);
      return;
    }

    if (_isPlacementMode) {
      _showAddLocationSheet(localPosition);
    } else if (_isMoveMode && _movingLocationId != null) {
      _moveLocation(_movingLocationId!, localPosition);
    } else {
      _selectLocationAtPosition(localPosition);
    }
  }

  // NEW: Handle node selection on main map
  void _handleNodeSelection(Offset position) {
    // Find tapped node within 20px radius
    for (var node in _graphNodes) {
      final nodePos = Offset(
        node.x * _imageSize!.width,
        node.y * _imageSize!.height,
      );
      final distance = (position - nodePos).distance;
      
      if (distance <= 20) {
        // Check if node is already assigned
        if (node.isMapped) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Already assigned to "${node.datasetLocation}"',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFFF6D00),
            ),
          );
          return;
        }
        
        // Node selected - proceed to location name selection
        setState(() {
          _selectedNodeForAssignment = node.id;
        });
        
        // Show location name selection sheet
        _showLocationNameSelectionSheet(node.id);
        return;
      }
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
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location Marking', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
              Text('Mark and edit room positions', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
            ],
          ),
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
          if (_isNodeSelectionMode) _buildNodeSelectionBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
                : isTablet
                    ? Row(children: [Expanded(flex: 6, child: _buildMapPanel()), Expanded(flex: 4, child: _buildListPanel())])
                    : Column(children: [Expanded(flex: 6, child: _buildMapPanel()), Expanded(flex: 4, child: _buildListPanel())]),
          ),
        ],
      ),
      floatingActionButton: _isPlacementMode || _isMoveMode || _isNodeSelectionMode
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

  Widget _buildNodeSelectionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF7C4DFF).withOpacity(0.2),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Color(0xFF7C4DFF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedNodeForAssignment != null
                  ? 'Node selected! Opening location selection...'
                  : 'Tap an unassigned node on the map',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _isNodeSelectionMode = false;
              _selectedNodeForAssignment = null;
            }),
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
            // Show loading indicator while map is loading
            if (_isLoadingMap)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2979FF)),
              )
            // Show empty state if no map exists
            else if (_mapImageBytes == null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'No map uploaded for Floor $_currentFloor',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            // Show map with interactive viewer
            else
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
                      if (_imageSize != null)
                        CustomPaint(
                          size: _imageSize!,
                          painter: LocationMapPainter(
                            locations: _locations,
                            graphNodes: _graphNodes,
                            graphEdges: _graphEdges,
                            imageSize: _imageSize!,
                            selectedLocationId: _selectedLocationId,
                            selectedNodeId: _isNodeSelectionMode ? _selectedNodeForAssignment : null,
                            pulseAnimation: _pulseController,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_selectedLocationId != null && !_isLoadingMap) _buildLocationDetailPeek(),
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

// Custom Painter for Location Map
class LocationMapPainter extends CustomPainter {
  final List<LocationMarker> locations;
  final List<GraphNode> graphNodes;
  final List<GraphEdge> graphEdges;
  final Size imageSize;
  final String? selectedLocationId;
  final String? selectedNodeId; // NEW: For node selection mode
  final Animation<double> pulseAnimation;

  LocationMapPainter({
    required this.locations,
    required this.graphNodes,
    required this.graphEdges,
    required this.imageSize,
    this.selectedLocationId,
    this.selectedNodeId, // NEW
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
    for (var node in graphNodes) {
      final pos = Offset(node.x * imageSize.width, node.y * imageSize.height);
      final isSelectedNode = node.id == selectedNodeId;
      
      if (isSelectedNode) {
        // Highlight selected node with pulsing green circle
        final highlightPaint = Paint()
          ..color = const Color(0xFF00C853).withOpacity(0.3 * pulseAnimation.value)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 20 * pulseAnimation.value, highlightPaint);
        
        // Draw selected node as filled green circle
        final selectedNodePaint = Paint()
          ..color = const Color(0xFF00C853)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 8, selectedNodePaint);
        
        // White border
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(pos, 8, borderPaint);
      } else {
        // Regular node rendering
        final nodePaint = Paint()
          ..color = const Color(0xFF2979FF).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 4, nodePaint);
      }
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
