import 'dart:ui';
import 'package:flutter/material.dart';
import 'draw_models.dart';

class BoardPainter extends CustomPainter {
  final List<Stroke> strokes;
  BoardPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      paint.color = Color(int.parse(s.color));
      paint.strokeWidth = s.width;
      if (s.points.isEmpty) continue;
      final path = Path();
      path.moveTo(s.points[0].x, s.points[0].y);
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].x, s.points[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
