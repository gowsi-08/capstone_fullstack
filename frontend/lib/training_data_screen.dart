import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class TrainingDataScreen extends StatefulWidget {
  const TrainingDataScreen({Key? key}) : super(key: key);
  @override
  State<TrainingDataScreen> createState() => _TrainingDataScreenState();
}

class _TrainingDataScreenState extends State<TrainingDataScreen> {
  // ─── Controllers ───
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();

  // ─── Location Data ───
  List<Map<String, dynamic>> _trainingLocations = [];
  List<Map<String, dynamic>> _mapLocations = [];
  Map<String, dynamic>? _selectedExisting;
  bool _isNewLocation = true;
  String _selectedFloor = '1';

  // ─── Map ───
  Uint8List? _mapImageBytes;
  double _imageWidth = 1;
  double _imageHeight = 1;
  Offset? _newMarkerPosition;
  bool _showMap = false;
  bool _locationOnMap = false;
  bool _skipMapMarking = false;

  // ─── WiFi Scan ───
  List<Map<String, dynamic>> _scannedNetworks = [];
  List<bool> _selectedScans = [];
  bool _isScanning = false;
  bool _isSubmitting = false;

  // ─── Stats ───
  Map<String, dynamic>? _trainingStats;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _loadTrainingStats();
    _loadTrainingLocations();
    _loadMapForFloor(_selectedFloor);
  }

  Future<void> _loadTrainingStats() async {
    final stats = await ApiService.getTrainingStats();
    if (mounted) setState(() => _trainingStats = stats);
  }

  Future<void> _loadTrainingLocations() async {
    final locs = await ApiService.getTrainingLocations();
    if (mounted) setState(() => _trainingLocations = locs);
  }

  Future<void> _loadMapForFloor(String floor) async {
    final b64 = await ApiService.getMapBase64(floor);
    if (b64 != null) {
      final bytes = base64Decode(b64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _mapImageBytes = bytes;
          _imageWidth = frame.image.width.toDouble();
          _imageHeight = frame.image.height.toDouble();
        });
      }
      frame.image.dispose();
      codec.dispose();
    }
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/$floor');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _mapLocations = data.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      print('Error loading map locations: $e');
    }
    _checkLocationOnMap();
  }

  void _checkLocationOnMap() {
    final name = _locationController.text.trim();
    if (name.isEmpty) return;
    final found = _mapLocations.any(
      (loc) => loc['name'].toString().toLowerCase() == name.toLowerCase(),
    );
    setState(() {
      _locationOnMap = found;
      if (found) {
        _skipMapMarking = false;
        final loc = _mapLocations.firstWhere(
          (l) => l['name'].toString().toLowerCase() == name.toLowerCase(),
        );
        _newMarkerPosition = Offset(
          (loc['x'] as num).toDouble(),
          (loc['y'] as num).toDouble(),
        );
      }
    });
  }

  void _onLocationSelected(Map<String, dynamic> location) {
    setState(() {
      _selectedExisting = location;
      _isNewLocation = false;
      _locationController.text = location['name'];
      _landmarkController.text = location['landmark'] ?? '';
      _skipMapMarking = false;
      _newMarkerPosition = null;
    });
    _checkLocationOnMap();
  }

  void _onClearLocation() {
    setState(() {
      _selectedExisting = null;
      _isNewLocation = true;
      _locationOnMap = false;
      _skipMapMarking = false;
      _newMarkerPosition = null;
      _locationController.clear();
      _landmarkController.clear();
    });
  }

  // ─── WiFi Scan ───
  Future<void> _scanWifi() async {
    setState(() => _isScanning = true);
    try {
      var perm = await Permission.location.request();
      if (!perm.isGranted) {
        Fluttertoast.showToast(msg: '⚠️ Location permission required');
        setState(() => _isScanning = false);
        return;
      }
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        Fluttertoast.showToast(msg: '⚠️ Cannot scan. Enable location & WiFi.');
        setState(() => _isScanning = false);
        return;
      }
      await WiFiScan.instance.startScan();
      final results = await WiFiScan.instance.getScannedResults();
      if (results.isEmpty) {
        Fluttertoast.showToast(msg: '⚠️ No WiFi networks found');
        setState(() => _isScanning = false);
        return;
      }
      final networks = results.map((ap) {
        double dist = _estimateDistance(ap.level, ap.frequency);
        return {
          'ssid': ap.ssid.isNotEmpty ? ap.ssid : 'Hidden',
          'bssid': ap.bssid,
          'frequency': ap.frequency,
          'bandwidth': ap.channelWidth ?? 20,
          'signal_strength': ap.level,
          'estimated_distance': double.parse(dist.toStringAsFixed(2)),
          'capabilities': ap.capabilities,
        };
      }).toList();
      networks.sort((a, b) => (b['signal_strength'] as int).compareTo(a['signal_strength'] as int));
      setState(() {
        _scannedNetworks = networks;
        _selectedScans = List.generate(networks.length, (_) => true);
        _isScanning = false;
      });
      Fluttertoast.showToast(
        msg: '✅ Found ${networks.length} networks',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ Scan failed: $e');
      setState(() => _isScanning = false);
    }
  }

  double _estimateDistance(int signalDbm, int freqMhz) {
    double exp = (27.55 - (20 * log(freqMhz.toDouble()) / ln10) + signalDbm.abs().toDouble()) / 20.0;
    return pow(10, exp).toDouble();
  }

  // ─── Submit ───
  Future<void> _submitData() async {
    final location = _locationController.text.trim();
    final landmark = _landmarkController.text.trim();
    if (location.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Please enter a location name');
      return;
    }
    if (_scannedNetworks.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Please scan WiFi first');
      return;
    }
    final selectedScans = <Map<String, dynamic>>[];
    for (int i = 0; i < _scannedNetworks.length; i++) {
      if (_selectedScans[i]) selectedScans.add(_scannedNetworks[i]);
    }
    if (selectedScans.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Select at least one network');
      return;
    }
    setState(() => _isSubmitting = true);

    // Save map marker if new position was set
    if (_newMarkerPosition != null && !_locationOnMap && !_skipMapMarking) {
      await ApiService.addMapLocation(
        name: location,
        floor: _selectedFloor,
        x: _newMarkerPosition!.dx,
        y: _newMarkerPosition!.dy,
      );
    }

    final result = await ApiService.submitTrainingData(
      location: location,
      landmark: landmark,
      floor: _selectedFloor,
      scans: selectedScans,
    );
    setState(() => _isSubmitting = false);

    if (result != null && result['success'] == true) {
      Fluttertoast.showToast(
        msg: '✅ ${result['message']}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      _loadTrainingStats();
      _loadTrainingLocations();
      _loadMapForFloor(_selectedFloor);
      setState(() {
        _scannedNetworks = [];
        _selectedScans = [];
        _onClearLocation();
        _showMap = false;
      });
    } else {
      Fluttertoast.showToast(
        msg: '❌ Failed to submit training data',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Training Data', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadInitialData),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8EAF6), Color(0xFFF5F5F5)],
          ),
        ),
        child: Column(
          children: [
            if (_trainingStats != null) _buildStatsBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildLocationSection(),
                    const SizedBox(height: 12),
                    _buildMapPromptOrStatus(),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _showMap ? _buildMapSection() : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _buildScanSection(),
                    if (_scannedNetworks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildNetworkList(),
                      const SizedBox(height: 16),
                      _buildSubmitButton(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats Bar ───
  Widget _buildStatsBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF303F9F), Color(0xFF1A237E)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Samples', '${_trainingStats!["total_rows"] ?? 0}', Icons.dataset),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem('Locations', '${_trainingStats!["total_locations"] ?? 0}', Icons.location_on),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem('BSSIDs', '${_trainingStats!["total_bssids"] ?? 0}', Icons.wifi),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  // ─── Section Header ───
  Widget _sectionHeader(String title, IconData icon, int step) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: Colors.indigo[700], size: 20),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  STEP 1: LOCATION SELECTION
  // ═══════════════════════════════════════
  Widget _buildLocationSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Select Location', Icons.edit_location_alt, 1),
            const SizedBox(height: 16),

            // ── Autocomplete Location Dropdown ──
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textValue) {
                if (_trainingLocations.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                final query = textValue.text.toLowerCase();
                if (query.isEmpty) return _trainingLocations;
                return _trainingLocations.where(
                  (loc) => loc['name'].toString().toLowerCase().contains(query),
                );
              },
              displayStringForOption: (option) => option['name'] ?? '',
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final opt = options.elementAt(index);
                          final isOnMap = _mapLocations.any(
                            (m) => m['name'].toString().toLowerCase() == opt['name'].toString().toLowerCase(),
                          );
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isOnMap ? Colors.green[50] : Colors.orange[50],
                              child: Icon(
                                isOnMap ? Icons.check_circle : Icons.warning_amber,
                                color: isOnMap ? Colors.green : Colors.orange,
                                size: 18,
                              ),
                            ),
                            title: Text(opt['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${opt['sample_count']} samples • ${isOnMap ? "On map" : "Not on map"}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: _onLocationSelected,
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                // Sync the internal autocomplete controller with ours
                _locationController.text = ctrl.text;
                ctrl.addListener(() {
                  if (_locationController.text != ctrl.text) {
                    _locationController.text = ctrl.text;
                    if (_selectedExisting != null && ctrl.text != _selectedExisting!['name']) {
                      setState(() {
                        _selectedExisting = null;
                        _isNewLocation = true;
                        _locationOnMap = false;
                      });
                    }
                  }
                });
                return TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'Search or enter new location...',
                    prefixIcon: const Icon(Icons.room, color: Colors.indigo),
                    suffixIcon: ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              ctrl.clear();
                              _onClearLocation();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // ── Selected location info chip ──
            if (_selectedExisting != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.indigo[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Existing location • ${_selectedExisting!['sample_count']} samples collected',
                        style: TextStyle(fontSize: 12, color: Colors.indigo[700]),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Landmark ──
            TextField(
              controller: _landmarkController,
              decoration: InputDecoration(
                labelText: 'Nearby Landmark',
                hintText: 'e.g. near HOD cabin',
                prefixIcon: const Icon(Icons.place, color: Colors.indigo),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),

            const SizedBox(height: 12),

            // ── Floor Selector ──
            Row(
              children: [
                Icon(Icons.layers, color: Colors.indigo[400], size: 20),
                const SizedBox(width: 8),
                Text('Floor:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '1', label: Text('Ground')),
                      ButtonSegment(value: '2', label: Text('First')),
                      ButtonSegment(value: '3', label: Text('Second')),
                    ],
                    selected: {_selectedFloor},
                    onSelectionChanged: (val) {
                      setState(() => _selectedFloor = val.first);
                      _loadMapForFloor(_selectedFloor);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected) ? Colors.indigo : Colors.grey[100];
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected) ? Colors.white : Colors.grey[700];
                      }),
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

  // ═══════════════════════════════════════
  //  MAP PROMPT / STATUS
  // ═══════════════════════════════════════
  Widget _buildMapPromptOrStatus() {
    final locName = _locationController.text.trim();
    if (locName.isEmpty) return const SizedBox.shrink();

    if (_locationOnMap) {
      // Already marked on map
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"$locName" is marked on the map',
                style: TextStyle(color: Colors.green[800], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showMap = !_showMap),
              child: Text(_showMap ? 'Hide' : 'View', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (_skipMapMarking) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.not_interested, color: Colors.grey[500], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Map marking skipped', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
            TextButton(
              onPressed: () => setState(() {
                _skipMapMarking = false;
                _showMap = true;
              }),
              child: const Text('Mark Now', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Not on map — prompt
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"$locName" is not marked on the map',
                  style: TextStyle(color: Colors.orange[900], fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _showMap = true;
                    _skipMapMarking = false;
                  }),
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: const Text('Mark on Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _skipMapMarking = true;
                    _showMap = false;
                  }),
                  icon: const Icon(Icons.not_interested, size: 18),
                  label: const Text('Not Necessary'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  MAP SECTION
  // ═══════════════════════════════════════
  Widget _buildMapSection() {
    if (_mapImageBytes == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.indigo[50],
            child: Row(
              children: [
                Icon(Icons.map, color: Colors.indigo[700], size: 20),
                const SizedBox(width: 8),
                Text('Tap on map to mark location',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo[700], fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showMap = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Map
          LayoutBuilder(builder: (context, constraints) {
            final containerWidth = constraints.maxWidth;
            final aspectRatio = _imageWidth / _imageHeight;
            final containerHeight = (containerWidth / aspectRatio).clamp(200.0, 400.0);
            final scaleX = containerWidth / _imageWidth;
            final scaleY = containerHeight / _imageHeight;
            final scale = scaleX < scaleY ? scaleX : scaleY;
            final renderedW = _imageWidth * scale;
            final renderedH = _imageHeight * scale;
            final offsetX = (containerWidth - renderedW) / 2;
            final offsetY = (containerHeight - renderedH) / 2;

            return GestureDetector(
              onTapUp: (details) {
                final lx = details.localPosition.dx - offsetX;
                final ly = details.localPosition.dy - offsetY;
                if (lx < 0 || ly < 0 || lx > renderedW || ly > renderedH) return;
                final imgX = lx / scale;
                final imgY = ly / scale;
                setState(() {
                  _newMarkerPosition = Offset(imgX, imgY);
                  _locationOnMap = false; // it's a new/moved marker
                });
              },
              child: SizedBox(
                width: containerWidth,
                height: containerHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: offsetX,
                      top: offsetY,
                      child: Image.memory(_mapImageBytes!, width: renderedW, height: renderedH, fit: BoxFit.fill),
                    ),
                    // Existing markers (small dots)
                    for (var loc in _mapLocations)
                      Positioned(
                        left: offsetX + (loc['x'] as num).toDouble() * scale - 5,
                        top: offsetY + (loc['y'] as num).toDouble() * scale - 5,
                        child: Tooltip(
                          message: loc['name'],
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    // New marker (big pin)
                    if (_newMarkerPosition != null)
                      Positioned(
                        left: offsetX + _newMarkerPosition!.dx * scale - 16,
                        top: offsetY + _newMarkerPosition!.dy * scale - 36,
                        child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 36),
                      ),
                  ],
                ),
              ),
            );
          }),
          // Marker info
          if (_newMarkerPosition != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green[50],
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Marker placed at (${_newMarkerPosition!.dx.toInt()}, ${_newMarkerPosition!.dy.toInt()})',
                    style: TextStyle(color: Colors.green[800], fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  STEP 2: WIFI SCAN
  // ═══════════════════════════════════════
  Widget _buildScanSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Scan WiFi Networks', Icons.wifi_find, 2),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanWifi,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.wifi_find, color: Colors.white),
                label: Text(
                  _isScanning ? 'Scanning...' : 'Start WiFi Scan',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Network List ───
  Widget _buildNetworkList() {
    final selectedCount = _selectedScans.where((s) => s).length;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.wifi, color: Colors.indigo[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  '$selectedCount / ${_scannedNetworks.length} selected',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[700], fontSize: 13),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedScans = List.generate(_scannedNetworks.length, (_) => true)),
                  child: const Text('All', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedScans = List.generate(_scannedNetworks.length, (_) => false)),
                  child: const Text('None', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scannedNetworks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final net = _scannedNetworks[index];
              final signal = net['signal_strength'] as int;
              return CheckboxListTile(
                dense: true,
                value: _selectedScans[index],
                onChanged: (val) => setState(() => _selectedScans[index] = val ?? false),
                secondary: _signalIcon(signal),
                title: Text(net['ssid'] ?? 'Hidden', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(
                  '${net['bssid']} • ${signal}dBm • ${net['frequency']}MHz',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Submit Button ───
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitData,
        icon: _isSubmitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload, color: Colors.white),
        label: Text(
          _isSubmitting ? 'Submitting & Retraining...' : 'Submit Data & Retrain Model',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }

  // ─── Signal Icon ───
  Widget _signalIcon(int signal) {
    IconData icon;
    Color color;
    if (signal > -50) {
      icon = Icons.signal_wifi_4_bar; color = Colors.green;
    } else if (signal > -60) {
      icon = Icons.network_wifi_3_bar; color = Colors.lightGreen;
    } else if (signal > -70) {
      icon = Icons.network_wifi_2_bar; color = Colors.orange;
    } else if (signal > -80) {
      icon = Icons.network_wifi_1_bar; color = Colors.deepOrange;
    } else {
      icon = Icons.signal_wifi_0_bar; color = Colors.red;
    }
    return Icon(icon, color: color, size: 26);
  }
}
