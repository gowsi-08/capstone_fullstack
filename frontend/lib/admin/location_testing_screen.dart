import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api_service.dart';
import '../models/graph_models.dart';

class LocationTestingScreen extends StatefulWidget {
  const LocationTestingScreen({Key? key}) : super(key: key);

  @override
  State<LocationTestingScreen> createState() => _LocationTestingScreenState();
}

class _LocationTestingScreenState extends State<LocationTestingScreen> {
  String _mode = 'wifi'; // 'wifi' or 'gps'
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;
  
  // Map display
  int? _resultFloor;
  Uint8List? _mapImageBytes;
  Size? _imageSize;
  List<GraphNode> _graphNodes = [];
  List<GraphEdge> _graphEdges = [];
  
  // WiFi data
  List<WiFiAccessPoint> _wifiNetworks = [];
  
  // GPS data
  Position? _currentPosition;

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
                'Location Testing',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Text(
                'Test WiFi or GPS location prediction',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildModeToggle(),
          if (_testResult != null) ...[
            Expanded(child: _buildResultMap()),
            _buildResultPanel(),
          ] else ...[
            Expanded(child: _buildInstructionPanel()),
          ],
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = 'wifi';
                _testResult = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _mode == 'wifi' ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _mode == 'wifi' ? const Color(0xFF2979FF) : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi,
                      color: _mode == 'wifi' ? Colors.white : Colors.white60,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WiFi Model',
                      style: GoogleFonts.inter(
                        color: _mode == 'wifi' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = 'gps';
                _testResult = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _mode == 'gps' ? const Color(0xFF00C853) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _mode == 'gps' ? const Color(0xFF00C853) : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: _mode == 'gps' ? Colors.white : Colors.white60,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GPS Model',
                      style: GoogleFonts.inter(
                        color: _mode == 'gps' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionPanel() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _mode == 'wifi' ? Icons.wifi_tethering : Icons.my_location,
              size: 64,
              color: _mode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853),
            ),
            const SizedBox(height: 24),
            Text(
              _mode == 'wifi' ? 'WiFi Location Testing' : 'GPS Location Testing',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _mode == 'wifi'
                  ? 'Scan nearby WiFi networks and predict your location using the trained ML model'
                  : 'Get your GPS coordinates and find the nearest mapped node',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works:',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_mode == 'wifi') ...[
                    _buildStep('1', 'Scan WiFi networks'),
                    _buildStep('2', 'Send to ML model'),
                    _buildStep('3', 'Get predicted location'),
                    _buildStep('4', 'Show on map'),
                  ] else ...[
                    _buildStep('1', 'Get GPS coordinates'),
                    _buildStep('2', 'Find nearest node'),
                    _buildStep('3', 'Calculate distance'),
                    _buildStep('4', 'Show on map'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _mode == 'wifi' 
                  ? const Color(0xFF2979FF).withOpacity(0.2)
                  : const Color(0xFF00C853).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  color: _mode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultMap() {
    if (_mapImageBytes == null || _imageSize == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(1000),
          child: Stack(
            children: [
              Image.memory(_mapImageBytes!, fit: BoxFit.none),
              CustomPaint(
                size: _imageSize!,
                painter: LocationTestMapPainter(
                  nodes: _graphNodes,
                  edges: _graphEdges,
                  imageSize: _imageSize!,
                  highlightNodeId: _testResult?['node_id'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final result = _testResult!;
    final location = result['predicted_location'] ?? 'Unknown';
    final floor = result['floor'] ?? '?';
    final distance = result['distance_meters'];
    final confidence = result['confidence'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: _mode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predicted Location',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      location,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.layers, 'Floor $floor'),
              const SizedBox(width: 8),
              if (distance != null)
                _buildInfoChip(Icons.straighten, '${distance}m away'),
              const SizedBox(width: 8),
              _buildInfoChip(
                _mode == 'wifi' ? Icons.model_training : Icons.gps_fixed,
                confidence == 'model_based' ? 'ML Model' : 'GPS Based',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          if (_testResult != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _testResult = null),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Test Again',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_testResult != null) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _testLocation,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _mode == 'wifi' ? Icons.wifi_find : Icons.my_location,
                      size: 18,
                    ),
              label: Text(
                _isTesting
                    ? 'Testing...'
                    : _mode == 'wifi'
                        ? 'Test WiFi Location'
                        : 'Test GPS Location',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853),
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
    );
  }

  Future<void> _testLocation() async {
    setState(() => _isTesting = true);

    try {
      if (_mode == 'wifi') {
        await _testWiFiLocation();
      } else {
        await _testGPSLocation();
      }
    } catch (e) {
      _showSnackBar('❌ Error: $e', Colors.red);
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _testWiFiLocation() async {
    // Check WiFi permission
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _showSnackBar('❌ Location permission required for WiFi scanning', Colors.red);
        return;
      }
    }

    // Scan WiFi networks
    _showSnackBar('📡 Scanning WiFi networks...', const Color(0xFF2979FF));
    
    final canStartScan = await WiFiScan.instance.canStartScan();
    if (canStartScan == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 3));
    }

    final networks = await WiFiScan.instance.getScannedResults();
    
    if (networks.isEmpty) {
      _showSnackBar('❌ No WiFi networks found', Colors.red);
      return;
    }

    _wifiNetworks = networks;
    print('📡 Found ${networks.length} WiFi networks');

    // Prepare WiFi data for API
    final wifiData = networks.map((ap) => {
      'BSSID': ap.bssid,
      'rssi': ap.level,
    }).toList();

    // Send to server
    final response = await ApiService.testLocation(
      mode: 'wifi',
      wifiData: wifiData,
    );

    if (response != null && response['error'] == null) {
      await _loadMapForResult(response);
      setState(() => _testResult = response);
      _showSnackBar('✅ Location predicted successfully', const Color(0xFF00C853));
    } else {
      _showSnackBar('❌ ${response?['error'] ?? 'Prediction failed'}', Colors.red);
    }
  }

  Future<void> _testGPSLocation() async {
    // Check GPS permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('❌ Location permissions denied', Colors.red);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('❌ Location permissions permanently denied', Colors.red);
      return;
    }

    // Get GPS location
    _showSnackBar('📍 Getting GPS location...', const Color(0xFF00C853));
    
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentPosition = position;
    print('📍 GPS: ${position.latitude}, ${position.longitude}');

    // Send to server
    final response = await ApiService.testLocation(
      mode: 'gps',
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (response != null && response['error'] == null) {
      await _loadMapForResult(response);
      setState(() => _testResult = response);
      _showSnackBar('✅ Nearest node found', const Color(0xFF00C853));
    } else {
      _showSnackBar('❌ ${response?['error'] ?? 'No GPS nodes found'}', Colors.red);
    }
  }

  Future<void> _loadMapForResult(Map<String, dynamic> result) async {
    final floor = result['floor'];
    if (floor == null) return;

    setState(() => _resultFloor = floor);

    // Load map image
    final b64 = await ApiService.getMapBase64(floor.toString());
    if (b64 != null) {
      final bytes = base64Decode(b64);
      setState(() => _mapImageBytes = bytes);
      _calculateImageSize(bytes);
    }

    // Load graph
    final graphData = await ApiService.getWalkableGraph(floor);
    if (graphData != null && graphData['exists'] == true) {
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Custom Painter for Location Test Map
class LocationTestMapPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Size imageSize;
  final String? highlightNodeId;

  LocationTestMapPainter({
    required this.nodes,
    required this.edges,
    required this.imageSize,
    this.highlightNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = const Color(0xFF2979FF).withOpacity(0.15)
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
      final isHighlighted = node.id == highlightNodeId;

      if (isHighlighted) {
        // Highlighted node: Large pulsing circle with glow
        final glowPaint = Paint()
          ..color = const Color(0xFFFF6D00).withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 30, glowPaint);

        final highlightPaint = Paint()
          ..color = const Color(0xFFFF6D00)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 12, highlightPaint);

        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(pos, 12, borderPaint);

        // Draw pin icon
        final pinPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 4, pinPaint);
      } else {
        // Regular node: Small gray circle
        final nodePaint = Paint()
          ..color = Colors.white.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 3, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
