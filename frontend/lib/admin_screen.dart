import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final List<Map<String, dynamic>> _locations = [];
  final TextEditingController _floorController = TextEditingController(text: '1');

  bool _isUploadingMap = false;
  bool _isSavingLocations = false;
  bool _isLoadingLocations = false;

  Uint8List? _mapImageBytes;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _loadMapImage();
    _loadLocations();
  }

  Future<void> _loadMapImage() async {
    final floor = _floorController.text;
    final b64 = await ApiService.getMapBase64(floor);
    if (!mounted) return;
    if (b64 != null) {
      setState(() => _mapImageBytes = base64Decode(b64));
    } else {
      setState(() => _mapImageBytes = null);
    }
  }

  Future<void> _pickMapImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2500,
      maxHeight: 2500,
      imageQuality: 85,
    );
    if (picked != null) {
      await _uploadMapImage(File(picked.path));
    }
  }

  Future<void> _uploadMapImage(File imageFile) async {
    setState(() => _isUploadingMap = true);
    final floor = _floorController.text;
    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final resp = await req.send();
      final respBody = await resp.stream.bytesToString();
      final respJson = jsonDecode(respBody);

      if (!mounted) return;
      setState(() => _isUploadingMap = false);
      if (resp.statusCode == 200 && respJson['success'] == true) {
        _loadMapImage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Map uploaded successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${respJson['error'] ?? 'Unknown'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingMap = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
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
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (!mounted) return;
      setState(() => _isSavingLocations = false);
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Locations saved!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadLocations();
      }
    } catch (e) {
      if (mounted) setState(() => _isSavingLocations = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_location_alt, color: Colors.indigo.shade700),
            const SizedBox(width: 8),
            const Text('Edit Location'),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Location name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.add_location_alt, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text('Mark Location'),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Room 101, Lab, Corridor...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save Location'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.model_training),
            tooltip: 'WiFi Training Data',
            onPressed: () => Navigator.pushNamed(context, '/training_data'),
          ),
          IconButton(
            icon: const Icon(Icons.architecture),
            tooltip: 'Digitized Structure',
            onPressed: () => Navigator.pushNamed(context, '/digitized'),
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          // ── Control Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade500],
              ),
            ),
            child: Row(
              children: [
                // Floor selector
                Container(
                  width: 80,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(60)),
                  ),
                  child: TextField(
                    controller: _floorController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Floor',
                      hintStyle: TextStyle(color: Colors.white54),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _refreshData(),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Floor ${_floorController.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _isUploadingMap
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file, size: 20),
                  label: Text(
                    _isUploadingMap ? 'Uploading...' : 'Upload Map',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isUploadingMap ? null : _pickMapImage,
                ),
              ],
            ),
          ),

          // ── Map Area ──
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Map content
                  if (_mapImageBytes == null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No map loaded for Floor ${_floorController.text}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload a floor plan to get started',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
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
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 300,
                                    child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
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
                                          Container(
                                            decoration: const BoxDecoration(
                                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                                            ),
                                            child: const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              loc['name'],
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                      },
                    ),

                  // Hint badge
                  if (_mapImageBytes != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 14, color: Colors.indigo.shade400),
                            const SizedBox(width: 4),
                            Text('Tap to add location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Locations List ──
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.place, size: 20, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Mapped Locations',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo.shade800),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_locations.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_isLoadingLocations) ...[
                          const SizedBox(width: 8),
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
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
                                Icon(Icons.add_location, size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('No marked locations yet', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _locations.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, index) {
                              final loc = _locations[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                                  ),
                                ),
                                title: Text(loc['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(
                                  'X: ${loc['pos'].dx.toStringAsFixed(0)}  Y: ${loc['pos'].dy.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 20),
                                      tooltip: 'Edit',
                                      onPressed: () => _editLocation(index),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
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
        ],
      ),
    );
  }
}