final class GridPoint {
  const GridPoint({required this.x, required this.y, required this.color});

  final int x;
  final int y;
  final String color;
}

final class LevelModel {
  const LevelModel({
    required this.id,
    required this.size,
    required this.points,
  });

  factory LevelModel.fromJson(Map<String, Object?> json) {
    final id = _requiredInt(json, 'id');
    final size = _requiredInt(json, 'size');
    if (size < 2) {
      throw const LevelFormatException('size must be at least 2');
    }

    final rawPoints = json['points'];
    if (rawPoints is! List<Object?> || rawPoints.isEmpty) {
      throw const LevelFormatException('points must be a non-empty list');
    }

    final points = <GridPoint>[];
    final coordinates = <(int, int)>{};
    final colorCounts = <String, int>{};

    for (var index = 0; index < rawPoints.length; index++) {
      final rawPoint = rawPoints[index];
      if (rawPoint is! Map) {
        throw LevelFormatException('points[$index] must be an object');
      }

      final pointJson = rawPoint.cast<String, Object?>();
      final x = _requiredInt(pointJson, 'points[$index].x', key: 'x');
      final y = _requiredInt(pointJson, 'points[$index].y', key: 'y');
      final color = pointJson['color'];
      if (color is! String || color.trim().isEmpty) {
        throw LevelFormatException(
          'points[$index].color must be a non-empty string',
        );
      }
      if (x < 0 || x >= size || y < 0 || y >= size) {
        throw LevelFormatException(
          'points[$index] coordinates must be within the size $size grid',
        );
      }
      if (!coordinates.add((x, y))) {
        throw LevelFormatException(
          'points[$index] duplicates the coordinate ($x, $y)',
        );
      }

      points.add(GridPoint(x: x, y: y, color: color));
      colorCounts.update(color, (count) => count + 1, ifAbsent: () => 1);
    }

    for (final MapEntry(key: color, value: count) in colorCounts.entries) {
      if (count != 2) {
        throw LevelFormatException(
          'points.color "$color" must have exactly two endpoints',
        );
      }
    }

    return LevelModel(
      id: id,
      size: size,
      points: List<GridPoint>.unmodifiable(points),
    );
  }

  final int id;
  final int size;
  final List<GridPoint> points;
}

final class LevelFormatException implements FormatException {
  const LevelFormatException(this.message);

  @override
  final String message;

  @override
  Object? get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => 'LevelFormatException: $message';
}

int _requiredInt(Map<String, Object?> json, String field, {String? key}) {
  final value = json[key ?? field];
  if (value is! int) {
    throw LevelFormatException('$field must be an integer');
  }
  return value;
}
