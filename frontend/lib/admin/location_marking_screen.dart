import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';

class LocationMarkingScreen extends StatefulWidget {
  const LocationMarkingScreen({Key? key}) : super(key: key);

  @override
  State<LocationMarkingScreen> createState() => _LocationMarkingScreenState();
}

class _LocationMarkingScreenState extends State<LocationMarkingScreen> {
  final TextEditingController _floorController = TextEditingController(text: '1');
  final List<Map<String, dynamic>> _locations = [];
  
  bool _isSavingLocations = false;
  bool _isLoadingLocations = false;
  bool _isLoadingMap = false;
  Uint8List? _mapImageBytes;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _floorController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _refreshData() {
    _loadMapImage();
    _loadLocations();
  }

  Future<void> _loadMapImage() async {
    setState(() => _isLoadingMap = true);
    final floor = _floorController.text;
    final b64 = await ApiService.getMapBase64(floor);
    if (!mounted) return;
    setState(() {
      _isLoadingMap = false;
      _mapImageBytes = b64 != null ? base64Decode(b64) : null;
    });
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    final floor = _floorController.text;
    final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/$floor');
    try {
      final resp = await http.get(uri);
      if (!mounted) return;
      setState(() => _isLoadingLocations = false);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          _locations.clear();
          for (var loc in data) {
            _locations.add({
              'id': loc['id'],
              'name': loc['name'],
              'pos': Offset(loc['x'].toDouble(), loc['y'].toDouble()),
            });
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _saveLocations() async {
    setState(() => _isSavingLocations = true);
    final floor = _floorController.text;
    final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/$floor');
    final data = _locations.map((loc) => {
      'name': loc['name'],
      'x': loc['pos'].dx,
      'y': loc['pos'].dy,
    }).toList();
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (!mounted) return;
      setState(() => _isSavingLocations = false);
      if (resp.statusCode == 200) {
        _showSnackBar('✅ Locations saved successfully!', Colors.green);
        _loadLocations();
      } else {
        _showSnackBar('Failed to save locations', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingLocations = false);
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteLocation(String? id, int index) async {
    if (id == null) {
      setState(() => _locations.removeAt(index));
      await _saveLocations();
      return;
    }
    final uri = Uri.parse('${ApiService.baseUrl}/admin/location/$id');
    try {
      final resp = await http.delete(uri);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() => _locations.removeAt(index));
        _showSnackBar('Location deleted', Colors.orange);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _editLocation(int index) async {
    final loc = _locations[index];
    final nameController = TextEditingController(text: loc['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_location_alt, color: Color(0xFF2979FF)),
            const SizedBox(width: 12),
            Text(
              'Edit Location',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Location name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
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
              borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => _locations[index]['name'] = newName);
      await _saveLocations();
    }
  }

  void _addLocation(Offset pos) async {
    final controller = TextEditingController();
    String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_location_alt, color: Color(0xFF00BCD4)),
              const SizedBox(width: 12),
              Text(
                'Mark Location',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Room 101, Lab, Corridor...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
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
                borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Save Location', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _locations.add({'name': name, 'pos': pos}));
      await _saveLocations();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
              'Location Marking',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Mark and edit room positions',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF132F4C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _floorController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Floor',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _refreshData(),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Color(0xFF00BCD4), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_locations.length} Locations',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_locations.isNotEmpty)
                  Flexible(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isSavingLocations
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(
                        _isSavingLocations ? 'Saving...' : 'Save All',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      onPressed: _isSavingLocations ? null : _saveLocations,
                    ),
                  ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Row(
              children: [
                // Map Area
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              _buildMapContent(),
                              if (_mapImageBytes != null)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00BCD4).withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.touch_app, size: 16, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Tap to add location',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Locations List Panel
                Container(
                  width: 350,
                  margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
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
                                color: const Color(0xFF00BCD4).withOpacity(0.2),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.place, color: Color(0xFF00BCD4), size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Mapped Locations',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingLocations)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF00BCD4),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // List
                            Expanded(
                              child: _locations.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_location,
                                            size: 48,
                                            color: Colors.white.withOpacity(0.2),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No marked locations yet',
                                            style: GoogleFonts.inter(
                                              color: Colors.white60,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap on the map to add',
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.4),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: _locations.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                      itemBuilder: (context, index) {
                                        final loc = _locations[index];
                                        return ListTile(
                                          leading: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: const Color(0xFF00BCD4).withOpacity(0.2),
                                            child: Text(
                                              '${index + 1}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF00BCD4),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            loc['name'],
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'X: ${loc['pos'].dx.toStringAsFixed(0)}  Y: ${loc['pos'].dy.toStringAsFixed(0)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF2979FF), size: 20),
                                                tooltip: 'Edit',
                                                onPressed: () => _editLocation(index),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                tooltip: 'Delete',
                                                onPressed: () => _deleteLocation(loc['id'], index),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    if (_isLoadingMap) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF00BCD4),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading map...',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_mapImageBytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No map loaded for Floor ${_floorController.text}',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a floor plan first',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.1,
      maxScale: 20.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: GestureDetector(
        onTapDown: (details) => _addLocation(details.localPosition),
        child: Stack(
          children: [
            Image.memory(
              _mapImageBytes!,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            ..._locations.map((loc) {
              return Positioned(
                left: loc['pos'].dx - 14,
                top: loc['pos'].dy - 30,
                child: GestureDetector(
                  onLongPress: () => _editLocation(_locations.indexOf(loc)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: const Color(0xFF00BCD4),
                        size: 32,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          loc['name'],
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
