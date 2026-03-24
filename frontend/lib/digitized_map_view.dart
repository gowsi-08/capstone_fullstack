import 'package:flutter/material.dart';
import 'generated_map_data.dart';

class DigitizedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint wallPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint roomPaint = Paint()
      ..color = Colors.indigo.withAlpha(20)
      ..style = PaintingStyle.fill;
    
    final Paint roomBorderPaint = Paint()
      ..color = Colors.indigo.withAlpha(120)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double scaleX = size.width / MapStructure.width;
    double scaleY = size.height / MapStructure.height;
    
    canvas.scale(scaleX, scaleY);

    // Draw Walls
    for (var wall in MapStructure.walls) {
      canvas.drawLine(
        Offset(wall['x1'], wall['y1']),
        Offset(wall['x2'], wall['y2']),
        wallPaint
      );
    }

    // Draw Rooms
    for (var room in MapStructure.rooms) {
      Rect rect = room['rect'];
      canvas.drawRect(rect, roomPaint);
      canvas.drawRect(rect, roomBorderPaint);
      
      TextSpan span = TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500), text: room['name']);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DigitizedMapView extends StatefulWidget {
  const DigitizedMapView({Key? key}) : super(key: key);

  @override
  State<DigitizedMapView> createState() => _DigitizedMapViewState();
}

class _DigitizedMapViewState extends State<DigitizedMapView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Digitized Map Structure', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          minScale: 0.01,
          maxScale: 10.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          child: SizedBox(
            width: MapStructure.width,
            height: MapStructure.height,
            child: CustomPaint(
              painter: DigitizedMapPainter(),
            ),
          ),
        ),
      ),
    );
  }
}
