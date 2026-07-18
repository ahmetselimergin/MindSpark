/// Difficulty parameters for a procedurally generated level.
final class LevelDifficulty {
  const LevelDifficulty({
    required this.size,
    required this.colors,
    required this.minLen,
  });

  final int size;
  final int colors;
  final int minLen;

  @override
  bool operator ==(Object other) =>
      other is LevelDifficulty &&
      other.size == size &&
      other.colors == colors &&
      other.minLen == minLen;

  @override
  int get hashCode => Object.hash(size, colors, minLen);

  @override
  String toString() => 'LevelDifficulty(size: $size, colors: $colors, minLen: $minLen)';
}

/// First procedurally generated level id (ids <= 10 are hand-authored).
const int kFirstGeneratedLevel = 11;

/// Continuous, capped difficulty curve for generated levels. Picks up where the
/// curated set ends (level 10 is 7x7 with 6 colours) so level 11 is not easier,
/// then grows the board to an 8x8 plateau. Colours stay at the 6-colour palette
/// cap; added difficulty comes from board size and the full-coverage rule.
/// Defined for [id] >= [kFirstGeneratedLevel].
LevelDifficulty difficultyForLevel(int id) {
  assert(id >= kFirstGeneratedLevel, 'difficultyForLevel is for generated ids');
  final t = id - kFirstGeneratedLevel; // id 11 -> 0
  final size = (7 + t ~/ 8).clamp(7, 8); // L11-18: 7x7, L19+: 8x8 (plateau)
  const colors = 6;
  final minLen = size - 2; // 7 -> 5, 8 -> 6
  return LevelDifficulty(size: size, colors: colors, minLen: minLen);
}
