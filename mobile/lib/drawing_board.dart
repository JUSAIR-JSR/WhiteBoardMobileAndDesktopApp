// mobile/lib/drawing_board.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'draw_models.dart';

Color _parseColorString(String? colorStr) {
  if (colorStr == null) return Colors.black;
  try {
    colorStr = colorStr.trim();
    // If already a hex like "#RRGGBB" or "#AARRGGBB"
    if (colorStr.startsWith('#')) {
      final hex = colorStr.substring(1);
      if (hex.length == 6) {
        // add opaque alpha
        final intVal = int.parse('ff$hex', radix: 16);
        return Color(intVal);
      } else if (hex.length == 8) {
        final intVal = int.parse(hex, radix: 16);
        return Color(intVal);
      }
    }

    // If it is an integer string representation (e.g. "4283215696")
    final maybeInt = int.tryParse(colorStr);
    if (maybeInt != null) {
      return Color(maybeInt);
    }

    // Last fallback: try parse as hex without '#'
    final cleaned = colorStr.replaceAll('0x', '').replaceAll('0X', '');
    if (cleaned.length == 6) {
      return Color(int.parse('ff$cleaned', radix: 16));
    } else if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
  } catch (e) {
    // ignore parse errors
  }
  return Colors.black; // default fallback
}

class BoardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final double offsetX;

  BoardPainter(this.strokes, {this.offsetX = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-offsetX, 0); // ← SHIFT view left/right

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final s in strokes) {
      paint.color = _parseColorString(s.color);
      paint.strokeWidth = s.width;

      if (s.points.isEmpty) continue;

      final path = Path();
      path.moveTo(s.points.first.x, s.points.first.y);

      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].x, s.points[i].y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

