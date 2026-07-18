import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/generation/level_difficulty.dart';

void main() {
  test('continues from the curated set then plateaus at 8x8', () {
    // Level 11 must not be easier than curated level 10 (7x7, 6 colours).
    expect(difficultyForLevel(11), const LevelDifficulty(size: 7, colors: 6, minLen: 5));
    expect(difficultyForLevel(18), const LevelDifficulty(size: 7, colors: 6, minLen: 5));
    expect(difficultyForLevel(19), const LevelDifficulty(size: 8, colors: 6, minLen: 6));
    expect(difficultyForLevel(47), const LevelDifficulty(size: 8, colors: 6, minLen: 6));
  });

  test('is monotonic and plateaus at 8/6/6', () {
    var prev = difficultyForLevel(11);
    for (var id = 12; id <= 400; id++) {
      final d = difficultyForLevel(id);
      expect(d.size, greaterThanOrEqualTo(prev.size));
      expect(d.colors, greaterThanOrEqualTo(prev.colors));
      expect(d.minLen, greaterThanOrEqualTo(prev.minLen));
      expect(d.size, lessThanOrEqualTo(8));
      expect(d.colors, lessThanOrEqualTo(6));
      expect(d.minLen, lessThanOrEqualTo(6));
      prev = d;
    }
    expect(difficultyForLevel(400), const LevelDifficulty(size: 8, colors: 6, minLen: 6));
  });
}
