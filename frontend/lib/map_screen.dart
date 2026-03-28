import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'app_state.dart';
import 'navigation_service.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
  bool _wifiDisabled = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final NavigationService _navigationService = NavigationService();
  List<Offset> _shortestPath = [];

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
          _navigationService.initGraph(roomPositions);
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
    
    List<Map<String, dynamic>> payload = group.map((row) => {
      'BSSID': row['BSSID'],
      'Signal Strength dBm': row['Signal Strength dBm'],
    }).toList();
    
    final result = await ApiService.predictLocation(payload);
    
    if (result != null) {
      final String predicted = result['predicted']!;
      final String source = result['source']!;
      String displayedRoom = predicted;

      if (!roomPositions.containsKey(displayedRoom)) {
        if (roomPositions.isNotEmpty) {
           displayedRoom = roomPositions.keys.first;
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
    _checkWifiStatus();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _wifiDisabled = !results.contains(ConnectivityResult.wifi);
      });
    });
    _fetchAndGroupTestData().then((_) {
       Future.delayed(const Duration(seconds: 1), _locateUser);
    });
  }

  Future<void> _checkWifiStatus() async {
    final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
    setState(() {
      _wifiDisabled = !results.contains(ConnectivityResult.wifi);
    });
  }

  Future<void> _locateUser() async {
    if (_isLocating) return;

    await _checkWifiStatus();
    if (_wifiDisabled) {
      AppSettings.openAppSettings(type: AppSettingsType.wifi);
      return;
    }

    setState(() => _isLocating = true);

    List<Map<String, dynamic>> payload = [];

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
         }
      }
    } catch (e) {
      print("Scan Error: $e");
    }

    if (payload.isEmpty) {
      setState(() => _isLocating = false);
      Fluttertoast.showToast(msg: "⚠️ No Wi-Fi signals found.");
      return;
    }

    final result = await ApiService.predictLocation(payload);
    
    setState(() => _isLocating = false);

    if (result != null) {
      final String predicted = result['predicted']!;
      setState(() => predictedRoom = predicted);
      if (roomPositions.containsKey(predicted)) {
        _userMarkerController.forward(from: 0.7);
        _animateToLocation(roomPositions[predicted]!);
      }
    }
  }

  final TransformationController _transformationController = TransformationController();

  void _animateToLocation(Offset pos) {
    const double targetScale = 2.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    final double transX = (screenWidth / 2) - (pos.dx * targetScale);
    final double transY = (screenHeight / 2) - (pos.dy * targetScale);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(transX, transY)
      ..scale(targetScale);

    _transformationController.value = endMatrix;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
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
    setState(() => _allLocations = locs);
  }

  void _changeFloor(String floor) {
    setState(() {
      currentFloor = floor;
      predictedRoom = '';
      _mapImageBytes = null;
      roomPositions.clear();
      _shortestPath = [];
    });
    _loadFloorData();
    _fetchMapBytes();
  }

  void _handleLogout() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
            color: const Color(0xFF132F4C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  color: const Color(0xFF132F4C),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2979FF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('L$currentFloor', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2979FF))),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF2979FF)),
                      ],
                    ),
                  ),
                  onSelected: _changeFloor,
                  itemBuilder: (context) => ['1', '2', '3'].map((f) => PopupMenuItem(
                    value: f,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Floor $f', style: const TextStyle(color: Colors.white)),
                    ),
                  )).toList(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textValue) {
                      if (_allLocations.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                      final query = textValue.text.toLowerCase();
                      final matches = _allLocations.where((loc) {
                        final name = loc['name'] as String;
                        return name.toLowerCase().contains(query) && roomPositions.containsKey(name);
                      }).toList();
                      matches.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                      return matches.cast<Map<String, dynamic>>();
                    },
                    displayStringForOption: (option) => option['name'],
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF132F4C),
                          child: ConstrainedBox(
                           constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300), 
                           child: ListView.separated(
                             padding: EdgeInsets.zero,
                             shrinkWrap: true,
                             itemCount: options.length,
                             separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                             itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(option['name'], style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                                  subtitle: Text('Floor ${option['floor']}', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
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
                         Future.delayed(const Duration(milliseconds: 500), () {
                            if (roomPositions.containsKey(selection['name'])) {
                               _animateToLocation(roomPositions[selection['name']]!);
                            }
                         });
                      } else {
                         if (roomPositions.containsKey(selection['name'])) {
                            _animateToLocation(roomPositions[selection['name']]!);
                         }
                      }
                      setState(() {
                        selectedDestination = selection['name'];
                        _shortestPath = [];
                      });
                      _destMarkerController.forward(from: 0.7);
                    },
                    fieldViewBuilder: (ctx, ctrl, fnode, onSubmit) {
                      return TextField(
                        controller: ctrl,
                        focusNode: fnode,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search locations...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF2979FF)),
                        ),
                      );
                    },
                  ),
                ),
                if (Provider.of<AppState>(context, listen: false).isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.model_training, color: Color(0xFF7C4DFF)),
                    tooltip: 'WiFi Training Data',
                    onPressed: () => Navigator.pushNamed(context, '/training_data'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Color(0xFF00BCD4)),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/admin_dashboard');
                      _loadFloorData();
                    },
                  ),
                ],
                // User menu with logout
                PopupMenuButton<String>(
                  color: const Color(0xFF132F4C),
                  icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                  itemBuilder: (context) {
                    final appState = Provider.of<AppState>(context, listen: false);
                    return [
                      PopupMenuItem(
                        enabled: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appState.userType, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                              Text(appState.isAdmin ? 'Admin' : 'Student', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        height: 1,
                        enabled: false,
                        child: Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "locate",
              backgroundColor: _wifiDisabled ? Colors.grey : const Color(0xFF2979FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Icon(_wifiDisabled ? Icons.signal_wifi_off : Icons.my_location, color: Colors.white),
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
              backgroundColor: _isTesting ? Colors.redAccent : const Color(0xFF00C853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Icon(_isTesting ? Icons.stop : Icons.play_arrow),
              label: Text(_isTesting ? 'Stop Test' : 'Test Random'),
              onPressed: _toggleTesting,
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF0A1929),
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 4.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              child: Stack(
                children: [
                  if (_mapImageBytes != null)
                    Image.memory(_mapImageBytes!, fit: BoxFit.none)
                  else
                    const SizedBox(width: 2000, height: 2000),
                  
                  // All Marked Locations (Subtle Dots)
                  ...roomPositions.entries.where((e) => e.key != predictedRoom && e.key != selectedDestination).map((entry) {
                    return Positioned(
                      left: entry.value.dx - 4,
                      top: entry.value.dy - 4,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                      ),
                    );
                  }).toList(),

                  if (predictedRoom.isNotEmpty && roomPositions.containsKey(predictedRoom))
                    AnimatedBuilder(
                      animation: _userMarkerController,
                      builder: (ctx, child) {
                        final pos = roomPositions[predictedRoom]!;
                        return Positioned(
                          left: pos.dx - 24, top: pos.dy - 48,
                          child: Transform.scale(scale: _userMarkerController.value, alignment: Alignment.bottomCenter, child: const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 48)),
                        );
                      },
                    ),

                  if (selectedDestination.isNotEmpty && roomPositions.containsKey(selectedDestination))
                    AnimatedBuilder(
                      animation: _destMarkerController,
                      builder: (ctx, child) {
                        final pos = roomPositions[selectedDestination]!;
                        return Positioned(
                          left: pos.dx - 24, top: pos.dy - 48,
                          child: Transform.scale(scale: _destMarkerController.value, alignment: Alignment.bottomCenter, child: const Icon(Icons.flag, color: Colors.redAccent, size: 48)),
                        );
                      },
                    ),

                  if (_shortestPath.isNotEmpty)
                    CustomPaint(size: Size.infinite, painter: PathPainter(_shortestPath))
                  else if (selectedDestination.isNotEmpty && roomPositions.containsKey(predictedRoom) && roomPositions.containsKey(selectedDestination))
                    CustomPaint(size: Size.infinite, painter: SimplePathPainter(start: roomPositions[predictedRoom]!, end: roomPositions[selectedDestination]!)),
                ],
              ),
            ),
            Positioned(
              left: 16, right: 16, bottom: 75,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF2979FF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Current Location: ${predictedRoom.isEmpty ? 'Unknown' : predictedRoom}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
            if (selectedDestination.isNotEmpty) _buildDirectionsBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsBanner() {
    return Positioned(
      bottom: 24, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2979FF).withOpacity(0.2),
                  child: const Icon(Icons.location_on, color: Color(0xFF2979FF)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectedDestination, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text("Floor $currentFloor", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() { selectedDestination = ''; _shortestPath = []; }),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Text("Info"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _getDirections,
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text("Get Directions"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _getDirections() {
    if (predictedRoom.isEmpty || selectedDestination.isEmpty) return;
    _navigationService.initGraph(roomPositions);
    final path = _navigationService.findShortestPath(predictedRoom, selectedDestination);
    if (path.isNotEmpty) {
      setState(() => _shortestPath = path);
      Fluttertoast.showToast(msg: "Calculating shortest route...", backgroundColor: Colors.indigo, textColor: Colors.white);
    } else {
      Fluttertoast.showToast(msg: "No path found between locations");
    }
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> points;
  PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = Colors.indigo..strokeWidth = 6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final shadowPaint = Paint()..color = Colors.indigo.withOpacity(0.3)..strokeWidth = 10..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, shadowPaint);
    const dashWidth = 8.0, dashSpace = 4.0;
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

class SimplePathPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  SimplePathPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.5)..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
    final metrics = path.computeMetrics();
    for (var metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + 5);
        canvas.drawPath(extract, paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}