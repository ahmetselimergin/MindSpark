import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/player_progress.dart';

void main() {
  group('PlayerProgress', () {
    test('initial progress uses schema defaults', () {
      const progress = PlayerProgress.initial();

      expect(progress.schemaVersion, 1);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.completedLevelIds, isEmpty);
      expect(progress.totalScore, 0);
      expect(progress.lives, 3);
      expect(progress.soundEnabled, isTrue);
      expect(progress.vibrationEnabled, isTrue);
    });

    test('round-trips through a map', () {
      const progress = PlayerProgress(
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
        const PlayerProgress(
          schemaVersion: 1,
          highestUnlockedLevel: 1,
          completedLevelIds: {1, 4},
          totalScore: 0,
          lives: 3,
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
      const progress = PlayerProgress(
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
