// -------------------------------------------------------------
// draw_models.dart  (Optimized for Large Canvas + Socket Sync)
// -------------------------------------------------------------

class StrokePoint {
  final double x;
  final double y;

  StrokePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {"x": x, "y": y};

  static StrokePoint fromJson(dynamic data) {
    if (data == null) return StrokePoint(0, 0);

    final map = Map<String, dynamic>.from(data as Map);

    double parse(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return StrokePoint(
      parse(map["x"]),
      parse(map["y"]),
    );
  }
}

class Stroke {
  final String type;      // always "stroke"
  final String color;     // "#RRGGBB" or "#AARRGGBB"
  final double width;     // brush width
  final List<StrokePoint> points;

  Stroke({
    required this.color,
    required this.width,
    required this.points,
  }) : type = "stroke";

  Map<String, dynamic> toJson() => {
        "type": "stroke",
        "color": color,
        "width": width,
        "points": points.map((p) => p.toJson()).toList(),
      };

  static Stroke fromJson(dynamic data) {
    if (data == null) {
      return Stroke(color: "#000000", width: 3.0, points: []);
    }

    final map = Map<String, dynamic>.from(data as Map);

    // Safe width parsing
    double parseWidth(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 3.0;
    }

    // Safe point list parsing
    final rawPoints = map["points"] ?? [];
    final List<StrokePoint> pts = [];

    if (rawPoints is List) {
      for (final p in rawPoints) {
        pts.add(StrokePoint.fromJson(p));
      }
    }

    return Stroke(
      color: map["color"]?.toString() ?? "#000000",
      width: parseWidth(map["width"]),
      points: pts,
    );
  }
}
