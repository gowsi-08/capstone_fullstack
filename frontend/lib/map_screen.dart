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
import 'models/graph_models.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  // NEW: Navigable locations (dataset-mapped nodes)
  List<NavigableLocation> _navigableLocations = [];
  List<NavigableLocation> _allNavigableLocations = [];
  
  String selectedDestination = '';
  String predictedRoom = '';
  String currentFloor = '1';
  
  // NEW: Current location info from WiFi prediction
  bool _isNavigable = false;
  double? _currentNodeX;
  double? _currentNodeY;

  late AnimationController _userMarkerController;
  late AnimationController _destMarkerController;
  late AnimationController _pathAnimationController;

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
  Size? _imageSize;

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
         _calculateImageSize(bytes);
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

    _pathAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _loadFloorData() async {
    try {
      // Load navigable locations for current floor
      final locationsData = await ApiService.getNavigableLocations(int.parse(currentFloor));
      setState(() {
        _navigableLocations = locationsData
            .map((data) => NavigableLocation.fromJson(data))
            .toList();
      });
      print('📍 Loaded ${_navigableLocations.length} navigable locations for floor $currentFloor');
    } catch (e) {
      print('Error loading floor data: $e');
    }
  }

  Future<void> _loadAllNavigableLocations() async {
    try {
      // Load navigable locations across all floors for search
      final locationsData = await ApiService.getAllNavigableLocations();
      setState(() {
        _allNavigableLocations = locationsData
            .map((data) => NavigableLocation.fromJson(data))
            .toList();
      });
      print('📍 Loaded ${_allNavigableLocations.length} navigable locations across all floors');
    } catch (e) {
      print('Error loading all navigable locations: $e');
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
      final bool isNavigable = result['is_navigable'] ?? false;
      final double? nodeX = result['node_x'];
      final double? nodeY = result['node_y'];
      
      setState(() {
        predictedRoom = predicted;
        _isNavigable = isNavigable;
        _currentNodeX = nodeX;
        _currentNodeY = nodeY;
      });

      if (isNavigable && nodeX != null && nodeY != null && _imageSize != null) {
        final pixelPos = Offset(nodeX * _imageSize!.width, nodeY * _imageSize!.height);
        _userMarkerController.forward(from: 0.7);
        _animateToLocation(pixelPos);
      }
      
      String msg = 'Ground Truth: $sourceLocName\nAI Predicted: $predicted\n${isNavigable ? "✓ Navigable" : "⚠ Not mapped"}';
      
      Fluttertoast.showToast(
        msg: "$msg", 
        toastLength: Toast.LENGTH_LONG, 
        gravity: ToastGravity.BOTTOM, 
        backgroundColor: isNavigable ? Colors.indigo : Colors.orange,
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
    _loadAllNavigableLocations();
    _fetchMapBytes();
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
      final bool isNavigable = result['is_navigable'] ?? false;
      final double? nodeX = result['node_x'];
      final double? nodeY = result['node_y'];
      final int? floor = result['floor'];
      
      setState(() {
        predictedRoom = predicted;
        _isNavigable = isNavigable;
        _currentNodeX = nodeX;
        _currentNodeY = nodeY;
      });
      
      if (isNavigable && nodeX != null && nodeY != null && _imageSize != null) {
        // Animate to the graph node position
        final pixelPos = Offset(nodeX * _imageSize!.width, nodeY * _imageSize!.height);
        _userMarkerController.forward(from: 0.7);
        _animateToLocation(pixelPos);
      } else {
        // Location not mapped - show warning
        print('⚠️ Location "$predicted" is not mapped to navigation graph');
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
  }    _transformationController.value = endMatrix;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _searchController.dispose();
    _userMarkerController.dispose();
    _destMarkerController.dispose();
    _pathAnimationController.dispose();
    _testTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void _changeFloor(String floor) {
    setState(() {
      currentFloor = floor;
      predictedRoom = '';
      _mapImageBytes = null;
      _navigableLocations.clear();
      _shortestPath = [];
      _isNavigable = false;
      _currentNodeX = null;
      _currentNodeY = null;
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
                  child: Autocomplete<NavigableLocation>(
                    optionsBuilder: (textValue) {
                      if (_allNavigableLocations.isEmpty) return const Iterable<NavigableLocation>.empty();
                      final query = textValue.text.toLowerCase();
                      final matches = _allNavigableLocations.where((loc) {
                        return loc.locationName.toLowerCase().contains(query);
                      }).toList();
                      matches.sort((a, b) => a.locationName.compareTo(b.locationName));
                      return matches;
                    },
                    displayStringForOption: (option) => option.locationName,
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF132F4C),
                          child: ConstrainedBox(
                           constraints: const BoxConstraints(maxHeight: 300, maxWidth: 350), 
                           child: ListView.separated(
                             padding: EdgeInsets.zero,
                             shrinkWrap: true,
                             itemCount: options.length,
                             separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                             itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    option.locationName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2979FF).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF2979FF), width: 1),
                                        ),
                                        child: Text(
                                          'Floor ${option.floor}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF2979FF), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${option.recordCount} records',
                                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                      ),
                                    ],
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
                      final targetFloor = selection.floor.toString();
                      if (targetFloor != currentFloor) {
                         _changeFloor(targetFloor);
                         Future.delayed(const Duration(milliseconds: 500), () {
                            if (_imageSize != null) {
                               final pixelPos = selection.toPixelOffset(_imageSize!);
                               _animateToLocation(pixelPos);
                            }
                         });
                      } else {
                         if (_imageSize != null) {
                            final pixelPos = selection.toPixelOffset(_imageSize!);
                            _animateToLocation(pixelPos);
                         }
                      }
                      setState(() {
                        selectedDestination = selection.locationName;
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
                          hintText: 'Search navigable locations...',
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
                 if (_isNavigable && _currentNodeX != null && _currentNodeY != null && _imageSize != null) {
                   final pixelPos = Offset(_currentNodeX! * _imageSize!.width, _currentNodeY! * _imageSize!.height);
                   _animateToLocation(pixelPos);
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
                  
                  // All Navigable Locations (Purple Dots)
                  if (_imageSize != null)
                    ..._navigableLocations.where((loc) => loc.locationName != predictedRoom && loc.locationName != selectedDestination).map((loc) {
                      final pixelPos = loc.toPixelOffset(_imageSize!);
                      return Positioned(
                        left: pixelPos.dx - 4,
                        top: pixelPos.dy - 4,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF).withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                          ),
                        ),
                      );
                    }).toList(),

                  // Current Location Marker (Blue Person Pin)
                  if (_isNavigable && _currentNodeX != null && _currentNodeY != null && _imageSize != null)
                    AnimatedBuilder(
                      animation: _userMarkerController,
                      builder: (ctx, child) {
                        final pos = Offset(_currentNodeX! * _imageSize!.width, _currentNodeY! * _imageSize!.height);
                        return Positioned(
                          left: pos.dx - 24, top: pos.dy - 48,
                          child: Transform.scale(scale: _userMarkerController.value, alignment: Alignment.bottomCenter, child: const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 48)),
                        );
                      },
                    ),

                  // Destination Marker (Red Flag)
                  if (selectedDestination.isNotEmpty && _imageSize != null)
                    Builder(
                      builder: (context) {
                        final destLocation = _navigableLocations.firstWhere(
                          (loc) => loc.locationName == selectedDestination,
                          orElse: () => _allNavigableLocations.firstWhere(
                            (loc) => loc.locationName == selectedDestination,
                            orElse: () => NavigableLocation(locationName: '', nodeId: '', x: 0, y: 0, floor: 0, recordCount: 0),
                          ),
                        );
                        if (destLocation.nodeId.isEmpty) return const SizedBox.shrink();
                        
                        return AnimatedBuilder(
                          animation: _destMarkerController,
                          builder: (ctx, child) {
                            final pos = destLocation.toPixelOffset(_imageSize!);
                            return Positioned(
                              left: pos.dx - 24, top: pos.dy - 48,
                              child: Transform.scale(scale: _destMarkerController.value, alignment: Alignment.bottomCenter, child: const Icon(Icons.flag, color: Colors.redAccent, size: 48)),
                            );
                          },
                        );
                      },
                    ),

                  // Animated Path
                  if (_shortestPath.isNotEmpty)
                    CustomPaint(size: Size.infinite, painter: AnimatedPathPainter(_shortestPath, _pathAnimationController)),
                ],
              ),
            ),
            // Current Location Info Card
            if (predictedRoom.isNotEmpty)
              Positioned(
                left: 16, right: 16, bottom: selectedDestination.isEmpty ? 24 : 140,
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
                      Expanded(
                        child: Text(
                          'Current: $predictedRoom',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isNavigable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00C853), width: 1),
                          ),
                          child: const Text(
                            'Navigable',
                            style: TextStyle(fontSize: 11, color: Color(0xFF00C853), fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6D00).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFF6D00), width: 1),
                              ),
                              child: const Text(
                                'Not mapped',
                                style: TextStyle(fontSize: 11, color: Color(0xFFFF6D00), fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF132F4C),
                                    title: const Text('Location Not Mapped', style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                      'This location was predicted but has no position on the map. The admin needs to assign this location to a graph node in Floor Plan Management.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK', style: TextStyle(color: Color(0xFF2979FF))),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Icon(Icons.info_outline, color: const Color(0xFFFF6D00).withOpacity(0.8), size: 18),
                            ),
                          ],
                        ),
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

  Future<void> _getDirections() async {
    // Check if current location is set
    if (predictedRoom.isEmpty) {
      Fluttertoast.showToast(
        msg: "Scan WiFi first to detect your location",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    
    if (selectedDestination.isEmpty) return;
    
    try {
      // Call graph-based pathfinding API
      final uri = Uri.parse('${ApiService.baseUrl}/navigation/path');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'floor': int.parse(currentFloor),
          'from_location': predictedRoom,
          'to_location': selectedDestination,
        }),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        
        if (data['found'] == true) {
          // Path found - convert and display
          if (_imageSize != null) {
            // Convert normalized coordinates to pixel coordinates
            final pathNodes = (data['path_nodes'] as List).map((n) {
              return Offset(
                n['x'] * _imageSize!.width,
                n['y'] * _imageSize!.height,
              );
            }).toList();
            
            setState(() => _shortestPath = pathNodes);
            
            // Animate the path
            _pathAnimationController.reset();
            _pathAnimationController.forward();
            
            final seconds = data['estimated_seconds'] ?? 0;
            final minutes = (seconds / 60).ceil();
            
            Fluttertoast.showToast(
              msg: "Route found! Estimated time: ${minutes}min",
              backgroundColor: const Color(0xFF00C853),
              textColor: Colors.white,
            );
          }
        } else {
          // No path found - check reason
          setState(() => _shortestPath = []);
          final reason = data['reason'] ?? '';
          
          if (reason == 'location_not_mapped') {
            Fluttertoast.showToast(
              msg: "One or more locations are not mapped to the navigation graph. Ask admin to assign nodes.",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          } else {
            Fluttertoast.showToast(
              msg: "No walkable path found between these locations.",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          }
        }
      } else {
        // API error
        Fluttertoast.showToast(
          msg: "Failed to calculate route. Please try again.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Pathfinding error: $e');
      Fluttertoast.showToast(
        msg: "Failed to calculate route: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }    }
  }
}

// Animated Path Painter with progressive drawing
class AnimatedPathPainter extends CustomPainter {
  final List<Offset> points;
  final Animation<double> animation;

  AnimatedPathPainter(this.points, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Create the full path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final pathMetrics = path.computeMetrics().first;
    final totalLength = pathMetrics.length;
    final currentLength = totalLength * animation.value;

    // Draw the animated path segment
    final extractedPath = pathMetrics.extractPath(0, currentLength);

    // Shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF00BCD4).withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(extractedPath, shadowPaint);

    // Main path line (teal)
    final pathPaint = Paint()
      ..color = const Color(0xFF00BCD4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(extractedPath, pathPaint);

    // Draw waypoint dots at intermediate nodes (only for completed segments)
    for (int i = 1; i < points.length - 1; i++) {
      final pointDistance = _calculatePathDistance(points.sublist(0, i + 1));
      if (pointDistance <= currentLength) {
        final dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 4, dotPaint);
        
        // Dot border
        final borderPaint = Paint()
          ..color = const Color(0xFF00BCD4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(points[i], 4, borderPaint);
      }
    }

    // Draw "you are here" marker at start (blue dot with radiating circle)
    if (animation.value > 0) {
      final startPaint = Paint()..color = const Color(0xFF2979FF)..style = PaintingStyle.fill;
      canvas.drawCircle(points[0], 8, startPaint);
      
      // Radiating circle
      final radiatingPaint = Paint()
        ..color = const Color(0xFF2979FF).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(points[0], 12 + (animation.value * 4), radiatingPaint);
    }

    // Draw destination marker (pulsing green circle with location pin)
    if (animation.value >= 1.0 && points.isNotEmpty) {
      final destPoint = points.last;
      
      // Pulsing circle
      final pulseValue = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
      final pulseRadius = 16 + (pulseValue * 8);
      final pulsePaint = Paint()
        ..color = const Color(0xFF00C853).withOpacity(0.3 - (pulseValue * 0.2))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(destPoint, pulseRadius, pulsePaint);
      
      // Solid circle
      final destPaint = Paint()..color = const Color(0xFF00C853)..style = PaintingStyle.fill;
      canvas.drawCircle(destPoint, 12, destPaint);
      
      // White center
      final centerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      canvas.drawCircle(destPoint, 6, centerPaint);
    }
  }

  double _calculatePathDistance(List<Offset> pathPoints) {
    double distance = 0;
    for (int i = 1; i < pathPoints.length; i++) {
      distance += (pathPoints[i] - pathPoints[i - 1]).distance;
    }
    return distance;
  }

  @override
  bool shouldRepaint(covariant AnimatedPathPainter oldDelegate) => true;
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