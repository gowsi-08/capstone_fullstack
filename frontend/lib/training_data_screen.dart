import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'api_service.dart';

class TrainingDataScreen extends StatefulWidget {
  const TrainingDataScreen({Key? key}) : super(key: key);

  @override
  State<TrainingDataScreen> createState() => _TrainingDataScreenState();
}

class _TrainingDataScreenState extends State<TrainingDataScreen> {
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _floorController = TextEditingController(text: 'ground floor');

  List<Map<String, dynamic>> _scannedNetworks = [];
  bool _isScanning = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _trainingStats;

  // Track which scans are selected for submission
  List<bool> _selectedScans = [];

  @override
  void initState() {
    super.initState();
    _loadTrainingStats();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _landmarkController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainingStats() async {
    final stats = await ApiService.getTrainingStats();
    if (mounted) {
      setState(() => _trainingStats = stats);
    }
  }

  Future<void> _scanWifi() async {
    setState(() => _isScanning = true);

    try {
      // Request permissions
      var locPermission = await Permission.location.request();
      if (!locPermission.isGranted) {
        if (mounted) {
          Fluttertoast.showToast(msg: '⚠️ Location permission is required for WiFi scan');
        }
        setState(() => _isScanning = false);
        return;
      }

      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        Fluttertoast.showToast(msg: '⚠️ Cannot start WiFi scan. Enable location & WiFi.');
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

      // Convert scan results to our format
      final networks = results.map((ap) {
        // Estimate distance from signal strength using the log-distance path loss model
        double estimatedDistance = _estimateDistance(ap.level, ap.frequency);

        return {
          'ssid': ap.ssid.isNotEmpty ? ap.ssid : 'Hidden',
          'bssid': ap.bssid,
          'frequency': ap.frequency,
          'bandwidth': ap.channelWidth ?? 20,
          'signal_strength': ap.level,
          'estimated_distance': double.parse(estimatedDistance.toStringAsFixed(2)),
          'capabilities': ap.capabilities,
          'selected': true,
        };
      }).toList();

      // Sort by signal strength (strongest first)
      networks.sort((a, b) => (b['signal_strength'] as int).compareTo(a['signal_strength'] as int));

      setState(() {
        _scannedNetworks = networks;
        _selectedScans = List.generate(networks.length, (_) => true);
        _isScanning = false;
      });

      Fluttertoast.showToast(
        msg: '✅ Found ${networks.length} WiFi networks',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Scan error: $e');
      Fluttertoast.showToast(msg: '❌ Scan failed: $e');
      setState(() => _isScanning = false);
    }
  }

  double _estimateDistance(int signalStrengthDbm, int frequencyMhz) {
    // Free-space path loss model
    double exp = (27.55 - (20 * log(frequencyMhz.toDouble()) / ln10) + signalStrengthDbm.abs().toDouble()) / 20.0;
    return pow(10, exp).toDouble();
  }

  Future<void> _submitData() async {
    final location = _locationController.text.trim();
    final landmark = _landmarkController.text.trim();
    final floor = _floorController.text.trim();

    if (location.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Please enter a location name');
      return;
    }

    if (_scannedNetworks.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Please scan WiFi first');
      return;
    }

    // Filter only selected scans
    final selectedScans = <Map<String, dynamic>>[];
    for (int i = 0; i < _scannedNetworks.length; i++) {
      if (_selectedScans[i]) {
        final scan = Map<String, dynamic>.from(_scannedNetworks[i]);
        scan.remove('selected');
        selectedScans.add(scan);
      }
    }

    if (selectedScans.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Select at least one WiFi network');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService.submitTrainingData(
      location: location,
      landmark: landmark,
      floor: floor,
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
      // Refresh stats
      _loadTrainingStats();
      // Clear scanned data for next entry
      setState(() {
        _scannedNetworks = [];
        _selectedScans = [];
      });
    } else {
      Fluttertoast.showToast(
        msg: '❌ Failed to submit training data',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _selectAll(bool select) {
    setState(() {
      _selectedScans = List.generate(_scannedNetworks.length, (_) => select);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Training Data'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: _loadTrainingStats,
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: Column(
          children: [
            // Stats Banner
            if (_trainingStats != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.indigo, Colors.indigoAccent],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Samples', '${_trainingStats!["total_rows"] ?? 0}', Icons.dataset),
                    _statItem('Locations', '${_trainingStats!["total_locations"] ?? 0}', Icons.location_on),
                    _statItem('BSSIDs', '${_trainingStats!["total_bssids"] ?? 0}', Icons.wifi),
                  ],
                ),
              ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Details Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.edit_location_alt, color: Colors.indigo[700]),
                                const SizedBox(width: 8),
                                Text('Location Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: 'Location Name *',
                                hintText: 'e.g. cse department office',
                                prefixIcon: const Icon(Icons.room),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _landmarkController,
                              decoration: InputDecoration(
                                labelText: 'Nearby Landmark',
                                hintText: 'e.g. near hod cabin',
                                prefixIcon: const Icon(Icons.place),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _floorController,
                              decoration: InputDecoration(
                                labelText: 'Floor',
                                hintText: 'e.g. ground floor, second',
                                prefixIcon: const Icon(Icons.layers),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Scan Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanWifi,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.wifi_find, color: Colors.white),
                        label: Text(
                          _isScanning ? 'Scanning...' : 'Scan WiFi Networks',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Scanned Networks
                    if (_scannedNetworks.isNotEmpty) ...[
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.wifi, color: Colors.indigo[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Found ${_scannedNetworks.length} Networks',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[700]),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    icon: const Icon(Icons.select_all, size: 16),
                                    label: const Text('All'),
                                    onPressed: () => _selectAll(true),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.deselect, size: 16),
                                    label: const Text('None'),
                                    onPressed: () => _selectAll(false),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Network List
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _scannedNetworks.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final network = _scannedNetworks[index];
                                final signal = network['signal_strength'] as int;
                                final signalPercent = ((signal + 100) / 70 * 100).clamp(0, 100).toInt();

                                return CheckboxListTile(
                                  dense: true,
                                  value: _selectedScans[index],
                                  onChanged: (val) {
                                    setState(() => _selectedScans[index] = val ?? false);
                                  },
                                  secondary: _signalIcon(signal),
                                  title: Text(
                                    network['ssid'] ?? 'Hidden',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BSSID: ${network['bssid']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                      Text(
                                        '${network['frequency']}MHz | ${signal}dBm ($signalPercent%) | ~${network['estimated_distance']}m',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitData,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload, color: Colors.white),
                          label: Text(
                            _isSubmitting
                                ? 'Submitting & Retraining...'
                                : 'Submit Data & Retrain Model',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                          ),
                        ),
                      ),
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

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _signalIcon(int signal) {
    IconData icon;
    Color color;

    if (signal > -50) {
      icon = Icons.signal_wifi_4_bar;
      color = Colors.green;
    } else if (signal > -60) {
      icon = Icons.network_wifi_3_bar;
      color = Colors.lightGreen;
    } else if (signal > -70) {
      icon = Icons.network_wifi_2_bar;
      color = Colors.orange;
    } else if (signal > -80) {
      icon = Icons.network_wifi_1_bar;
      color = Colors.deepOrange;
    } else {
      icon = Icons.signal_wifi_0_bar;
      color = Colors.red;
    }

    return Icon(icon, color: color, size: 28);
  }
}
