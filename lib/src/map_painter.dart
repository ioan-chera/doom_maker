import 'dart:typed_data';
import 'package:flutter/material.dart';


class MapPainter extends CustomPainter {
  final Uint8List fileData;
  final String fileName;

  MapPainter({
    required this.fileData,
    required this.fileName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.grey[100]!
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    Paint gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double gridSize = 64.0;

    for(double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for(double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Paint filePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    double radius = (fileData.length / 1000).clamp(10.0, 100.0);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      filePaint,
    );

    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'File: $fileName\nSize: ${fileData.length} bytes',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}