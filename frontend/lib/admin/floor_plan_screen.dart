import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';

class FloorPlanScreen extends StatefulWidget {
  const FloorPlanScreen({Key? key}) : super(key: key);

  @override
  State<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  final TextEditingController _floorController = TextEditingController(text: '1');
  bool _isUploadingMap = false;
  bool _isLoadingMap = false;
  Uint8List? _mapImageBytes;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadMapImage();
  }

  @override
  void dispose() {
    _floorController.dispose();
    _transformationController.dispose();
    super.dispose();
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
        _showSnackBar('✅ Map uploaded successfully!', Colors.green);
      } else {
        _showSnackBar('Upload failed: ${respJson['error'] ?? 'Unknown'}', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingMap = false);
      _showSnackBar('Upload failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
              'Floor Plan Management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Upload and manage floor maps',
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
            tooltip: 'Refresh Map',
            onPressed: _loadMapImage,
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
                    onSubmitted: (_) => _loadMapImage(),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Floor ${_floorController.text}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _isUploadingMap
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file, size: 20),
                  label: Text(
                    _isUploadingMap ? 'Uploading...' : 'Upload Map',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isUploadingMap ? null : _pickMapImage,
                ),
              ],
            ),
          ),

          // Map Display Area
          Expanded(
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
                    child: _buildMapContent(),
                  ),
                ),
              ),
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
              color: Color(0xFF2979FF),
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
              'Upload a floor plan to get started',
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
      child: Image.memory(
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
    );
  }
}
