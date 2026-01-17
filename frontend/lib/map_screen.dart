import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  Map<String, Offset> roomPositions = {};
  String selectedDestination = '';
  String predictedRoom = '';
  String currentFloor = '1';

  late AnimationController _userMarkerController;
  late AnimationController _destMarkerController;

  bool _isTesting = false;
  Timer? _testTimer;
  Map<String, List<Map<String, dynamic>>> _groupedTestData = {};

  // No static baseUrl here, use ApiService.baseUrl

  bool _isLoading = true;
  String? _errorMessage;



  Uint8List? _mapImageBytes;

  Future<void> _fetchMapBytes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final b64 = await ApiService.getMapBase64(currentFloor);
    
    if (b64 != null) {
      try {
         final bytes = base64Decode(b64);
         setState(() {
           _mapImageBytes = bytes;
           _isLoading = false;
         });
      } catch (e) {
        setState(() {
          _errorMessage = "Decoding error: $e";
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = "Failed to download map from backend.";
        _isLoading = false;
      });
    }
  }

  void _initAnimations() {
    _userMarkerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.7,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _destMarkerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.7,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  Future<void> _loadFloorData() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/$currentFloor');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          roomPositions = {
            for (var loc in data)
              loc['name']: Offset(loc['x'].toDouble(), loc['y'].toDouble())
          };
          if (roomPositions.isNotEmpty && predictedRoom.isEmpty) {
            predictedRoom = roomPositions.keys.first;
          }
        });
      }
    } catch (e) {
      print('Error loading floor data: $e');
    }
  }

  Future<void> _fetchAndGroupTestData() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/testdata');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        _groupedTestData = {};
        for (var row in data) {
          final loc = row['Location'] ?? '';
          if (!_groupedTestData.containsKey(loc)) {
            _groupedTestData[loc] = [];
          }
          _groupedTestData[loc]!.add(row);
        }
        Fluttertoast.showToast(msg: 'Test data loaded');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to fetch test data');
    }
  }

  Future<void> _testRandomLocation() async {
    if (_groupedTestData.isEmpty) {
       await _fetchAndGroupTestData();
    }
    if (_groupedTestData.isEmpty) {
      Fluttertoast.showToast(msg: "⚠️ No test data available.");
      return;
    }

    final locations = _groupedTestData.keys.toList();
    final sourceLocName = (locations..shuffle()).first;
    final group = _groupedTestData[sourceLocName]!;
    
    // Process test data to look exactly like a real hardware scan
    List<Map<String, dynamic>> payload = group.map((row) => {
      'BSSID': row['BSSID'],
      'Signal Strength dBm': row['Signal Strength dBm'],
    }).toList();
    
    // Unified API Handshake
    final result = await ApiService.predictLocation(payload);
    
    if (result != null) {
      final String predicted = result['predicted']!;
      final String source = result['source']!;
      String displayedRoom = predicted;
      bool isFallback = false;

      if (!roomPositions.containsKey(displayedRoom)) {
        if (roomPositions.isNotEmpty) {
           displayedRoom = roomPositions.keys.first;
           isFallback = true;
        }
      }

      setState(() {
        predictedRoom = displayedRoom;
      });

      if (roomPositions.containsKey(displayedRoom)) {
         _userMarkerController.forward(from: 0.7);
         _animateToLocation(roomPositions[displayedRoom]!);
      }
      
      String msg = 'Ground Truth: $sourceLocName\nAI Predicted: $predicted';
      
      Fluttertoast.showToast(
        msg: "$msg", 
        toastLength: Toast.LENGTH_LONG, 
        gravity: ToastGravity.BOTTOM, 
        backgroundColor: Colors.indigo,
        textColor: Colors.white
      );
    } else {
      Fluttertoast.showToast(msg: "❌ FAILED: Server unreachable.");
    }
  }

  void _toggleTesting() async {
    if (_isTesting) {
      _testTimer?.cancel();
      setState(() => _isTesting = false);
    } else {
      await _fetchAndGroupTestData();
      if (_groupedTestData.isEmpty) return;
      setState(() => _isTesting = true);
      _testTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _testRandomLocation();
      });
    }
  }

 

  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadFloorData();
    _fetchMapBytes();
    _fetchAllLocations();
    // Fetch test data first so auto-locate simulation works on emulators
    _fetchAndGroupTestData().then((_) {
       Future.delayed(const Duration(seconds: 1), _locateUser);
    });
  }

  Future<void> _locateUser() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    List<Map<String, dynamic>> payload = [];

    // 1. Real Hardware Wi-Fi Scan
    try {
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan == CanStartScan.yes) {
         await WiFiScan.instance.startScan();
         final results = await WiFiScan.instance.getScannedResults();
         if (results.isNotEmpty) {
           payload = results.map((ap) => {
             'BSSID': ap.bssid,
             'Signal Strength dBm': ap.level,
           }).toList();
           print("📡 REAL HARDWARE SCAN: Captured ${payload.length} Access Points");
         }
      }
    } catch (e) {
      print("Scan Error: $e");
    }

    // 2. Terminate if no hardware data
    if (payload.isEmpty) {
      setState(() => _isLocating = false);
      Fluttertoast.showToast(
        msg: "⚠️ No Wi-Fi signals found. Ensure Wi-Fi/Location is ON.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.redAccent
      );
      return;
    }

    // 3. Official Backend Model Prediction
    final result = await ApiService.predictLocation(payload);
    
    setState(() => _isLocating = false);

    if (result != null) {
      final String predicted = result['predicted']!;
      
      setState(() {
        predictedRoom = predicted;
      });
      
      if (roomPositions.containsKey(predicted)) {
        _userMarkerController.forward(from: 0.7);
        _animateToLocation(roomPositions[predicted]!);
      }

      Fluttertoast.showToast(
        msg: "Live Location: $predicted",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.indigo,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(msg: "❌ ERROR: Server prediction failed.");
    }
  }

  final TransformationController _transformationController = TransformationController();

  void _animateToLocation(Offset pos) {
    const double targetScale = 2.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate translation to center the point
    final double transX = (screenWidth / 2) - (pos.dx * targetScale);
    final double transY = (screenHeight / 2) - (pos.dy * targetScale);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(transX, transY)
      ..scale(targetScale);

    _transformationController.value = endMatrix;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _userMarkerController.dispose();
    _destMarkerController.dispose();
    _testTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  List<dynamic> _allLocations = [];

  Future<void> _fetchAllLocations() async {
    final locs = await ApiService.getAllLocations();
    setState(() {
      _allLocations = locs;
    });
  }

  // Reload data when floor changes
  void _changeFloor(String floor) {
    setState(() {
      currentFloor = floor;
      predictedRoom = ''; // Reset prediction
      _mapImageBytes = null; // Clear old map
      roomPositions.clear(); // Clear old markers
    });
    _loadFloorData();
    _fetchMapBytes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          margin: const EdgeInsets.only(top: 40, left: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9), // Glassy but readable
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Floor Selector
                PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text('L$currentFloor', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                      ],
                    ),
                  ),
                  onSelected: _changeFloor,
                  itemBuilder: (context) => ['1', '2', '3'].map((f) => PopupMenuItem(
                    value: f,
                    child: Text('Floor $f'),
                  )).toList(),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textValue) {
                      if (_allLocations.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                      final query = textValue.text.toLowerCase();
                      
                      // Filter
                      final matches = _allLocations.where((loc) {
                        return (loc['name'] as String).toLowerCase().contains(query);
                      }).toList();
                      
                      // Sort: Current floor first
                      matches.sort((a, b) {
                        final aFloor = a['floor']?.toString() ?? '1';
                        final bFloor = b['floor']?.toString() ?? '1';
                        if (aFloor == currentFloor && bFloor != currentFloor) return -1;
                        if (aFloor != currentFloor && bFloor == currentFloor) return 1;
                        return 0;
                      });
                      
                      return matches.cast<Map<String, dynamic>>();
                    },
                    displayStringForOption: (option) => option['name'],
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          child: ConstrainedBox(
                           constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300), 
                           child: ListView.separated(
                             padding: EdgeInsets.zero,
                             shrinkWrap: true,
                             itemCount: options.length,
                             separatorBuilder: (ctx, idx) => const Divider(height: 1),
                             itemBuilder: (BuildContext context, int index) {
                               final option = options.elementAt(index);
                               final floor = option['floor']?.toString() ?? '1';
                               return ListTile(
                                 dense: true,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                 leading: const Icon(Icons.location_on, color: Colors.indigo),
                                 title: Text(option['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                 subtitle: Text('Floor $floor', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                 trailing: Chip(
                                   label: Text(floor, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                   backgroundColor: floor == currentFloor ? Colors.indigo : Colors.grey,
                                   padding: EdgeInsets.zero,
                                   visualDensity: VisualDensity.compact,
                                 ),
                                 onTap: () => onSelected(option),
                               );
                             },
                           ),
                          ),
                        ),
                      );
                    },
                    onSelected: (selection) {
                      final targetFloor = selection['floor']?.toString() ?? '1';
                      if (targetFloor != currentFloor) {
                         _changeFloor(targetFloor);
                         // Delay animation slightly to let map load
                         Future.delayed(const Duration(milliseconds: 500), () {
                            // Find new position for this location name
                            if (roomPositions.containsKey(selection['name'])) {
                               _animateToLocation(roomPositions[selection['name']]!);
                            }
                         });
                      } else {
                         if (roomPositions.containsKey(selection['name'])) {
                            _animateToLocation(roomPositions[selection['name']]!);
                         }
                      }
                      setState(() => selectedDestination = selection['name']);
                      _destMarkerController.forward(from: 0.7);
                    },
                    fieldViewBuilder: (ctx, ctrl, fnode, onSubmit) {
                      return TextField(
                        controller: ctrl,
                        focusNode: fnode,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.black45),
                          prefixIcon: Icon(Icons.search, color: Colors.indigo),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: 1, 
                  height: 24, 
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.indigo),
                  tooltip: "Admin Panel",
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/admin');
                    _loadFloorData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110.0), // Lift buttons above the info card
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: "locate",
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Locate Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              onPressed: () {
                 _locateUser();
                 if (predictedRoom.isNotEmpty && roomPositions.containsKey(predictedRoom)) {
                   _animateToLocation(roomPositions[predictedRoom]!);
                 }
              },
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: "test",
              backgroundColor: _isTesting ? Colors.redAccent : Colors.green, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Icon(_isTesting ? Icons.stop : Icons.play_arrow),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(_isTesting ? 'Stop Test' : 'Test Random', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              onPressed: _toggleTesting,
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF0F2F5), // Light grey background
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.01,
              maxScale: 4.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500), // Allow panning far out
              child: Stack(
                children: [
                  // The Map Image
              // The Map Image
              if (_mapImageBytes != null)
                 Image.memory(
                    _mapImageBytes!,
                    fit: BoxFit.none,
                    errorBuilder: (ctx, err, st) => const Center(child: Text('Failed to perform image render')),
                 )
              else 
                 SizedBox(
                   width: MediaQuery.of(context).size.width,
                   height: MediaQuery.of(context).size.height,
                   child: Center(
                     child: _isLoading 
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(_errorMessage ?? 'Unknown Error', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchMapBytes, 
                                child: const Text('Retry')
                              )
                            ],
                          ),
                   ),
                 ),
                  
                  // User Marker
                  if (predictedRoom.isNotEmpty && roomPositions.containsKey(predictedRoom))
                     AnimatedBuilder(
                        animation: _userMarkerController,
                        builder: (ctx, child) {
                          final pos = roomPositions[predictedRoom]!;
                          return Positioned(
                            left: pos.dx - 24, 
                            top: pos.dy - 48,
                            child: Transform.scale(
                              scale: _userMarkerController.value, 
                              alignment: Alignment.bottomCenter,
                              child: InkWell(
                                onTap: () => Fluttertoast.showToast(msg: "You are here: $predictedRoom"),
                                child: const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 48),
                              ),
                            ),
                          );
                        },
                      ),
                
                  // Destination Marker
                  if (selectedDestination.isNotEmpty && roomPositions.containsKey(selectedDestination))
                     AnimatedBuilder(
                        animation: _destMarkerController,
                        builder: (ctx, child) {
                          final pos = roomPositions[selectedDestination]!;
                          return Positioned(
                            left: pos.dx - 24, 
                            top: pos.dy - 48,
                            child: Transform.scale(
                              scale: _destMarkerController.value,
                              alignment: Alignment.bottomCenter,
                              child: const Icon(Icons.flag, color: Colors.redAccent, size: 48),
                            ),
                          );
                        },
                      ),

                   // Path
                   if (selectedDestination.isNotEmpty && roomPositions.containsKey(predictedRoom) && roomPositions.containsKey(selectedDestination))
                      CustomPaint(
                        size: Size.infinite, 
                        painter: PathPainter(start: roomPositions[predictedRoom]!, end: roomPositions[selectedDestination]!),
                      ),
                ],
              ),
            ),
            
            // Info Card Overlay
            Positioned(
              left: 16, right: 16, bottom: 75, // Lifted for better visibility
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.indigo, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isLocating 
                            ? Row(
                                children: [
                                  const Text('Locating...', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                ],
                              )
                            : Text('Current Location: ${predictedRoom.isEmpty ? 'Unknown' : predictedRoom}', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (selectedDestination.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.flag, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Destination: $selectedDestination', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  PathPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);
    
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    
    final metrics = path.computeMetrics();
    for (var metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}