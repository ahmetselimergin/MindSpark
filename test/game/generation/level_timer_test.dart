import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/generation/level_timer.dart';

void main() {
  group('levelTimeLimit', () {
    test('reference board sizes', () {
      expect(levelTimeLimit(5), const Duration(seconds: 60)); // 20 + 25*1.6
      expect(levelTimeLimit(7), const Duration(seconds: 98)); // 20 + 49*1.6
      expect(levelTimeLimit(8), const Duration(seconds: 122)); // 20 + 64*1.6
    });

    test('never below the 45s floor', () {
      expect(levelTimeLimit(2).inSeconds, greaterThanOrEqualTo(45));
      expect(levelTimeLimit(3).inSeconds, greaterThanOrEqualTo(45));
    });

    test('is monotonic non-decreasing in board size', () {
      for (var size = 2; size < 12; size++) {
        expect(
          levelTimeLimit(size + 1).inSeconds,
          greaterThanOrEqualTo(levelTimeLimit(size).inSeconds),
          reason: 'size $size -> ${size + 1}',
        );
      }
    });
  });
}
