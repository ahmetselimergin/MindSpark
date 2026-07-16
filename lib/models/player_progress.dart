final class PlayerProgress {
  const PlayerProgress({
    required this.schemaVersion,
    required this.highestUnlockedLevel,
    required this.completedLevelIds,
    required this.totalScore,
    required this.lives,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  const PlayerProgress.initial()
    : schemaVersion = 1,
      highestUnlockedLevel = 1,
      completedLevelIds = const <int>{},
      totalScore = 0,
      lives = 3,
      soundEnabled = true,
      vibrationEnabled = true;

  factory PlayerProgress.fromMap(Map<Object?, Object?> map) {
    final completedLevelIds = <int>{};
    final rawCompletedLevelIds = map['completedLevelIds'];
    if (rawCompletedLevelIds is Iterable<Object?>) {
      completedLevelIds.addAll(
        rawCompletedLevelIds.whereType<int>().where((id) => id > 0),
      );
    }

    return PlayerProgress(
      schemaVersion: _positiveInt(map['schemaVersion'], fallback: 1),
      highestUnlockedLevel: _positiveInt(
        map['highestUnlockedLevel'],
        fallback: 1,
      ),
      completedLevelIds: Set<int>.unmodifiable(completedLevelIds),
      totalScore: _nonNegativeInt(map['totalScore'], fallback: 0),
      lives: _nonNegativeInt(map['lives'], fallback: 3),
      soundEnabled: map['soundEnabled'] is bool
          ? map['soundEnabled']! as bool
          : true,
      vibrationEnabled: map['vibrationEnabled'] is bool
          ? map['vibrationEnabled']! as bool
          : true,
    );
  }

  final int schemaVersion;
  final int highestUnlockedLevel;
  final Set<int> completedLevelIds;
  final int totalScore;
  final int lives;
  final bool soundEnabled;
  final bool vibrationEnabled;

  Map<String, Object> toMap() {
    final sortedCompletedLevelIds = completedLevelIds.toList()..sort();
    return {
      'schemaVersion': schemaVersion,
      'highestUnlockedLevel': highestUnlockedLevel,
      'completedLevelIds': sortedCompletedLevelIds,
      'totalScore': totalScore,
      'lives': lives,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  PlayerProgress completeLevel({required int levelId, int? nextLevelId}) {
    if (levelId <= 0) {
      return this;
    }

    final isFirstCompletion = !completedLevelIds.contains(levelId);
    final unlocksNextLevel =
        nextLevelId != null && nextLevelId > highestUnlockedLevel;
    if (!isFirstCompletion && !unlocksNextLevel) {
      return this;
    }

    final updatedCompletedLevelIds = isFirstCompletion
        ? {...completedLevelIds, levelId}
        : completedLevelIds;
    final updatedHighestUnlockedLevel = unlocksNextLevel
        ? nextLevelId
        : highestUnlockedLevel;

    return PlayerProgress(
      schemaVersion: schemaVersion,
      highestUnlockedLevel: updatedHighestUnlockedLevel,
      completedLevelIds: Set<int>.unmodifiable(updatedCompletedLevelIds),
      totalScore: totalScore + (isFirstCompletion ? 100 : 0),
      lives: lives,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlayerProgress &&
            schemaVersion == other.schemaVersion &&
            highestUnlockedLevel == other.highestUnlockedLevel &&
            _setsEqual(completedLevelIds, other.completedLevelIds) &&
            totalScore == other.totalScore &&
            lives == other.lives &&
            soundEnabled == other.soundEnabled &&
            vibrationEnabled == other.vibrationEnabled;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    highestUnlockedLevel,
    Object.hashAllUnordered(completedLevelIds),
    totalScore,
    lives,
    soundEnabled,
    vibrationEnabled,
  );
}

int _positiveInt(Object? value, {required int fallback}) {
  return value is int && value > 0 ? value : fallback;
}

int _nonNegativeInt(Object? value, {required int fallback}) {
  return value is int && value >= 0 ? value : fallback;
}

bool _setsEqual(Set<int> first, Set<int> second) {
  return first.length == second.length && first.containsAll(second);
}
