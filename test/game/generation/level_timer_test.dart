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

  group('starsForResult', () {
    Duration s(int n) => Duration(seconds: n);
    test('thresholds', () {
      expect(starsForResult(remaining: s(70), timeLimit: s(100)), 3);
      expect(starsForResult(remaining: s(69), timeLimit: s(100)), 2);
      expect(starsForResult(remaining: s(40), timeLimit: s(100)), 2);
      expect(starsForResult(remaining: s(39), timeLimit: s(100)), 1);
      expect(starsForResult(remaining: s(0), timeLimit: s(100)), 1);
    });
    test('full time is 3 stars', () {
      expect(starsForResult(remaining: s(100), timeLimit: s(100)), 3);
    });
    test('zero or negative limit yields 1', () {
      expect(starsForResult(remaining: s(0), timeLimit: Duration.zero), 1);
    });
    test('clamps over-full remaining to 3', () {
      expect(starsForResult(remaining: s(200), timeLimit: s(100)), 3);
    });
  });
}
