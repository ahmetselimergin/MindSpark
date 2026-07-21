import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/image_button.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/features/out_of_lives/out_of_lives_screen.dart';
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

// level 3 unlocked so GameplayScreen(levelId: 3) is playable.
PlayerProgress _stored({required int lives, DateTime? anchor}) =>
    const PlayerProgress.initial()
        .copyWith(highestUnlockedLevel: 3)
        .copyWithLives(lives: lives, anchor: anchor);

// Real MindSparkGame is created via the default factory (it is a final class).
// Timeout is driven by the screen's own countdown, independent of the game.
Widget _directApp(DateTime now, ProgressRepository repo) => ProviderScope(
  overrides: [
    progressRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => now),
    levelByIdProvider(3).overrideWith((ref) async => _level(3)),
    levelTimerProvider.overrideWithValue((_) => const Duration(seconds: 2)),
  ],
  child: const MaterialApp(home: GameplayScreen(levelId: 3)),
);

Widget _routedApp(DateTime now, ProgressRepository repo) => ProviderScope(
  overrides: [
    progressRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => now),
    levelByIdProvider(3).overrideWith((ref) async => _level(3)),
    levelTimerProvider.overrideWithValue((_) => const Duration(seconds: 2)),
  ],
  child: MaterialApp(
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.outOfLives => const OutOfLivesScreen(levelId: 3),
        _ => const GameplayScreen(levelId: 3),
      },
    ),
  ),
);

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('timeout spends a life and shows a retry/home dialog', (
    tester,
  ) async {
    final repo = InMemoryProgressRepository(_stored(lives: 3));
    await tester.pumpWidget(_directApp(t0, repo));
    await tester.pump(); // resolve providers, build game + start timer
    await tester.pump(const Duration(seconds: 3)); // elapse past the 2s limit
    // Flame renders continuously, so pumpAndSettle never settles here; use
    // fixed pumps to flush the spendLife save and show the dialog.
    await tester.pump();
    await tester.pump();

    expect(repo.value.lives, 2); // a life was spent
    expect(find.text('HOME'), findsOneWidget); // dialog is up
    expect(
      find.byWidgetPredicate(
        (w) => w is ImageButton && w.semanticLabel == 'Retry',
      ),
      findsOneWidget,
    ); // the RETRY button in the dialog

  });

  testWidgets('expiry on the last life routes to Out-of-Lives', (tester) async {
    await tester.pumpWidget(
      _routedApp(t0, InMemoryProgressRepository(_stored(lives: 1, anchor: t0))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(OutOfLivesScreen), findsOneWidget);
  });

  testWidgets('entering with zero lives redirects to Out-of-Lives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routedApp(
        t0.add(const Duration(minutes: 1)),
        InMemoryProgressRepository(_stored(lives: 0, anchor: t0)),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OutOfLivesScreen), findsOneWidget);
  });
}
