/// Difficulty parameters for a procedurally generated level.
class LevelDifficulty {
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

/// Monotone, capped difficulty curve. Defined for [id] >= [kFirstGeneratedLevel].
LevelDifficulty difficultyForLevel(int id) {
  final t = id - kFirstGeneratedLevel; // id 11 -> 0
  final size = (5 + t ~/ 8).clamp(5, 8);
  final colors = (4 + t ~/ 8).clamp(4, 6);
  final minLen = (3 + t ~/ 12).clamp(3, 6);
  return LevelDifficulty(size: size, colors: colors, minLen: minLen);
}
