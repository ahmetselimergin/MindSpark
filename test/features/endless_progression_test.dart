import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/composite_level_source.dart';
import 'package:mind_spark/repositories/level_repository.dart';

class _CuratedRepo implements LevelRepository {
  @override
  Future<LevelModel> levelById(int id) async => LevelModel(
        id: id,
        size: 5,
        points: const [
          GridPoint(x: 0, y: 0, color: 'red'),
          GridPoint(x: 4, y: 4, color: 'red'),
        ],
      );
  @override
  Future<List<LevelModel>> loadLevels() async => const [];
}

void main() {
  test('a player advances past the curated set to level 60', () async {
    final source = CompositeLevelSource(repository: _CuratedRepo());
    var progress = const PlayerProgress.initial();

    for (var id = 1; id <= 60; id++) {
      final level = await source.levelById(id); // must not throw for any id
      expect(level.id, id);
      progress = progress.completeLevel(levelId: id, nextLevelId: id + 1);
    }

    expect(progress.highestUnlockedLevel, 61);
    expect(progress.completedLevelIds.length, 60);
    expect(progress.totalScore, 6000);
  });
}
