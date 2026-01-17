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
  File? _localMapImage;
  String? _mapImageUrl;
  final List<Map<String, dynamic>> _locations = [];
  final TextEditingController _testDataController = TextEditingController();
  final TextEditingController _floorController = TextEditingController(text: '1');
  final GlobalKey _mapKey = GlobalKey();

  // Use ApiService.baseUrl

  bool _isUploadingMap = false;
  bool _isSavingLocations = false;
  bool _isLoadingLocations = false;
  bool _isFetchingTestData = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _loadMapImage();
    _loadLocations();
  }

  Uint8List? _mapImageBytes;

  Future<void> _loadMapImage() async {
    final floor = _floorController.text;
    final b64 = await ApiService.getMapBase64(floor);
    if (b64 != null) {
      setState(() {
         _mapImageBytes = base64Decode(b64);
      });
    } else {
      setState(() {
        _mapImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load map image')));
    }
  }

  Future<void> _pickMapImage() async {
    final picker = ImagePicker();
    // Optimize on client side immediately: max 2500px dimension, 85% JPEG quality
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2500,
      maxHeight: 2500,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _localMapImage = File(picked.path);
      });
      await _uploadMapImage(File(picked.path));
    }
  }

  Future<void> _uploadMapImage(File imageFile) async {
    setState(() => _isUploadingMap = true);
    final floor = _floorController.text;
    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final resp = await req.send();

    final respBody = await resp.stream.bytesToString();
    final respJson = jsonDecode(respBody);

    setState(() => _isUploadingMap = false);

    if (resp.statusCode == 200 && respJson['success'] == true) {
      _loadMapImage();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map image uploaded!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${respJson['error'] ?? 'Unknown error'}')),
      );
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    final floor = _floorController.text;
    final uri = Uri.parse('${ApiService.baseUrl}/admin/locations/$floor');
    final resp = await http.get(uri);
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
    final resp = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    setState(() => _isSavingLocations = false);
    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locations updated!')),
      );
      _loadLocations();
    }
  }

  Future<void> _deleteLocation(String? id, int index) async {
    if (id == null) {
      setState(() => _locations.removeAt(index));
      await _saveLocations();
      return;
    }
    final uri = Uri.parse('${ApiService.baseUrl}/admin/location/$id');
    final resp = await http.delete(uri);
    if (resp.statusCode == 200) {
      setState(() => _locations.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete location')));
    }
  }

  Future<void> _editLocation(int index) async {
    final loc = _locations[index];
    final nameController = TextEditingController(text: loc['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Location Name'),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _locations[index]['name'] = newName;
      });
      await _saveLocations();
    }
  }

  void _addLocation(Offset pos) async {
    String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Name this location'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      setState(() {
        _locations.add({'name': name, 'pos': pos});
      });
      await _saveLocations();
    }
  }

  final TransformationController _transformationController = TransformationController();

  // ... (existing vars)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          // Top controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                 Expanded(
                   child: TextField(
                     controller: _floorController,
                     decoration: const InputDecoration(labelText: 'Floor', border: OutlineInputBorder()),
                     keyboardType: TextInputType.number,
                     onSubmitted: (_) => _refreshData(),
                   ),
                 ),
                 const SizedBox(width: 10),
                  ElevatedButton.icon(
                     icon: _isUploadingMap
                         ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                         : const Icon(Icons.upload_file),
                     label: const Text('Upload Map'),
                     onPressed: _isUploadingMap ? null : _pickMapImage,
                   ),
                   IconButton(
                     icon: const Icon(Icons.architecture),
                     tooltip: 'View Digitized Structure',
                     onPressed: () => Navigator.pushNamed(context, '/digitized'),
                   ),
              ],
            ),
          ),
          
          // Map Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: Colors.grey[200],
              ),
              child: _mapImageBytes == null
                      ? const Center(child: Text('No map loaded / fetching...'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.001,
                          maxScale: 20.0,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(double.infinity), 
                          child: GestureDetector(
                            onTapDown: (details) {
                              _addLocation(details.localPosition);
                            },
                            child: Stack(
                              children: [                                    _mapImageBytes != null 
                                      ? Image.memory(
                                          _mapImageBytes!,
                                          fit: BoxFit.none,
                                          alignment: Alignment.topLeft,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox(
                                            height: 300, 
                                            child: Center(child: Icon(Icons.broken_image))
                                          ),
                                        )
                                      : const SizedBox(
                                          height: 300, 
                                          child: Center(child: CircularProgressIndicator())
                                        ),
                                ..._locations.map((loc) {
                                  return Positioned(
                                    left: loc['pos'].dx - 12,
                                    top: loc['pos'].dy - 24,
                                    child: GestureDetector(
                                      onLongPress: () {
                                        final index = _locations.indexOf(loc);
                                        _editLocation(index);
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, color: Colors.red, size: 24),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Text(
                                              loc['name'],
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
            ),
          ),
          
          const Divider(height: 1),
          
          // Location List
          Expanded(
            flex: 1, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Locations:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_isLoadingLocations) const LinearProgressIndicator(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _locations.length,
                    itemBuilder: (context, index) {
                      final loc = _locations[index];
                      return ListTile(
                        dense: true,
                        title: Text(loc['name']),
                        subtitle: Text('(${loc['pos'].dx.toStringAsFixed(0)}, ${loc['pos'].dy.toStringAsFixed(0)})'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editLocation(index)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteLocation(loc['id'], index)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(onPressed: _loadLocations, child: const Text('Reload Locations')),
          ),
        ],
      ),
    );
  }
}