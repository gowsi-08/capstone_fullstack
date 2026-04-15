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
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
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
  
  // NEW: Node references for navigation
  NavigableLocation? _defaultNode;  // Default fallback node for current floor
  NavigableLocation? _predictedNode;  // Node for current predicted location
  NavigableLocation? _selectedDestinationNode;  // Node for selected destination

  late AnimationController _userMarkerController;
  late AnimationController _destMarkerController;
  late AnimationController _pathAnimationController;

  bool _isTesting = false;
  Timer? _testTimer;
  
  // NEW: Continuous location tracking
  Timer? _locationTrackingTimer;
  bool _isTrackingLocation = false;
  bool _isLocating = false;
  String _cachedLocationMode = 'wifi'; // Cached to avoid server call every tick
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
      // Load navigable nodes for current floor
      final nodes = await ApiService.getNavigableNodes(int.parse(currentFloor));
      setState(() {
        _navigableLocations = nodes.map((node) => NavigableLocation(
          locationName: node.locationName,
          nodeId: node.nodeId,
          x: node.x,
          y: node.y,
          floor: node.floor,
          recordCount: node.recordCount,
        )).toList();
      });
      print('📍 Loaded ${_navigableLocations.length} navigable locations for floor $currentFloor');
      
      // Load default node for current floor
      await _loadDefaultNode();
    } catch (e) {
      print('Error loading floor data: $e');
    }
  }

  Future<void> _loadDefaultNode() async {
    try {
      final defaultNode = await ApiService.getDefaultNode(int.parse(currentFloor));
      if (defaultNode != null) {
        setState(() {
          _defaultNode = NavigableLocation(
            locationName: 'Default',
            nodeId: defaultNode.nodeId,
            x: defaultNode.x,
            y: defaultNode.y,
            floor: defaultNode.floor,
            recordCount: 0,
          );
        });
        print('🎯 Loaded default node for floor $currentFloor');
      } else {
        setState(() => _defaultNode = null);
        print('⚠️ No default node set for floor $currentFloor');
      }
    } catch (e) {
      print('Error loading default node: $e');
      setState(() => _defaultNode = null);
    }
  }

  Future<void> _loadAllNavigableLocations() async {
    try {
      // Load navigable nodes across all floors for search
      final nodes = await ApiService.getAllNavigableNodes();
      setState(() {
        _allNavigableLocations = nodes.map((node) => NavigableLocation(
          locationName: node.locationName,
          nodeId: node.nodeId,
          x: node.x,
          y: node.y,
          floor: node.floor,
          recordCount: node.recordCount,
        )).toList();
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
        
        // Set predicted node if navigable
        if (isNavigable && nodeX != null && nodeY != null) {
          _predictedNode = _navigableLocations.firstWhere(
            (loc) => loc.locationName == predicted,
            orElse: () => NavigableLocation(
              locationName: predicted,
              nodeId: '',
              x: nodeX,
              y: nodeY,
              floor: int.parse(currentFloor),
              recordCount: 0,
            ),
          );
        } else {
          _predictedNode = null;
        }
      });

      if (isNavigable && nodeX != null && nodeY != null && _imageSize != null) {
        final pixelPos = Offset(nodeX * _imageSize!.width, nodeY * _imageSize!.height);
        _userMarkerController.forward(from: 0.7);
        _animateToLocation(pixelPos);
      } else if (!isNavigable && _defaultNode != null && _imageSize != null) {
        // Use default node position for unmapped locations
        final pixelPos = _defaultNode!.toPixelOffset(_imageSize!);
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadFloorData();
    _loadAllNavigableLocations();
    _fetchMapBytes();
    _checkWifiStatus();
    _refreshLocationMode(); // Cache location mode early
    _checkAndEnsureModelTrained(); // Check model status and retrain if needed
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

  Future<void> _checkAndEnsureModelTrained() async {
    try {
      print('🔍 Checking model training status...');
      final stats = await ApiService.getTrainingStats();
      
      if (stats == null) {
        print('⚠️ Could not fetch training stats');
        return;
      }
      
      final totalRows = stats['total_rows'] ?? 0;
      final totalLocations = stats['total_locations'] ?? 0;
      
      print('📊 Training data: $totalRows rows, $totalLocations locations');
      
      // Check if model needs training (no data or model not trained)
      if (totalRows == 0) {
        print('⚠️ No training data available');
        Fluttertoast.showToast(
          msg: "⚠️ No training data. Please collect WiFi data first.",
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
      
      // Always trigger retrain on app start to ensure model is up-to-date
      print('🔄 Triggering model retrain to ensure latest data...');
      Fluttertoast.showToast(
        msg: "🔄 Updating location model...",
        backgroundColor: const Color(0xFF2979FF),
        toastLength: Toast.LENGTH_SHORT,
      );
      
      final success = await ApiService.triggerRetrain();
      
      if (success) {
        print('✅ Model retrain triggered successfully');
        // Wait a bit for the model to retrain
        await Future.delayed(const Duration(seconds: 3));
        Fluttertoast.showToast(
          msg: "✅ Location model ready",
          backgroundColor: const Color(0xFF00C853),
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        print('❌ Failed to trigger model retrain');
        Fluttertoast.showToast(
          msg: "⚠️ Could not update model. Predictions may be inaccurate.",
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      print('❌ Error checking model status: $e');
    }
  }

  /// Refresh the cached location mode from server (call once, not every tick)
  Future<void> _refreshLocationMode() async {
    try {
      _cachedLocationMode = await ApiService.getLocationMode();
      print('📡 Location mode refreshed: $_cachedLocationMode');
    } catch (e) {
      print('⚠️ Failed to refresh location mode, using cached: $_cachedLocationMode');
    }
  }

  Future<void> _locateUser() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      if (_cachedLocationMode == 'gps') {
        await _locateUserGPS();
      } else {
        await _locateUserWiFi();
      }
    } finally {
      // Ensure _isLocating is always reset even if an exception occurs
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _locateUserGPS() async {
    try {
      // Check GPS permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!_isTrackingLocation) {
            Fluttertoast.showToast(
              msg: "⚠️ Location permissions denied",
              backgroundColor: Colors.red,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_isTrackingLocation) {
          Fluttertoast.showToast(
            msg: "⚠️ Location permissions permanently denied",
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      // Get GPS location with timeout to prevent blocking tracking
      print('📍 Getting GPS location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('GPS timeout - took too long'),
      );

      print('📍 GPS: ${position.latitude}, ${position.longitude}');

      final gpsPayload = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      final result = await ApiService.predictLocationGPS(gpsPayload);

      if (result == null) {
        print('❌ GPS prediction returned null - no GPS nodes available, falling back to WiFi');
        
        if (!_isTrackingLocation) {
          Fluttertoast.showToast(
            msg: "⚠️ No GPS nodes mapped. Falling back to WiFi...",
            backgroundColor: Colors.orange,
            toastLength: Toast.LENGTH_SHORT,
          );
        }
        // Always fallback to WiFi when GPS returns no result (both manual and tracking)
        await _locateUserWiFi();
        return;
      }

      final String predicted = result['predicted']!;
      final bool isNavigable = result['is_navigable'] ?? false;
      // Safely cast node_x/node_y to double (JSON may return int)
      final double? nodeX = (result['node_x'] as num?)?.toDouble();
      final double? nodeY = (result['node_y'] as num?)?.toDouble();
      final int? floor = result['floor'] is int 
          ? result['floor'] 
          : int.tryParse(result['floor']?.toString() ?? '');
      final double? distance = (result['distance_meters'] as num?)?.toDouble();

      print('📍 GPS location: $predicted (${distance}m away, navigable: $isNavigable)');

      // Handle floor change
      if (floor != null && floor.toString() != currentFloor) {
        setState(() => currentFloor = floor.toString());
        await _loadFloorData();
        await _fetchMapBytes(); // Also reload the map image for the new floor
      }

      if (nodeX != null && nodeY != null && mounted) {
        setState(() {
          predictedRoom = predicted;
          _currentNodeX = nodeX;
          _currentNodeY = nodeY;
          _isNavigable = isNavigable;
        });

        // Animate/update marker for BOTH tracking and manual modes
        if (_imageSize != null) {
          final pixelPos = Offset(nodeX * _imageSize!.width, nodeY * _imageSize!.height);
          _userMarkerController.forward(from: 0.7);
          
          // Only pan/zoom the map on first manual locate, not during tracking
          if (!_isTrackingLocation) {
            _animateToLocation(pixelPos);
          }
        }

        if (!_isTrackingLocation) {
          Fluttertoast.showToast(
            msg: "📍 You are at: $predicted",
            backgroundColor: const Color(0xFF00C853),
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } catch (e) {
      print('❌ GPS location error: $e');
      if (!_isTrackingLocation) {
        Fluttertoast.showToast(
          msg: "⚠️ GPS error: $e",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _locateUserWiFi() async {
    await _checkWifiStatus();
    if (_wifiDisabled) {
      if (!_isTrackingLocation) {
        AppSettings.openAppSettings(type: AppSettingsType.wifi);
      }
      return;
    }

    List<Map<String, dynamic>> payload = [];

    try {
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan == CanStartScan.yes) {
         await WiFiScan.instance.startScan();
         await Future.delayed(const Duration(milliseconds: 1500));
         final results = await WiFiScan.instance.getScannedResults();
         if (results.isNotEmpty) {
           payload = results.map((ap) => {
             'BSSID': ap.bssid,
             'Signal Strength dBm': ap.level,
           }).toList();
           print('📡 WiFi scan found ${results.length} access points');
         } else {
           print('⚠️ WiFi scan returned 0 results');
         }
      } else {
        print('⚠️ Cannot start WiFi scan: $canScan');
        if (!_isTrackingLocation) {
          Fluttertoast.showToast(
            msg: "⚠️ WiFi scanning not available. Check permissions and WiFi.",
            backgroundColor: Colors.orange,
          );
        }
        return;
      }
    } catch (e) {
      print("❌ Scan Error: $e");
      if (!_isTrackingLocation) {
        Fluttertoast.showToast(
          msg: "⚠️ WiFi scan error: $e",
          backgroundColor: Colors.orange,
        );
      }
      return;
    }

    if (payload.isEmpty) {
      if (!_isTrackingLocation) {
        Fluttertoast.showToast(
          msg: "⚠️ No Wi-Fi signals found. Make sure WiFi is enabled and nearby.",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.orange,
        );
      }
      return;
    }

    print('📤 Sending ${payload.length} WiFi signals to server for prediction');
    final result = await ApiService.predictLocation(payload);

    if (result == null) {
      print('❌ predictLocation returned null - server error or network issue');
      if (!_isTrackingLocation) {
        Fluttertoast.showToast(
          msg: "⚠️ Could not predict location. Check server connection.",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    // Check if model needs retraining
    if (result.containsKey('error') && result['error'] == 'model_retrain_needed') {
      print('❌ Model needs retraining - feature mismatch');
      if (!_isTrackingLocation) {
        Fluttertoast.showToast(
          msg: "⚠️ Model needs retraining. Contact admin to retrain the model.",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.orange,
        );
      }
      return;
    }

    final String predicted = result['predicted']!;
    final bool isNavigable = result['is_navigable'] ?? false;
    // Safely cast to double (JSON may return int)
    final double? nodeX = (result['node_x'] as num?)?.toDouble();
    final double? nodeY = (result['node_y'] as num?)?.toDouble();
    final int? floor = result['floor'] is int 
        ? result['floor'] 
        : int.tryParse(result['floor']?.toString() ?? '');
    
    print('📍 Location predicted: $predicted (navigable: $isNavigable)');
    
    if (!mounted) return;
    
    setState(() {
      predictedRoom = predicted;
      _isNavigable = isNavigable;
      _currentNodeX = nodeX;
      _currentNodeY = nodeY;
    });
    
    // Update marker animation for both tracking and manual modes
    if (isNavigable && nodeX != null && nodeY != null && _imageSize != null) {
      final pixelPos = Offset(nodeX * _imageSize!.width, nodeY * _imageSize!.height);
      _userMarkerController.forward(from: 0.7);
      if (!_isTrackingLocation) {
        _animateToLocation(pixelPos);
      }
    } else if (!isNavigable && _defaultNode != null && _imageSize != null) {
      final pixelPos = _defaultNode!.toPixelOffset(_imageSize!);
      _userMarkerController.forward(from: 0.7);
      if (!_isTrackingLocation) {
        _animateToLocation(pixelPos);
      }
    }
  }

  void _startLocationTracking() async {
    if (_isTrackingLocation) return;
    
    // Refresh location mode once when tracking starts (not every tick)
    await _refreshLocationMode();
    
    setState(() => _isTrackingLocation = true);
    
    // Initial scan
    _locateUser();
    
    // Tracking interval: scan every 1 second for real-time tracking
    const trackingInterval = Duration(seconds: 1);
    
    _locationTrackingTimer = Timer.periodic(trackingInterval, (timer) {
      _locateUser();
    });
    
    Fluttertoast.showToast(
      msg: "📍 Live tracking started (${_cachedLocationMode.toUpperCase()} mode)",
      backgroundColor: const Color(0xFF00C853),
    );
  }

  void _stopLocationTracking() {
    if (!_isTrackingLocation) return;
    
    _locationTrackingTimer?.cancel();
    _locationTrackingTimer = null;
    
    setState(() => _isTrackingLocation = false);
    
    Fluttertoast.showToast(
      msg: "Location tracking stopped",
      backgroundColor: Colors.grey,
    );
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
    _pathAnimationController.dispose();
    _testTimer?.cancel();
    _locationTrackingTimer?.cancel();
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
    // Stop any active tracking before navigating away
    _stopLocationTracking();
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
                      // Dismiss keyboard and close suggestions
                      FocusScope.of(context).unfocus();
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
                      // Stop tracking while in admin screens to prevent background calls
                      final wasTracking = _isTrackingLocation;
                      if (wasTracking) _stopLocationTracking();
                      
                      await Navigator.pushNamed(context, '/admin_dashboard');
                      
                      // Refresh data when coming back from admin
                      _loadFloorData();
                      _fetchMapBytes();
                      await _refreshLocationMode();
                      
                      // Resume tracking if it was active before
                      if (wasTracking) _startLocationTracking();
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
        padding: const EdgeInsets.only(bottom: 90.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "locate",
              backgroundColor: _wifiDisabled 
                ? Colors.grey 
                : (_isTrackingLocation ? const Color(0xFF00C853) : const Color(0xFF2979FF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Icon(
                _wifiDisabled 
                  ? Icons.signal_wifi_off 
                  : (_isTrackingLocation ? Icons.gps_fixed : Icons.my_location), 
                color: Colors.white
              ),
              onPressed: () {
                if (_isTrackingLocation) {
                  _stopLocationTracking();
                } else {
                  _startLocationTracking();
                }
              },
            ),
            // const SizedBox(height: 16),
            // FloatingActionButton.extended(
            //   heroTag: "test",
            //   backgroundColor: _isTesting ? Colors.redAccent : const Color(0xFF00C853),
            //   foregroundColor: Colors.white,
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            //   icon: Icon(_isTesting ? Icons.stop : Icons.play_arrow),
            //   label: Text(_isTesting ? 'Stop Test' : 'Test Random'),
            //   onPressed: _toggleTesting,
            // ),
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
                  
                  // All Navigable Locations (Professional Markers)
                  if (_imageSize != null)
                    ..._navigableLocations.where((loc) => loc.locationName != predictedRoom && loc.locationName != selectedDestination).map((loc) {
                      final pixelPos = loc.toPixelOffset(_imageSize!);
                      return Positioned(
                        left: pixelPos.dx - 12,
                        top: pixelPos.dy - 24,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDestination = loc.locationName;
                              _shortestPath = [];
                            });
                            _destMarkerController.forward(from: 0.7);
                            _animateToLocation(pixelPos);
                          },
                          child: CustomPaint(
                            size: const Size(24, 24),
                            painter: LocationMarkerPainter(
                              color: const Color(0xFF7C4DFF),
                              isSelected: false,
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                  // Current Location Marker (Blue Person Pin)
                  // Shows at node position if navigable, or at default node if not navigable
                  if (predictedRoom.isNotEmpty && _imageSize != null)
                    Builder(
                      builder: (context) {
                        Offset? markerPos;
                        bool isApproximate = false;
                        
                        if (_isNavigable && _currentNodeX != null && _currentNodeY != null) {
                          // Navigable: show at actual node position
                          markerPos = Offset(_currentNodeX! * _imageSize!.width, _currentNodeY! * _imageSize!.height);
                        } else if (_currentNodeX != null && _currentNodeY != null) {
                          // GPS returned a valid node but it has no dataset_location (corridor node)
                          // Still show marker at the node's position
                          markerPos = Offset(_currentNodeX! * _imageSize!.width, _currentNodeY! * _imageSize!.height);
                          isApproximate = true;
                        } else if (_defaultNode != null) {
                          // Fallback: show at default node position
                          markerPos = _defaultNode!.toPixelOffset(_imageSize!);
                          isApproximate = true;
                        }
                        
                        if (markerPos == null) return const SizedBox.shrink();
                        
                        return AnimatedBuilder(
                          animation: _userMarkerController,
                          builder: (ctx, child) {
                            return Positioned(
                              left: markerPos!.dx - 24,
                              top: markerPos.dy - 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Dashed circle ring for approximate position
                                  if (isApproximate)
                                    CustomPaint(
                                      size: const Size(48, 48),
                                      painter: DashedCirclePainter(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                        radius: 20,
                                      ),
                                    ),
                                  // Person pin icon
                                  Transform.scale(
                                    scale: _userMarkerController.value,
                                    alignment: Alignment.bottomCenter,
                                    child: const Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.blueAccent,
                                      size: 48,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
            
            // Current Location Text Card (always visible)
            Positioned(
              left: 16,
              right: 16,
              bottom: selectedDestination.isEmpty ? 50 : 50, // Adjust based on directions banner
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      predictedRoom.isEmpty 
                        ? Icons.location_searching
                        : (_isNavigable ? Icons.location_on : Icons.warning_amber_rounded),
                      color: predictedRoom.isEmpty
                        ? Colors.white54
                        : (_isNavigable ? const Color(0xFF2979FF) : const Color(0xFFFF6D00)),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            color: predictedRoom.isEmpty 
                              ? Colors.white54 
                              : (_isNavigable ? Colors.white : Colors.white70),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: predictedRoom.isEmpty
                                ? 'Current Location:  '
                                : (_isNavigable ? 'You are at:  ' : 'Predicted:  '),
                            ),
                            TextSpan(
                              text: predictedRoom.isEmpty
                                ? 'Not detected yet'
                                : (_isNavigable ? predictedRoom : '$predictedRoom (not on map)'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontStyle: predictedRoom.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isTrackingLocation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00C853), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C853),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF00C853),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // OLD: Current Location Info Card (kept for compatibility, can be removed)
            if (false && predictedRoom.isNotEmpty)
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
                // Expanded(
                //   child: OutlinedButton(
                //     onPressed: () {},
                //     style: OutlinedButton.styleFrom(
                //       foregroundColor: Colors.white,
                //       side: BorderSide(color: Colors.white.withOpacity(0.3)),
                //     ),
                //     child: const Text("Info"),
                //   ),
                // ),
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
    if (selectedDestination.isEmpty) return;
    
    // Show dialog to select "From" location
    await _showFromLocationDialog();
  }

  Future<void> _showFromLocationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132F4C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.navigation, color: Color(0xFF2979FF), size: 24),
            const SizedBox(width: 12),
            Text(
              'Choose Starting Point',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current Location option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.my_location, color: Color(0xFF2979FF), size: 24),
              ),
              title: Text(
                'Current Location',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                predictedRoom.isNotEmpty ? predictedRoom : 'Scan WiFi to detect',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'current'),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 8),
            // Other locations option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on, color: Color(0xFF00BCD4), size: 24),
              ),
              title: Text(
                'Choose Location',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Select from available locations',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
        ],
      ),
    );

    if (result == 'current') {
      // Use current location - scan WiFi if not already done
      await _useCurrentLocationForNavigation();
    } else if (result == 'choose') {
      // Show location picker
      await _showLocationPicker();
    }
  }

  Future<void> _useCurrentLocationForNavigation() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text('Scanning WiFi...', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
          backgroundColor: const Color(0xFF2979FF),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Scan WiFi and predict location
    await _locateUser();
    
    // Wait a moment for the prediction to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Now calculate route
    if (predictedRoom.isNotEmpty) {
      await _calculateRoute(predictedRoom, selectedDestination);
    } else {
      Fluttertoast.showToast(
        msg: "Could not detect your location. Please try again.",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _showLocationPicker() async {
    final selectedLocation = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132F4C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Starting Location',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _navigableLocations.length,
            itemBuilder: (context, index) {
              final location = _navigableLocations[index];
              return ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF7C4DFF)),
                title: Text(
                  location.locationName,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Floor ${location.floor}',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, location.locationName),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
        ],
      ),
    );

    if (selectedLocation != null) {
      await _calculateRoute(selectedLocation, selectedDestination);
    }
  }

  Future<void> _calculateRoute(String fromLocation, String toLocation) async {
    try {
      // Call graph-based pathfinding API
      final uri = Uri.parse('${ApiService.baseUrl}/navigation/path');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'floor': int.parse(currentFloor),
          'from_location': fromLocation,
          'to_location': toLocation,
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


// Dashed Circle Painter for approximate position indicator
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    const totalDashes = 24;

    for (int i = 0; i < totalDashes; i++) {
      final startAngle = (i * 2 * 3.14159265359 / totalDashes);
      final sweepAngle = (dashWidth / (2 * 3.14159265359 * radius));

      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
        );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Professional Location Marker Painter
class LocationMarkerPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  LocationMarkerPainter({
    required this.color,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    final shadowPath = Path();
    shadowPath.moveTo(center.dx, size.height - 2);
    shadowPath.lineTo(center.dx - 4, size.height - 8);
    shadowPath.lineTo(center.dx + 4, size.height - 8);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Outer glow for selected state
    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(center.dx, center.dy - 4), 8, glowPaint);
    }
    
    // Main pin body (teardrop shape)
    final pinPath = Path();
    final pinTop = center.dy - 16;
    final pinRadius = 6.0;
    
    // Circle at top
    pinPath.addOval(Rect.fromCircle(
      center: Offset(center.dx, pinTop + pinRadius),
      radius: pinRadius,
    ));
    
    // Triangle pointing down
    pinPath.moveTo(center.dx - pinRadius * 0.5, pinTop + pinRadius * 2);
    pinPath.lineTo(center.dx, size.height - 4);
    pinPath.lineTo(center.dx + pinRadius * 0.5, pinTop + pinRadius * 2);
    pinPath.close();
    
    // Draw pin with gradient effect
    final pinPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          color.withOpacity(0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(pinPath, pinPaint);
    
    // White border around pin
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pinPath, borderPaint);
    
    // Inner dot (white center)
    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, pinTop + pinRadius), 2.5, innerDotPaint);
    
    // Pulsing ring for selected state
    if (isSelected) {
      final ringPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(center.dx, pinTop + pinRadius), 9, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LocationMarkerPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected || oldDelegate.color != color;
  }
}
