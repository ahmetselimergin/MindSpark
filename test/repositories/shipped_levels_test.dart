import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/asset_level_repository.dart';

// Called by: `flutter test` runner only (no production code references it).
// No existing test covers the real shipped asset + progression chain;
// asset_level_repository_test.dart uses synthetic fixtures instead.
// Reads assets/levels/levels.json via rootBundle: {id:int, size:int,
// points:[{x:int, y:int, color:String}]}. No date fields.
// User instruction: "buradaki sikintim 3. levelden sonrasina gitmemesi".
//
/// Guards the level pack that actually ships in the app bundle
/// (assets/levels/levels.json), loaded through the real rootBundle path.
///
/// Regression cover for "progression stops after level 3": the pack must
/// expose a contiguous run of levels and let a player advance from the first
/// level all the way to the last.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supportedColors = {
    'red',
    'blue',
    'green',
    'yellow',
    'purple',
    'orange',
  };

  test('ships a contiguous, well-formed level pack', () async {
    final levels = await AssetLevelRepository().loadLevels();

    expect(levels.length, greaterThanOrEqualTo(4), reason: 'needs levels past 3');
    expect(
      levels.map((level) => level.id),
      List<int>.generate(levels.length, (index) => index + 1),
      reason: 'level ids must be contiguous starting at 1',
    );

    for (final level in levels) {
      expect(level.size, greaterThanOrEqualTo(2));
      for (final point in level.points) {
        expect(
          supportedColors,
          contains(point.color),
          reason: 'level ${level.id} uses unsupported color "${point.color}"',
        );
      }
    }
  });

  test('a player can progress through every shipped level to the last', () async {
    final levels = await AssetLevelRepository().loadLevels();

    var progress = const PlayerProgress.initial();
    for (var index = 0; index < levels.length; index++) {
      final levelId = levels[index].id;
      final nextLevelId = index + 1 < levels.length ? levels[index + 1].id : null;

      progress = progress.completeLevel(
        levelId: levelId,
        nextLevelId: nextLevelId,
      );

      expect(progress.completedLevelIds, contains(levelId));
      if (nextLevelId != null) {
        expect(
          progress.highestUnlockedLevel,
          nextLevelId,
          reason: 'completing level $levelId must unlock $nextLevelId',
        );
      }
    }

    final lastLevelId = levels.last.id;
    expect(progress.highestUnlockedLevel, lastLevelId);
    expect(progress.completedLevelIds.length, levels.length);
    expect(progress.totalScore, levels.length * 100);
  });
}
