import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/player_progress.dart';

void main() {
  group('PlayerProgress', () {
    test('initial progress uses schema defaults', () {
      const progress = PlayerProgress.initial();

      expect(progress.schemaVersion, 2);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.completedLevelIds, isEmpty);
      expect(progress.totalScore, 0);
      expect(progress.lives, 5);
      expect(progress.livesRegenAnchor, isNull);
      expect(progress.soundEnabled, isTrue);
      expect(progress.vibrationEnabled, isTrue);
    });

    test('round-trips through a map', () {
      final progress = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 4,
        completedLevelIds: {1, 3},
        totalScore: 200,
        lives: 2,
        soundEnabled: false,
        vibrationEnabled: false,
      );

      expect(PlayerProgress.fromMap(progress.toMap()), progress);
    });

    test('strict persisted parsing round-trips and owns completed IDs', () {
      final record = <Object?, Object?>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 3,
        'completedLevelIds': <int>[1, 2],
        'totalScore': 200,
        'lives': 2,
        'soundEnabled': false,
        'vibrationEnabled': true,
      };

      final progress = PlayerProgress.fromPersistedMap(record);
      (record['completedLevelIds']! as List<int>).add(3);

      expect(progress.completedLevelIds, {1, 2});
      expect(() => progress.completedLevelIds.add(3), throwsUnsupportedError);
      expect(PlayerProgress.fromPersistedMap(progress.toMap()), progress);
    });

    test('strict persisted parsing reports the invalid field', () {
      expect(
        () => PlayerProgress.fromPersistedMap({
          'schemaVersion': 1,
          'highestUnlockedLevel': true,
          'completedLevelIds': const <int>[],
          'totalScore': 0,
          'lives': 3,
          'soundEnabled': true,
          'vibrationEnabled': true,
        }),
        throwsA(
          isA<ProgressFormatException>().having(
            (error) => error.field,
            'field',
            'highestUnlockedLevel',
          ),
        ),
      );
    });

    test('strict persisted parsing rejects every malformed record shape', () {
      final valid = <String, Object>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 2,
        'completedLevelIds': const <int>[1],
        'totalScore': 100,
        'lives': 3,
        'soundEnabled': true,
        'vibrationEnabled': true,
      };
      final cases = <(String, Object?)>[
        ('record', 'not a map'),
        ('schemaVersion', {...valid, 'schemaVersion': true}),
        ('schemaVersion', {...valid, 'schemaVersion': 3}),
        ('highestUnlockedLevel', {...valid, 'highestUnlockedLevel': 0}),
        ('completedLevelIds', {...valid, 'completedLevelIds': '1'}),
        (
          'completedLevelIds',
          {
            ...valid,
            'completedLevelIds': [0],
          },
        ),
        (
          'completedLevelIds',
          {
            ...valid,
            'completedLevelIds': [1, 1],
          },
        ),
        (
          'completedLevelIds',
          {
            ...valid,
            'highestUnlockedLevel': 1,
            'completedLevelIds': [2],
          },
        ),
        ('totalScore', {...valid, 'totalScore': -1}),
        ('totalScore', {...valid, 'totalScore': 0}),
        ('lives', {...valid, 'lives': -1}),
        ('lives', {...valid, 'lives': 6}),
        ('soundEnabled', {...valid, 'soundEnabled': 1}),
        ('vibrationEnabled', {...valid, 'vibrationEnabled': null}),
      ];

      for (final (field, record) in cases) {
        expect(
          () => PlayerProgress.fromPersistedMap(record),
          throwsA(
            isA<ProgressFormatException>().having(
              (error) => error.field,
              'field',
              field,
            ),
          ),
          reason: 'record: $record',
        );
      }
    });

    test('strict persisted parsing accepts and owns a set representation', () {
      final callerOwnedIds = <int>{1};
      final progress = PlayerProgress.fromPersistedMap({
        'schemaVersion': 2,
        'highestUnlockedLevel': 1,
        'completedLevelIds': callerOwnedIds,
        'totalScore': 100,
        'lives': 0,
        'soundEnabled': true,
        'vibrationEnabled': false,
      });

      callerOwnedIds
        ..clear()
        ..add(2);

      expect(progress.completedLevelIds, {1});
      expect(progress.lives, 0);
    });

    test('normalizes wrong, corrupt, and negative map values', () {
      final progress = PlayerProgress.fromMap({
        'schemaVersion': -2,
        'highestUnlockedLevel': -9,
        'completedLevelIds': [1, -1, '2', 1, null, 4],
        'totalScore': -100,
        'lives': 'many',
        'soundEnabled': 1,
        'vibrationEnabled': null,
      });

      expect(
        progress,
        PlayerProgress(
          schemaVersion: 1,
          highestUnlockedLevel: 1,
          completedLevelIds: {1, 4},
          totalScore: 0,
          lives: 5,
          soundEnabled: true,
          vibrationEnabled: true,
        ),
      );
      expect(PlayerProgress.fromMap(const {}), const PlayerProgress.initial());
      expect(
        PlayerProgress.fromMap({'completedLevelIds': 'not-a-list'}),
        const PlayerProgress.initial(),
      );
    });

    test('stamps the current schema version (2) on every constructed record', () {
      for (final raw in <Object?>[99, 0, -1, true, false, 1.0, '1', 1]) {
        expect(
          PlayerProgress.fromMap({'schemaVersion': raw}).schemaVersion,
          2,
          reason: 'schemaVersion: $raw',
        );
      }
      expect(
        PlayerProgress(
          schemaVersion: 2,
          highestUnlockedLevel: 1,
          completedLevelIds: const {},
          totalScore: 0,
          lives: 5,
          soundEnabled: true,
          vibrationEnabled: true,
        ).schemaVersion,
        2,
      );
    });

    test('round-trips a v2 record carrying a regen anchor', () {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final record = <Object?, Object?>{
        'schemaVersion': 2,
        'highestUnlockedLevel': 4,
        'completedLevelIds': <int>[1, 2, 3],
        'totalScore': 300,
        'lives': 2,
        'livesRegenAnchor': anchor.millisecondsSinceEpoch,
        'soundEnabled': true,
        'vibrationEnabled': true,
      };

      final progress = PlayerProgress.fromPersistedMap(record);

      expect(progress.lives, 2);
      expect(progress.livesRegenAnchor, anchor);
      expect(PlayerProgress.fromPersistedMap(progress.toMap()), progress);
    });

    test('migrates a persisted v1 record: keeps progress, refills lives to 5', () {
      final progress = PlayerProgress.fromPersistedMap(<Object?, Object?>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 6,
        'completedLevelIds': <int>[1, 2, 3, 4, 5],
        'totalScore': 500,
        'lives': 2,
        'soundEnabled': false,
        'vibrationEnabled': true,
      });

      expect(progress.schemaVersion, 2);
      expect(progress.highestUnlockedLevel, 6);
      expect(progress.completedLevelIds, {1, 2, 3, 4, 5});
      expect(progress.totalScore, 500);
      expect(progress.lives, 5); // refilled
      expect(progress.livesRegenAnchor, isNull);
      expect(progress.soundEnabled, isFalse);
    });

    test('spendLife from full starts the regen clock', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      const full = PlayerProgress.initial(); // 5 lives, no anchor

      final after = full.spendLife(now: now);

      expect(after.lives, 4);
      expect(after.livesRegenAnchor, now);
    });

    test('spendLife below full keeps the running anchor', () {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final later = anchor.add(const Duration(minutes: 3));
      final partial = const PlayerProgress.initial().copyWithLives(
        lives: 3,
        anchor: anchor,
      );

      final after = partial.spendLife(now: later);

      expect(after.lives, 2);
      expect(after.livesRegenAnchor, anchor); // unchanged
    });

    test('spendLife at zero lives is a no-op', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final empty = const PlayerProgress.initial().copyWithLives(
        lives: 0,
        anchor: now,
      );

      expect(empty.spendLife(now: now.add(const Duration(minutes: 1))), empty);
    });

    test('boolean values are not accepted by integer field helpers', () {
      final progress = PlayerProgress.fromMap({
        'schemaVersion': true,
        'highestUnlockedLevel': true,
        'totalScore': false,
        'lives': true,
      });

      expect(progress, const PlayerProgress.initial());
    });

    test('owns completed level IDs supplied by callers', () {
      final callerOwnedIds = <int>{1};
      final progress = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 2,
        completedLevelIds: callerOwnedIds,
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      );
      final equivalent = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 2,
        completedLevelIds: {1},
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      );
      final originalHashCode = progress.hashCode;

      callerOwnedIds
        ..clear()
        ..add(2);

      expect(progress.completedLevelIds, {1});
      expect(progress, equivalent);
      expect(progress.hashCode, originalHashCode);
      expect(
        progress.completeLevel(levelId: 1).totalScore,
        100,
        reason: 'caller mutation must not make a completed level award again',
      );
      expect(() => progress.completedLevelIds.add(3), throwsUnsupportedError);
    });

    test('completion awards once and only explicitly unlocks forward', () {
      const initial = PlayerProgress.initial();

      final first = initial.completeLevel(levelId: 1, nextLevelId: 2);
      final replay = first.completeLevel(levelId: 1, nextLevelId: 2);
      final omittedNext = first.completeLevel(levelId: 2);
      final regressiveNext = first.completeLevel(levelId: 3, nextLevelId: 1);

      expect(first.completedLevelIds, {1});
      expect(first.totalScore, 100);
      expect(first.highestUnlockedLevel, 2);
      expect(replay, first);
      expect(omittedNext.totalScore, 200);
      expect(omittedNext.highestUnlockedLevel, 2);
      expect(regressiveNext.totalScore, 200);
      expect(regressiveNext.highestUnlockedLevel, 2);
    });

    test('a replay can only advance an explicitly greater unlock', () {
      final first = const PlayerProgress.initial().completeLevel(
        levelId: 1,
        nextLevelId: 2,
      );

      final replay = first.completeLevel(levelId: 1, nextLevelId: 5);

      expect(replay.completedLevelIds, {1});
      expect(replay.totalScore, 100);
      expect(replay.highestUnlockedLevel, 5);
    });

    test('invalid completion IDs cannot regress or corrupt progress', () {
      final progress = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 4,
        completedLevelIds: {1},
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      );

      expect(progress.completeLevel(levelId: 0, nextLevelId: 10), progress);
      expect(progress.completeLevel(levelId: -1, nextLevelId: 10), progress);
    });
  });
}
