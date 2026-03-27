import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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
  final List<int> _floors = [1, 2, 3]; // Available floors
  final Map<int, Uint8List?> _floorMaps = {};
  final Map<int, bool> _loadingStates = {};
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFloorMaps();
  }

  Future<void> _loadAllFloorMaps() async {
    setState(() => _isInitialLoading = true);
    
    for (final floor in _floors) {
      setState(() => _loadingStates[floor] = true);
      final b64 = await ApiService.getMapBase64(floor.toString());
      if (mounted) {
        setState(() {
          _floorMaps[floor] = b64 != null ? base64Decode(b64) : null;
          _loadingStates[floor] = false;
        });
      }
    }
    
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadSingleFloorMap(int floor) async {
    setState(() => _loadingStates[floor] = true);
    final b64 = await ApiService.getMapBase64(floor.toString());
    if (mounted) {
      setState(() {
        _floorMaps[floor] = b64 != null ? base64Decode(b64) : null;
        _loadingStates[floor] = false;
      });
    }
  }

  Future<void> _uploadMapForFloor(int floor) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2500,
      maxHeight: 2500,
      imageQuality: 85,
    );
    
    if (picked == null) return;

    setState(() => _loadingStates[floor] = true);
    
    final uri = Uri.parse('${ApiService.baseUrl}/admin/upload_map/$floor');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', picked.path));

    try {
      final resp = await req.send();
      final respBody = await resp.stream.bytesToString();
      final respJson = jsonDecode(respBody);

      if (!mounted) return;
      
      if (resp.statusCode == 200 && respJson['success'] == true) {
        await _loadSingleFloorMap(floor);
        _showSnackBar('✅ Floor $floor map uploaded successfully!', const Color(0xFF00C853));
      } else {
        setState(() => _loadingStates[floor] = false);
        _showSnackBar('❌ Upload failed: ${respJson['error'] ?? 'Unknown'}', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStates[floor] = false);
      _showSnackBar('❌ Upload failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openExpandedView(int floor, Uint8List? imageBytes) {
    if (imageBytes == null) {
      _uploadMapForFloor(floor);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ExpandedFloorView(
          floor: floor,
          imageBytes: imageBytes,
          onReplace: () async {
            Navigator.pop(context);
            await _uploadMapForFloor(floor);
          },
          onViewLocations: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/admin/location_marking');
          },
        ),
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
              'Floor Plans',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Tap a floor to expand and manage',
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
            onPressed: _loadAllFloorMaps,
          ),
        ],
      ),
      body: _isInitialLoading
          ? _buildLoadingSkeleton()
          : _floors.isEmpty
              ? _buildEmptyState()
              : _buildFloorGallery(),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7C4DFF),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            'No floor plans uploaded yet',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload floor plans to get started',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorGallery() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _floors.length,
      itemBuilder: (context, index) {
        final floor = _floors[index];
        return _buildFloorCard(floor);
      },
    );
  }

  Widget _buildFloorCard(int floor) {
    final imageBytes = _floorMaps[floor];
    final isLoading = _loadingStates[floor] ?? false;

    return GestureDetector(
      onTap: () => _openExpandedView(floor, imageBytes),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF132F4C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Map Image or Placeholder
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C4DFF),
                  strokeWidth: 2,
                ),
              )
            else if (imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.upload_file,
                        size: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No map uploaded',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Floor Label Badge (bottom-left)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getFloorColor(floor),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Floor $floor',
                  style: GoogleFonts.inter(
                    color: _getFloorColor(floor),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Location Count Badge (top-right) - placeholder for now
            if (imageBytes != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132F4C).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '0', // TODO: Get actual location count
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
}

// Expanded Floor View
class _ExpandedFloorView extends StatelessWidget {
  final int floor;
  final Uint8List imageBytes;
  final VoidCallback onReplace;
  final VoidCallback onViewLocations;

  const _ExpandedFloorView({
    required this.floor,
    required this.imageBytes,
    required this.onReplace,
    required this.onViewLocations,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: Stack(
        children: [
          // Interactive Map
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Top Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A1929).withOpacity(0.9),
                    const Color(0xFF0A1929).withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132F4C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getFloorColor(floor),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Floor $floor',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF132F4C),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReplace,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(
                        'Replace',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onViewLocations,
                      icon: const Icon(Icons.location_on, size: 18),
                      label: Text(
                        'Locations',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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
