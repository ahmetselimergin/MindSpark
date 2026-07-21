import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

LevelModel _level(int id) => LevelModel(
  id: id,
  size: 5,
  points: const [
    GridPoint(x: 0, y: 0, color: 'red'),
    GridPoint(x: 4, y: 4, color: 'red'),
  ],
);

final class _GameHarness {
  VoidCallback? onAllPairsConnected;

  MindSparkGame create(
    LevelModel level,
    VoidCallback onCompleted,
    VoidCallback onAllPairsConnectedCb,
  ) {
    onAllPairsConnected = onAllPairsConnectedCb;
    return MindSparkGame(
      level: level,
      onCompleted: onCompleted,
      onAllPairsConnected: onAllPairsConnectedCb,
    );
  }
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  Widget app(_GameHarness harness, ProgressRepository repo) => ProviderScope(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => t0),
      levelByIdProvider(3).overrideWith((ref) async => _level(3)),
      levelTimerProvider.overrideWithValue((_) => const Duration(seconds: 60)),
      mindSparkGameFactoryProvider.overrideWithValue(harness.create),
    ],
    child: const MaterialApp(home: GameplayScreen(levelId: 3)),
  );

  testWidgets('shows the banner slot and no static hint during gameplay', (
    tester,
  ) async {
    final harness = _GameHarness();
    final repo = InMemoryProgressRepository(
      const PlayerProgress.initial()
          .copyWith(highestUnlockedLevel: 3)
          .copyWithLives(lives: 3, anchor: t0),
    );
    await tester.pumpWidget(app(harness, repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Connect matching sparks to fill the board.'), findsNothing);
    expect(find.byType(AdWidget), findsNothing); // ads are no-op under test
  });

  testWidgets('flashes the stuck hint when all pairs connect but board unfilled', (
    tester,
  ) async {
    final harness = _GameHarness();
    final repo = InMemoryProgressRepository(
      const PlayerProgress.initial()
          .copyWith(highestUnlockedLevel: 3)
          .copyWithLives(lives: 3, anchor: t0),
    );
    await tester.pumpWidget(app(harness, repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('All linked — now fill every square!'), findsNothing);

    harness.onAllPairsConnected!.call();
    await tester.pump(); // screen setState → new trigger
    await tester.pump(const Duration(milliseconds: 100)); // fade-in underway
    expect(find.text('All linked — now fill every square!'), findsOneWidget);
  });
}
