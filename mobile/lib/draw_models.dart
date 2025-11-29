// mobile/lib/draw_models.dart

class StrokePoint {
  final double x;
  final double y;
  
  StrokePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {
    "x": x,
    "y": y
  };

  static StrokePoint fromJson(dynamic m) {
    if (m == null) return StrokePoint(0.0, 0.0);
    
    final map = Map<String, dynamic>.from(m as Map);
    final dx = map['x'];
    final dy = map['y'];
    
    final x = (dx is num) ? dx.toDouble() : double.tryParse(dx.toString()) ?? 0.0;
    final y = (dy is num) ? dy.toDouble() : double.tryParse(dy.toString()) ?? 0.0;
    
    return StrokePoint(x, y);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokePoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class Stroke {
  final String type = 'stroke';
  final String color;
  final double width;
  final List<StrokePoint> points;
  final DateTime timestamp;

  Stroke({
    required this.color,
    required this.width,
    required this.points,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
    "type": type,
    "color": color,
    "width": width,
    "points": points.map((p) => p.toJson()).toList(),
    "timestamp": timestamp.millisecondsSinceEpoch,
  };

  static Stroke fromJson(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    
    final color = map['color']?.toString() ?? "#000000";
    final widthVal = map['width'];
    final width = (widthVal is num) ? widthVal.toDouble() : double.tryParse(widthVal?.toString() ?? '') ?? 3.0;

    final rawPoints = map['points'] as List? ?? [];
    final points = rawPoints.map((e) => StrokePoint.fromJson(e)).toList();

    return Stroke(color: color, width: width, points: points);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stroke &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          width == other.width &&
          points.length == other.points.length;

  @override
  int get hashCode => color.hashCode ^ width.hashCode ^ points.length.hashCode;
}