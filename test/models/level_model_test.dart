import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';

void main() {
  group('LevelModel.fromJson', () {
    test('parses a valid 5x5 level into an immutable point list', () {
      final level = LevelModel.fromJson({
        'id': 1,
        'size': 5,
        'points': [
          {'x': 0, 'y': 0, 'color': 'red'},
          {'x': 4, 'y': 4, 'color': 'red'},
        ],
      });

      expect(level.id, 1);
      expect(level.size, 5);
      expect(level.points.singleWhere((point) => point.x == 4).color, 'red');
      expect(
        () => level.points.add(const GridPoint(x: 1, y: 1, color: 'blue')),
        throwsUnsupportedError,
      );
    });

    test('rejects a point outside the grid bounds', () {
      expect(
        () => LevelModel.fromJson({
          'id': 1,
          'size': 5,
          'points': [
            {'x': 0, 'y': 0, 'color': 'red'},
            {'x': 5, 'y': 4, 'color': 'red'},
          ],
        }),
        throwsA(_formatErrorContaining('points')),
      );
    });

    test('rejects duplicate point coordinates', () {
      expect(
        () => LevelModel.fromJson({
          'id': 1,
          'size': 5,
          'points': [
            {'x': 2, 'y': 2, 'color': 'red'},
            {'x': 2, 'y': 2, 'color': 'red'},
          ],
        }),
        throwsA(_formatErrorContaining('points')),
      );
    });

    test('rejects an empty point list', () {
      expect(
        () => LevelModel.fromJson({'id': 1, 'size': 5, 'points': <Object>[]}),
        throwsA(_formatErrorContaining('points')),
      );
    });

    test('rejects a colour with fewer than two endpoints', () {
      expect(
        () => LevelModel.fromJson({
          'id': 1,
          'size': 5,
          'points': [
            {'x': 0, 'y': 0, 'color': 'red'},
          ],
        }),
        throwsA(_formatErrorContaining('color')),
      );
    });

    test('rejects a colour with more than two endpoints', () {
      expect(
        () => LevelModel.fromJson({
          'id': 1,
          'size': 5,
          'points': [
            {'x': 0, 'y': 0, 'color': 'red'},
            {'x': 1, 'y': 0, 'color': 'red'},
            {'x': 2, 'y': 0, 'color': 'red'},
          ],
        }),
        throwsA(_formatErrorContaining('color')),
      );
    });
  });
}

Matcher _formatErrorContaining(String field) {
  return isA<LevelFormatException>().having(
    (error) => error.message,
    'message',
    contains(field),
  );
}
