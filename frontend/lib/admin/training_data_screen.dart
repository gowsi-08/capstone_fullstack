import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../api_service.dart';

class TrainingDataScreen extends StatefulWidget {
  const TrainingDataScreen({Key? key}) : super(key: key);

  @override
  State<TrainingDataScreen> createState() => _TrainingDataScreenState();
}

class _TrainingDataScreenState extends State<TrainingDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training Data Management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Collect, manage, and merge WiFi data',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C4DFF),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.5),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.wifi_find), text: 'Collect'),
            Tab(icon: Icon(Icons.storage), text: 'Manage'),
            Tab(icon: Icon(Icons.merge_type), text: 'Merge'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CollectTab(),
          ManageTab(),
          MergeTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: COLLECT
// ============================================================================
class CollectTab extends StatefulWidget {
  const CollectTab({Key? key}) : super(key: key);

  @override
  State<CollectTab> createState() => _CollectTabState();
}

class _CollectTabState extends State<CollectTab>
    with AutomaticKeepAliveClientMixin {
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _floorController = TextEditingController(text: 'ground floor');

  List<Map<String, dynamic>> _scannedNetworks = [];
  bool _isScanning = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _trainingStats;

  List<bool> _selectedScans = [];

  @override
  bool get wantKeepAlive => true;

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
      var locPermission = await Permission.location.request();
      if (!locPermission.isGranted) {
        if (mounted) {
          Fluttertoast.showToast(msg: '⚠️ Location permission required');
        }
        setState(() => _isScanning = false);
        return;
      }

      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        Fluttertoast.showToast(msg: '⚠️ Enable location & WiFi');
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
        // Convert WiFiChannelWidth enum to integer by parsing the string representation
        int bandwidth = 20; // default
        if (ap.channelWidth != null) {
          final widthStr = ap.channelWidth.toString();
          // Extract number from string like "WiFiChannelWidth.width20" or "WiFiChannelWidth.unkown"
          if (widthStr.contains('20')) {
            bandwidth = 20;
          } else if (widthStr.contains('40')) {
            bandwidth = 40;
          } else if (widthStr.contains('80')) {
            bandwidth = 80;
          } else if (widthStr.contains('160')) {
            bandwidth = 160;
          }
        }
        return {
          'ssid': ap.ssid.isNotEmpty ? ap.ssid : 'Hidden',
          'bssid': ap.bssid,
          'frequency': ap.frequency,
          'bandwidth': bandwidth,
          'signal_strength': ap.level,
          'estimated_distance':
              double.parse(estimatedDistance.toStringAsFixed(2)),
          'capabilities': ap.capabilities,
          'selected': true,
        };
      }).toList();

      networks.sort((a, b) =>
          (b['signal_strength'] as int).compareTo(a['signal_strength'] as int));

      setState(() {
        _scannedNetworks = networks;
        _selectedScans = List.generate(networks.length, (_) => true);
        _isScanning = false;
      });

      Fluttertoast.showToast(
        msg: '✅ Found ${networks.length} networks',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ Scan failed: $e');
      setState(() => _isScanning = false);
    }
  }

  double _estimateDistance(int signalStrengthDbm, int frequencyMhz) {
    double exp = (27.55 -
            (20 * log(frequencyMhz.toDouble()) / ln10) +
            signalStrengthDbm.abs().toDouble()) /
        20.0;
    return pow(10, exp).toDouble();
  }

  Future<void> _submitData() async {
    final location = _locationController.text.trim();
    final landmark = _landmarkController.text.trim();
    final floor = _floorController.text.trim();

    if (location.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Enter location name');
      return;
    }
    if (_scannedNetworks.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Scan WiFi first');
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
      Fluttertoast.showToast(msg: '⚠️ Select at least one network');
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
        toastLength: Toast.LENGTH_LONG,
      );
      _loadTrainingStats();
      setState(() {
        _scannedNetworks = [];
        _selectedScans = [];
      });
    } else {
      Fluttertoast.showToast(
        msg: '❌ Failed to submit',
        backgroundColor: Colors.red,
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
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Banner
          if (_trainingStats != null) _buildStatsBanner(),
          const SizedBox(height: 24),

          // Location Form
          _buildLocationForm(),
          const SizedBox(height: 24),

          // Scan Button
          _buildScanButton(),
          const SizedBox(height: 24),

          // Scanned Networks
          if (_scannedNetworks.isNotEmpty) ...[
            _buildNetworksList(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Samples', '${_trainingStats!["total_rows"] ?? 0}',
              Icons.dataset_outlined),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
          _statItem('Locations',
              '${_trainingStats!["total_locations"] ?? 0}', Icons.location_on_outlined),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
          _statItem('BSSIDs', '${_trainingStats!["total_bssids"] ?? 0}',
              Icons.wifi),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationForm() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_location_alt,
                  color: Color(0xFF7C4DFF), size: 24),
              const SizedBox(width: 12),
              Text(
                'Location Details',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(_locationController, 'Location Name *',
              'e.g. CSE Department', Icons.room),
          const SizedBox(height: 14),
          _buildTextField(_landmarkController, 'Nearby Landmark',
              'e.g. Near HOD Cabin', Icons.place),
          const SizedBox(height: 14),
          _buildTextField(_floorController, 'Floor',
              'e.g. Ground Floor', Icons.layers),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white70),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF7C4DFF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isScanning ? null : _scanWifi,
        icon: _isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.wifi_find, color: Colors.white, size: 24),
        label: Text(
          _isScanning ? 'Scanning...' : 'Scan WiFi Networks',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildNetworksList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A52),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: Color(0xFF7C4DFF), size: 22),
                const SizedBox(width: 12),
                Text(
                  '${_scannedNetworks.length} Networks',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                _chipButton('All', () => _selectAll(true)),
                const SizedBox(width: 8),
                _chipButton('None', () => _selectAll(false)),
              ],
            ),
          ),
          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scannedNetworks.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
            itemBuilder: (context, index) {
              final network = _scannedNetworks[index];
              final signal = network['signal_strength'] as int;

              return CheckboxListTile(
                dense: true,
                activeColor: const Color(0xFF7C4DFF),
                value: _selectedScans[index],
                onChanged: (val) {
                  setState(() => _selectedScans[index] = val ?? false);
                },
                secondary: _signalIcon(signal),
                title: Text(
                  network['ssid'] ?? 'Hidden',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      network['bssid'],
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        _metaChip('${network['frequency']}MHz'),
                        _metaChip('${signal}dBm'),
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
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitData,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload, color: Colors.white, size: 24),
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit Data & Retrain',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _chipButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A52),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          fontSize: 10,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _signalIcon(int signal) {
    IconData icon;
    Color color;

    if (signal > -50) {
      icon = Icons.signal_wifi_4_bar;
      color = const Color(0xFF00C853);
    } else if (signal > -60) {
      icon = Icons.network_wifi_3_bar;
      color = const Color(0xFF64DD17);
    } else if (signal > -70) {
      icon = Icons.network_wifi_2_bar;
      color = const Color(0xFFFF6D00);
    } else if (signal > -80) {
      icon = Icons.network_wifi_1_bar;
      color = const Color(0xFFFF3D00);
    } else {
      icon = Icons.signal_wifi_0_bar;
      color = const Color(0xFFD50000);
    }

    return Icon(icon, color: color, size: 28);
  }
}

