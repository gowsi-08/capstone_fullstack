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
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final Paint roomBorderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Scale to fit canvas
    double scaleX = size.width / MapStructure.width;
    double scaleY = size.height / MapStructure.height;
    // Maintain aspect ratio?
    // Let's just fit for now as requested structure might be different
    
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
      
      // Draw Label
      TextSpan span = TextSpan(style: const TextStyle(color: Colors.black, fontSize: 20), text: room['name']);
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
      appBar: AppBar(title: const Text('Digitized Map Structure')),
      body: InteractiveViewer(
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
    );
  }
}
