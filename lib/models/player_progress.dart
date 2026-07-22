import 'package:mind_spark/game/domain/lives_state.dart';

final class PlayerProgress {
  factory PlayerProgress({
    required int schemaVersion,
    required int highestUnlockedLevel,
    required Set<int> completedLevelIds,
    required int totalScore,
    required int lives,
    DateTime? livesRegenAnchor,
    Map<int, int> levelStars = const <int, int>{},
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    return PlayerProgress._(
      schemaVersion: _schemaVersion(schemaVersion),
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: Set<int>.unmodifiable(completedLevelIds),
      totalScore: totalScore,
      lives: lives,
      livesRegenAnchor: livesRegenAnchor,
      levelStars: Map<int, int>.unmodifiable(levelStars),
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }

  const PlayerProgress._({
    required this.schemaVersion,
    required this.highestUnlockedLevel,
    required this.completedLevelIds,
    required this.totalScore,
    required this.lives,
    required this.livesRegenAnchor,
    required this.levelStars,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  const PlayerProgress.initial()
    : this._(
        schemaVersion: 3,
        highestUnlockedLevel: 1,
        completedLevelIds: const <int>{},
        totalScore: 0,
        lives: LivesRegen.maxLives,
        livesRegenAnchor: null,
        levelStars: const <int, int>{},
        soundEnabled: true,
        vibrationEnabled: true,
      );

  factory PlayerProgress.fromMap(Map<Object?, Object?> map) {
    final completedLevelIds = <int>{};
    final rawCompletedLevelIds = map['completedLevelIds'];
    if (rawCompletedLevelIds is Iterable<Object?>) {
      completedLevelIds.addAll(
        rawCompletedLevelIds.whereType<int>().where((id) => id > 0),
      );
    }

    return PlayerProgress(
      schemaVersion: _schemaVersion(map['schemaVersion']),
      highestUnlockedLevel: _positiveInt(
        map['highestUnlockedLevel'],
        fallback: 1,
      ),
      completedLevelIds: Set<int>.unmodifiable(completedLevelIds),
      totalScore: _nonNegativeInt(map['totalScore'], fallback: 0),
      lives: _boundedLives(map['lives']),
      livesRegenAnchor: _anchorFromMillis(map['livesRegenAnchor']),
      levelStars: _lenientLevelStars(map['levelStars']),
      soundEnabled: map['soundEnabled'] is bool
          ? map['soundEnabled']! as bool
          : true,
      vibrationEnabled: map['vibrationEnabled'] is bool
          ? map['vibrationEnabled']! as bool
          : true,
    );
  }

  factory PlayerProgress.fromPersistedMap(Object? record) {
    if (record is! Map) {
      throw const ProgressFormatException(
        field: 'record',
        message: 'must be a map',
      );
    }

    final schemaVersion = _requiredInt(record, 'schemaVersion');
    if (schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) {
      throw const ProgressFormatException(
        field: 'schemaVersion',
        message: 'must be 1, 2, or 3',
      );
    }

    final highestUnlockedLevel = _requiredInt(record, 'highestUnlockedLevel');
    if (highestUnlockedLevel < 1) {
      throw const ProgressFormatException(
        field: 'highestUnlockedLevel',
        message: 'must be at least 1',
      );
    }

    final completedLevelIds = _requiredCompletedLevelIds(record);
    if (completedLevelIds.any((id) => id > highestUnlockedLevel)) {
      throw const ProgressFormatException(
        field: 'completedLevelIds',
        message: 'cannot contain an ID above highestUnlockedLevel',
      );
    }

    final totalScore = _requiredInt(record, 'totalScore');
    if (totalScore < 0 || totalScore != completedLevelIds.length * 100) {
      throw const ProgressFormatException(
        field: 'totalScore',
        message: 'must equal 100 per completed level',
      );
    }

    final lives = _requiredInt(record, 'lives');
    if (lives < 0 || lives > LivesRegen.maxLives) {
      throw ProgressFormatException(
        field: 'lives',
        message: 'must be between 0 and ${LivesRegen.maxLives}',
      );
    }

    // v1 records predate lives regen: give a full tank and preserve progress.
    final migratedLives = schemaVersion == 1 ? LivesRegen.maxLives : lives;
    final anchor = schemaVersion == 1
        ? null
        : _persistedAnchor(record, migratedLives);
    // levelStars arrived in v3; earlier records start empty.
    final levelStars = schemaVersion == 3
        ? _requiredLevelStars(record, completedLevelIds)
        : const <int, int>{};

    return PlayerProgress(
      schemaVersion: 3,
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: completedLevelIds,
      totalScore: totalScore,
      lives: migratedLives,
      livesRegenAnchor: anchor,
      levelStars: levelStars,
      soundEnabled: _requiredBool(record, 'soundEnabled'),
      vibrationEnabled: _requiredBool(record, 'vibrationEnabled'),
    );
  }

  final int schemaVersion;
  final int highestUnlockedLevel;
  final Set<int> completedLevelIds;
  final int totalScore;
  final int lives;
  final DateTime? livesRegenAnchor;
  final Map<int, int> levelStars;
  final bool soundEnabled;
  final bool vibrationEnabled;

  Map<String, Object> toMap() {
    final sortedCompletedLevelIds = completedLevelIds.toList()..sort();
    final map = <String, Object>{
      'schemaVersion': 3,
      'highestUnlockedLevel': highestUnlockedLevel,
      'completedLevelIds': sortedCompletedLevelIds,
      'totalScore': totalScore,
      'lives': lives,
      'levelStars': <int, int>{
        for (final entry in levelStars.entries) entry.key: entry.value,
      },
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
    final anchor = livesRegenAnchor;
    if (anchor != null) {
      map['livesRegenAnchor'] = anchor.toUtc().millisecondsSinceEpoch;
    }
    return map;
  }

  PlayerProgress copyWith({
    int? highestUnlockedLevel,
    Set<int>? completedLevelIds,
    int? totalScore,
    int? lives,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return PlayerProgress(
      schemaVersion: schemaVersion,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      completedLevelIds: completedLevelIds ?? this.completedLevelIds,
      totalScore: totalScore ?? this.totalScore,
      lives: lives ?? this.lives,
      livesRegenAnchor: livesRegenAnchor,
      levelStars: levelStars,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  /// Resolves legacy saves that still point at a level already completed.
  ///
  /// Progression is sequential, so advancing stops at the first unfinished
  /// positive ID. No score, completion, life, star, or settings data changes.
  PlayerProgress reconcileCurrentLevel() {
    var currentLevel = highestUnlockedLevel;
    while (completedLevelIds.contains(currentLevel)) {
      currentLevel++;
    }
    return currentLevel == highestUnlockedLevel
        ? this
        : copyWith(highestUnlockedLevel: currentLevel);
  }

  /// Copies the record while setting both the life count and the regen anchor —
  /// including back to `null`, which the general [copyWith] cannot express.
  PlayerProgress copyWithLives({required int lives, required DateTime? anchor}) {
    return PlayerProgress(
      schemaVersion: schemaVersion,
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: completedLevelIds,
      totalScore: totalScore,
      lives: lives,
      livesRegenAnchor: anchor,
      levelStars: levelStars,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }

  /// Consumes one life. From a full tank this starts the regen clock at [now];
  /// below full it keeps the running anchor. A no-op at zero lives.
  PlayerProgress spendLife({required DateTime now}) {
    if (lives <= 0) {
      return this;
    }
    final startsClock = lives >= LivesRegen.maxLives;
    return copyWithLives(
      lives: lives - 1,
      anchor: startsClock ? now.toUtc() : livesRegenAnchor,
    );
  }

  PlayerProgress completeLevel({
    required int levelId,
    int? nextLevelId,
    int? stars,
  }) {
    if (levelId <= 0) {
      return this;
    }

    final isFirstCompletion = !completedLevelIds.contains(levelId);
    final unlocksNextLevel =
        nextLevelId != null && nextLevelId > highestUnlockedLevel;
    final newStars = stars?.clamp(1, 3);
    final improvesStars =
        newStars != null && newStars > (levelStars[levelId] ?? 0);
    if (!isFirstCompletion && !unlocksNextLevel && !improvesStars) {
      return this;
    }

    final updatedCompletedLevelIds = isFirstCompletion
        ? {...completedLevelIds, levelId}
        : completedLevelIds;
    final updatedHighestUnlockedLevel = unlocksNextLevel
        ? nextLevelId
        : highestUnlockedLevel;
    final updatedLevelStars = newStars == null
        ? levelStars
        : {
            ...levelStars,
            levelId: newStars > (levelStars[levelId] ?? 0)
                ? newStars
                : levelStars[levelId]!,
          };

    return PlayerProgress(
      schemaVersion: schemaVersion,
      highestUnlockedLevel: updatedHighestUnlockedLevel,
      completedLevelIds: Set<int>.unmodifiable(updatedCompletedLevelIds),
      totalScore: totalScore + (isFirstCompletion ? 100 : 0),
      lives: lives,
      livesRegenAnchor: livesRegenAnchor,
      levelStars: Map<int, int>.unmodifiable(updatedLevelStars),
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
            livesRegenAnchor == other.livesRegenAnchor &&
            _levelStarsEqual(levelStars, other.levelStars) &&
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
    livesRegenAnchor,
    Object.hashAllUnordered(
      levelStars.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    soundEnabled,
    vibrationEnabled,
  );
}

final class ProgressFormatException implements Exception {
  const ProgressFormatException({required this.field, required this.message});

  final String field;
  final String message;

  @override
  String toString() => 'ProgressFormatException($field): $message';
}

int _requiredInt(Map<Object?, Object?> map, String field) {
  final value = map[field];
  if (value is! int) {
    throw ProgressFormatException(field: field, message: 'must be an integer');
  }
  return value;
}

bool _requiredBool(Map<Object?, Object?> map, String field) {
  final value = map[field];
  if (value is! bool) {
    throw ProgressFormatException(field: field, message: 'must be a boolean');
  }
  return value;
}

Set<int> _requiredCompletedLevelIds(Map<Object?, Object?> map) {
  final value = map['completedLevelIds'];
  if (value is! List && value is! Set) {
    throw const ProgressFormatException(
      field: 'completedLevelIds',
      message: 'must be a list or set',
    );
  }

  final ids = <int>{};
  for (final id in value as Iterable<Object?>) {
    if (id is! int || id <= 0) {
      throw const ProgressFormatException(
        field: 'completedLevelIds',
        message: 'must contain only positive integers',
      );
    }
    if (!ids.add(id)) {
      throw const ProgressFormatException(
        field: 'completedLevelIds',
        message: 'must contain unique IDs',
      );
    }
  }
  return Set<int>.unmodifiable(ids);
}

int _positiveInt(Object? value, {required int fallback}) {
  return value is int && value > 0 ? value : fallback;
}

/// The current persisted schema version. Every constructed record is stamped
/// with it, so in-memory objects always speak the latest schema.
int _schemaVersion(Object? value) => 3;

int _boundedLives(Object? value) => value is int
    ? value.clamp(0, LivesRegen.maxLives)
    : LivesRegen.maxLives;

DateTime? _anchorFromMillis(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : null;

DateTime? _persistedAnchor(Map<Object?, Object?> record, int lives) {
  final raw = record['livesRegenAnchor'];
  if (lives >= LivesRegen.maxLives) {
    return null; // full ⇒ no regen in progress
  }
  if (raw == null) {
    return null; // healed to `now` on first reconcile
  }
  if (raw is! int) {
    throw const ProgressFormatException(
      field: 'livesRegenAnchor',
      message: 'must be an integer or absent',
    );
  }
  return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
}

/// Strict parse of a v3 `levelStars` map: positive completed-level keys mapping
/// to 1..3. Accepts int or numeric-string keys (Hive/JSON round-trips).
Map<int, int> _requiredLevelStars(
  Map<Object?, Object?> record,
  Set<int> completed,
) {
  final raw = record['levelStars'];
  if (raw == null) {
    return const <int, int>{};
  }
  if (raw is! Map) {
    throw const ProgressFormatException(
      field: 'levelStars',
      message: 'must be a map',
    );
  }
  final out = <int, int>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final levelId = key is int ? key : int.tryParse('$key');
    final value = entry.value;
    if (levelId == null ||
        levelId <= 0 ||
        value is! int ||
        value < 1 ||
        value > 3 ||
        !completed.contains(levelId)) {
      throw const ProgressFormatException(
        field: 'levelStars',
        message: 'keys must be completed level ids, values 1..3',
      );
    }
    out[levelId] = value;
  }
  return Map<int, int>.unmodifiable(out);
}

/// Lenient parse for [PlayerProgress.fromMap]: silently drops bad entries.
Map<int, int> _lenientLevelStars(Object? value) {
  if (value is! Map) {
    return const <int, int>{};
  }
  final out = <int, int>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final levelId = key is int ? key : int.tryParse('$key');
    final v = entry.value;
    if (levelId != null && levelId > 0 && v is int && v >= 1 && v <= 3) {
      out[levelId] = v;
    }
  }
  return Map<int, int>.unmodifiable(out);
}

int _nonNegativeInt(Object? value, {required int fallback}) {
  return value is int && value >= 0 ? value : fallback;
}

bool _setsEqual(Set<int> first, Set<int> second) {
  return first.length == second.length && first.containsAll(second);
}

bool _levelStarsEqual(Map<int, int> first, Map<int, int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