// ============================================================================
// TAB 2: MANAGE
// ============================================================================
class ManageTab extends StatefulWidget {
  const ManageTab({Key? key}) : super(key: key);

  @override
  State<ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends State<ManageTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // View mode
  bool _isGroupedView = true;

  // Filters
  int? _selectedFloor;
  String? _selectedSource;
  String _searchQuery = '';

  // Data
  Map<String, dynamic>? _groupedData;
  Map<String, dynamic>? _paginatedData;
  bool _isLoading = false;

  // Multi-select
  bool _isMultiSelectMode = false;
  Set<String> _selectedRecordIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (_isGroupedView) {
      final data = await ApiService.getTrainingRecordsGrouped(floor: _selectedFloor);
      if (mounted) {
        setState(() {
          _groupedData = data;
          _isLoading = false;
        });
      }
    } else {
      final data = await ApiService.getTrainingRecordsPaginated(
        floor: _selectedFloor,
        source: _selectedSource,
        location: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _paginatedData = data;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedRecordIds.clear();
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedRecordIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        'Delete ${_selectedRecordIds.length} records?',
        'This action cannot be undone.',
        Colors.red,
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTrainingRecordsBulk(_selectedRecordIds.toList());
      if (success && mounted) {
        Fluttertoast.showToast(
          msg: '✅ Deleted ${_selectedRecordIds.length} records',
          backgroundColor: Colors.green,
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedRecordIds.clear();
        });
        _loadData();
      } else if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete records',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _bulkChangeLocation() async {
    if (_selectedRecordIds.isEmpty) return;

    final newLocation = await showDialog<String>(
      context: context,
      builder: (ctx) => _buildTextInputDialog('Change Location', 'Enter new location name'),
    );

    if (newLocation != null && newLocation.isNotEmpty) {
      final success = await ApiService.updateTrainingRecordsBulk(
        _selectedRecordIds.toList(),
        {'location': newLocation},
      );
      if (success && mounted) {
        Fluttertoast.showToast(
          msg: '✅ Updated ${_selectedRecordIds.length} records',
          backgroundColor: Colors.green,
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedRecordIds.clear();
        });
        _loadData();
      } else if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to update records',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _bulkChangeFloor() async {
    if (_selectedRecordIds.isEmpty) return;

    final newFloor = await showDialog<int>(
      context: context,
      builder: (ctx) => _buildFloorPickerDialog(),
    );

    if (newFloor != null) {
      final success = await ApiService.updateTrainingRecordsBulk(
        _selectedRecordIds.toList(),
        {'floor': newFloor},
      );
      if (success && mounted) {
        Fluttertoast.showToast(
          msg: '✅ Updated ${_selectedRecordIds.length} records',
          backgroundColor: Colors.green,
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedRecordIds.clear();
        });
        _loadData();
      } else if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to update records',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            // Filter Bar
            _buildFilterBar(),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
                  : _isGroupedView
                      ? _buildGroupedView()
                      : _buildListView(),
            ),
          ],
        ),
        // Bulk Action Bar
        if (_isMultiSelectMode && _selectedRecordIds.isNotEmpty)
          _buildBulkActionBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          // Search + View Toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search location...',
                    hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7C4DFF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(_isGroupedView ? Icons.view_list : Icons.view_module),
                color: const Color(0xFF7C4DFF),
                onPressed: () {
                  setState(() => _isGroupedView = !_isGroupedView);
                  _loadData();
                },
              ),
              IconButton(
                icon: Icon(_isMultiSelectMode ? Icons.close : Icons.checklist),
                color: _isMultiSelectMode ? Colors.red : const Color(0xFF7C4DFF),
                onPressed: _toggleMultiSelect,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Floors', _selectedFloor == null, () {
                  setState(() => _selectedFloor = null);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _filterChip('Floor 1', _selectedFloor == 1, () {
                  setState(() => _selectedFloor = 1);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _filterChip('Floor 2', _selectedFloor == 2, () {
                  setState(() => _selectedFloor = 2);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _filterChip('Floor 3', _selectedFloor == 3, () {
                  setState(() => _selectedFloor = 3);
                  _loadData();
                }),
                const SizedBox(width: 16),
                _filterChip('All Sources', _selectedSource == null, () {
                  setState(() => _selectedSource = null);
                  _loadData();
                }),
                const SizedBox(width: 8),
                _filterChip('Train', _selectedSource == 'train', () {
                  setState(() => _selectedSource = 'train');
                  _loadData();
                }),
                const SizedBox(width: 8),
                _filterChip('Test', _selectedSource == 'test', () {
                  setState(() => _selectedSource = 'test');
                  _loadData();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C4DFF) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C4DFF) : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedView() {
    if (_groupedData == null || _groupedData!.isEmpty) {
      return Center(
        child: Text(
          'No records found',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }

    final groups = _groupedData!.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final groupKey = entry.key;
        final groupData = entry.value as Map<String, dynamic>;
        return _buildGroupCard(groupKey, groupData);
      },
    );
  }

  Widget _buildGroupCard(String groupKey, Map<String, dynamic> groupData) {
    final location = groupData['location'] ?? 'Unknown';
    final floor = groupData['floor'] ?? 0;
    final count = groupData['count'] ?? 0;
    final records = groupData['records'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: _getFloorColor(floor).withOpacity(0.2),
            child: Text(
              'F$floor',
              style: GoogleFonts.inter(
                color: _getFloorColor(floor),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            location,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '$count records',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _deleteGroup(location, floor),
              ),
              const Icon(Icons.expand_more, color: Colors.white70),
            ],
          ),
          children: records.map((record) => _buildRecordTile(record)).toList(),
        ),
      ),
    );
  }

  Widget _buildRecordTile(dynamic record) {
    final recordMap = record as Map<String, dynamic>;
    final id = recordMap['_id']?.toString() ?? '';
    final bssid = recordMap['bssid'] ?? 'Unknown';
    final signal = recordMap['signal'] ?? -100;
    final landmark = recordMap['landmark'] ?? '';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListTile(
        dense: true,
        leading: _isMultiSelectMode
            ? Checkbox(
                value: _selectedRecordIds.contains(id),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedRecordIds.add(id);
                    } else {
                      _selectedRecordIds.remove(id);
                    }
                  });
                },
                activeColor: const Color(0xFF7C4DFF),
              )
            : _signalIcon(signal),
        title: Text(
          bssid,
          style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.white),
        ),
        subtitle: landmark.isNotEmpty
            ? Text(
                landmark,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
              )
            : null,
        trailing: Text(
          '${signal}dBm',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
        ),
        onLongPress: () {
          if (!_isMultiSelectMode) {
            setState(() {
              _isMultiSelectMode = true;
              _selectedRecordIds.add(id);
            });
          }
        },
      ),
    );
  }

  Widget _buildListView() {
    if (_paginatedData == null) {
      return Center(
        child: Text(
          'No records found',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }

    final records = _paginatedData!['records'] as List<dynamic>? ?? [];
    if (records.isEmpty) {
      return Center(
        child: Text(
          'No records found',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index] as Map<String, dynamic>;
        return _buildListRecordCard(record);
      },
    );
  }

  Widget _buildListRecordCard(Map<String, dynamic> record) {
    final id = record['_id']?.toString() ?? '';
    final bssid = record['bssid'] ?? 'Unknown';
    final signal = record['signal'] ?? -100;
    final location = record['location'] ?? 'Unknown';
    final floor = record['floor'] ?? 0;
    final landmark = record['landmark'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: _isMultiSelectMode
            ? Checkbox(
                value: _selectedRecordIds.contains(id),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedRecordIds.add(id);
                    } else {
                      _selectedRecordIds.remove(id);
                    }
                  });
                },
                activeColor: const Color(0xFF7C4DFF),
              )
            : _signalIcon(signal),
        title: Text(
          bssid,
          style: GoogleFonts.robotoMono(fontSize: 13, color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getFloorColor(floor).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getFloorColor(floor)),
                  ),
                  child: Text(
                    'F$floor',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _getFloorColor(floor),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (landmark.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                landmark,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
              ),
            ],
          ],
        ),
        trailing: Text(
          '${signal}dBm',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        ),
        onLongPress: () {
          if (!_isMultiSelectMode) {
            setState(() {
              _isMultiSelectMode = true;
              _selectedRecordIds.add(id);
            });
          }
        },
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Text(
                '${_selectedRecordIds.length} selected',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_location, color: Color(0xFF2979FF)),
                onPressed: _bulkChangeLocation,
                tooltip: 'Change Location',
              ),
              IconButton(
                icon: const Icon(Icons.layers, color: Color(0xFF00BCD4)),
                onPressed: _bulkChangeFloor,
                tooltip: 'Change Floor',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _bulkDelete,
                tooltip: 'Delete',
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _isMultiSelectMode = false;
                    _selectedRecordIds.clear();
                  });
                },
                tooltip: 'Cancel',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGroup(String location, int floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        'Delete all records for "$location" (Floor $floor)?',
        'This action cannot be undone.',
        Colors.red,
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTrainingRecordsByGroup(location, floor);
      if (success && mounted) {
        Fluttertoast.showToast(
          msg: '✅ Deleted all records for $location',
          backgroundColor: Colors.green,
        );
        _loadData();
      } else if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete records',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Widget _buildConfirmDialog(String title, String message, Color color) {
    return AlertDialog(
      backgroundColor: const Color(0xFF132F4C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTextInputDialog(String title, String hint) {
    final controller = TextEditingController();
    return AlertDialog(
      backgroundColor: const Color(0xFF132F4C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: controller,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
          child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildFloorPickerDialog() {
    return AlertDialog(
      backgroundColor: const Color(0xFF132F4C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Select Floor',
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [1, 2, 3].map((floor) {
          return ListTile(
            title: Text(
              'Floor $floor',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context, floor),
          );
        }).toList(),
      ),
    );
  }

  Color _getFloorColor(int floor) {
    switch (floor) {
      case 1:
        return const Color(0xFF2979FF);
      case 2:
        return const Color(0xFF00BCD4);
      case 3:
        return const Color(0xFF7C4DFF);
      default:
        return Colors.grey;
    }
  }

  Widget _signalIcon(int signal) {
    IconData icon;
    Color color;

    if (signal > -50) {
      icon = Icons.signal_wifi_4_bar;
      color = const Color(0xFF00C853);
    } else if (signal > -60) {
      icon = Icons.network_wifi_3_bar;
      color = const Color(0xFF64DD17);
    } else if (signal > -70) {
      icon = Icons.network_wifi_2_bar;
      color = const Color(0xFFFF6D00);
    } else if (signal > -80) {
      icon = Icons.network_wifi_1_bar;
      color = const Color(0xFFFF3D00);
    } else {
      icon = Icons.signal_wifi_0_bar;
      color = const Color(0xFFD50000);
    }

    return Icon(icon, color: color, size: 24);
  }
}

// ============================================================================
// TAB 3: MERGE
// ============================================================================
class MergeTab extends StatefulWidget {
  const MergeTab({Key? key}) : super(key: key);

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _locations = [];
  Set<String> _selectedSourceLocations = {};
  String _targetLocation = '';
  int _selectedFloor = 1;
  bool _deleteSources = true;
  bool _isLoading = false;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final allLocations = await ApiService.getTrainingLocations();
    if (mounted) {
      // Filter by selected floor
      final filteredLocations = allLocations.where((loc) {
        if (loc is Map<String, dynamic>) {
          return loc['floor'] == _selectedFloor;
        }
        return false;
      }).toList();
      
      setState(() {
        _locations = filteredLocations;
        _isLoading = false;
      });
    }
  }

  Future<void> _performMerge() async {
    if (_selectedSourceLocations.isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Select at least one source location');
      return;
    }
    if (_targetLocation.trim().isEmpty) {
      Fluttertoast.showToast(msg: '⚠️ Enter target location name');
      return;
    }

    final totalRecords = _locations
        .where((loc) => _selectedSourceLocations.contains(loc['location']))
        .fold<int>(0, (sum, loc) => sum + (loc['count'] as int? ?? 0));

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132F4C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Merge',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Merge $totalRecords records from ${_selectedSourceLocations.length} locations into:',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A52),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C4DFF)),
              ),
              child: Text(
                _targetLocation.trim(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_deleteSources)
              Text(
                '⚠️ Source locations will be deleted',
                style: GoogleFonts.inter(color: Colors.orange, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
            child: Text('Merge', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isMerging = true);
      final success = await ApiService.mergeTrainingLocations(
        sourceLocations: _selectedSourceLocations.toList(),
        targetLocation: _targetLocation.trim(),
        floor: _selectedFloor,
        deleteSources: _deleteSources,
      );
      setState(() => _isMerging = false);

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: '✅ Merged $totalRecords records into ${_targetLocation.trim()}',
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() {
          _selectedSourceLocations.clear();
          _targetLocation = '';
        });
        _loadLocations();
      } else if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Merge failed',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _isMerging
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                const SizedBox(height: 16),
                Text(
                  'Merging locations...',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Floor Selector
                _buildFloorSelector(),
                const SizedBox(height: 24),

                // Source Locations Panel
                _buildSourceLocationsPanel(),
                const SizedBox(height: 24),

                // Arrow Icon
                Center(
                  child: Icon(
                    Icons.arrow_downward,
                    size: 48,
                    color: const Color(0xFF7C4DFF).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Target Location Panel
                _buildTargetLocationPanel(),
                const SizedBox(height: 24),

                // Options
                _buildOptions(),
                const SizedBox(height: 24),

                // Preview
                _buildPreview(),
                const SizedBox(height: 24),

                // Merge Button
                _buildMergeButton(),
              ],
            ),
          );
  }

  Widget _buildFloorSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers, color: Color(0xFF7C4DFF), size: 22),
              const SizedBox(width: 12),
              Text(
                'Select Floor',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [1, 2, 3].map((floor) {
              final isSelected = _selectedFloor == floor;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFloor = floor;
                        _selectedSourceLocations.clear();
                      });
                      _loadLocations();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF1A3A52),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C4DFF)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        'Floor $floor',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceLocationsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A52),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.source, color: Color(0xFF2979FF), size: 22),
                const SizedBox(width: 12),
                Text(
                  'Source Locations',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_selectedSourceLocations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedSourceLocations.length} selected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // List
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                )
              : _locations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'No locations found for Floor $_selectedFloor',
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _locations.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      itemBuilder: (context, index) {
                        final loc = _locations[index] as Map<String, dynamic>;
                        final location = loc['location'] ?? 'Unknown';
                        final count = loc['count'] ?? 0;
                        final isSelected = _selectedSourceLocations.contains(location);

                        return CheckboxListTile(
                          activeColor: const Color(0xFF2979FF),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSourceLocations.add(location);
                              } else {
                                _selectedSourceLocations.remove(location);
                              }
                            });
                          },
                          title: Text(
                            location,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '$count records',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildTargetLocationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xFF00C853), size: 22),
              const SizedBox(width: 12),
              Text(
                'Target Location',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter new location name',
              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.edit_location, color: Color(0xFF00C853)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFF1A3A52),
            ),
            onChanged: (val) {
              setState(() => _targetLocation = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.settings, color: Color(0xFF7C4DFF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete source records after merge',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          Switch(
            value: _deleteSources,
            onChanged: (val) {
              setState(() => _deleteSources = val);
            },
            activeColor: const Color(0xFF7C4DFF),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final totalRecords = _locations
        .where((loc) => _selectedSourceLocations.contains(loc['location']))
        .fold<int>(0, (sum, loc) => sum + (loc['count'] as int? ?? 0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7C4DFF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.preview, color: Color(0xFF7C4DFF), size: 22),
              const SizedBox(width: 12),
              Text(
                'Merge Preview',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _previewStat('Sources', '${_selectedSourceLocations.length}', Icons.source),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
              _previewStat('Records', '$totalRecords', Icons.dataset),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
              _previewStat('Floor', '$_selectedFloor', Icons.layers),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMergeButton() {
    final isEnabled = _selectedSourceLocations.isNotEmpty && _targetLocation.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _performMerge : null,
        icon: const Icon(Icons.merge_type, color: Colors.white, size: 24),
        label: Text(
          'Merge Locations',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? const Color(0xFF7C4DFF) : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}
