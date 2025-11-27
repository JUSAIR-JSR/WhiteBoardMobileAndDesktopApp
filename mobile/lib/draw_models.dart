class StrokePoint {
  final double x;
  final double y;
  StrokePoint(this.x, this.y);
  Map<String, dynamic> toJson() => {"x": x, "y": y};
  static StrokePoint fromJson(Map m) => StrokePoint((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
}

class Stroke {
  final String type = 'stroke';
  String color;
  double width;
  List<StrokePoint> points;
  Stroke({required this.color, required this.width, required this.points});
  Map<String, dynamic> toJson() => {
    "type": type,
    "color": color,
    "width": width,
    "points": points.map((p) => p.toJson()).toList()
  };
  static Stroke fromJson(Map m) {
    return Stroke(
      color: m['color'],
      width: (m['width'] as num).toDouble(),
      points: (m['points'] as List).map((e)=>StrokePoint.fromJson(e)).toList()
    );
  }
}
