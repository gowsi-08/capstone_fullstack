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

class _TrainingDataScreenState extends State<TrainingDataScreen> with SingleTickerProviderStateMixin {
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _floorController = TextEditingController(text: 'ground floor');

  List<Map<String, dynamic>> _scannedNetworks = [];
  bool _isScanning = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _trainingStats;

  List<bool> _selectedScans = [];

  late AnimationController _statsAnimController;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _statsAnimation = CurvedAnimation(parent: _statsAnimController, curve: Curves.easeOutCubic);
    _loadTrainingStats();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _landmarkController.dispose();
    _floorController.dispose();
    _statsAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainingStats() async {
    final stats = await ApiService.getTrainingStats();
    if (mounted) {
      setState(() => _trainingStats = stats);
      _statsAnimController.forward(from: 0);
    }
  }

  Future<void> _scanWifi() async {
    setState(() => _isScanning = true);

    try {
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

      final networks = results.map((ap) {
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
      _loadTrainingStats();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('WiFi Training Data', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
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
      body: Column(
        children: [
          // ── Stats Banner ──
          if (_trainingStats != null)
            FadeTransition(
              opacity: _statsAnimation,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.indigo.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Samples', '${_trainingStats!["total_rows"] ?? 0}', Icons.dataset_outlined),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _statItem('Locations', '${_trainingStats!["total_locations"] ?? 0}', Icons.location_on_outlined),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _statItem('BSSIDs', '${_trainingStats!["total_bssids"] ?? 0}', Icons.wifi),
                  ],
                ),
              ),
            ),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Location Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_location_alt, color: Colors.indigo.shade600, size: 22),
                              const SizedBox(width: 8),
                              Text('Location Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(_locationController, 'Location Name *', 'e.g. cse department office', Icons.room),
                          const SizedBox(height: 14),
                          _buildTextField(_landmarkController, 'Nearby Landmark', 'e.g. near hod cabin', Icons.place),
                          const SizedBox(height: 14),
                          _buildTextField(_floorController, 'Floor', 'e.g. ground floor, second', Icons.layers),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanWifi,
                      icon: _isScanning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_find, color: Colors.white, size: 22),
                      label: Text(
                        _isScanning ? 'Scanning...' : 'Scan WiFi Networks',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Scanned Networks ──
                  if (_scannedNetworks.isNotEmpty) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wifi, color: Colors.teal.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${_scannedNetworks.length} Networks Found',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                ),
                                const Spacer(),
                                _chipButton('All', () => _selectAll(true)),
                                const SizedBox(width: 4),
                                _chipButton('None', () => _selectAll(false)),
                              ],
                            ),
                          ),
                          // List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _scannedNetworks.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, index) {
                              final network = _scannedNetworks[index];
                              final signal = network['signal_strength'] as int;
                              final signalPercent = ((signal + 100) / 70 * 100).clamp(0, 100).toInt();

                              return CheckboxListTile(
                                dense: true,
                                activeColor: Colors.teal,
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
                                      network['bssid'],
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                                    ),
                                    Row(
                                      children: [
                                        _metaChip('${network['frequency']}MHz'),
                                        const SizedBox(width: 4),
                                        _metaChip('${signal}dBm ($signalPercent%)'),
                                        const SizedBox(width: 4),
                                        _metaChip('~${network['estimated_distance']}m'),
                                      ],
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
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitData,
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload, color: Colors.white, size: 22),
                        label: Text(
                          _isSubmitting ? 'Submitting & Retraining...' : 'Submit Data & Retrain Model',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
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
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _chipButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
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
