import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';
import 'package:mind_spark/features/home/widgets/level_map_view.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

PlayerProgress _progress({
  required int highest,
  Set<int> completed = const {},
  Map<int, int> stars = const {},
  int lives = 3,
  DateTime? anchor,
}) {
  return PlayerProgress(
    schemaVersion: 3,
    highestUnlockedLevel: highest,
    completedLevelIds: completed,
    totalScore: completed.length * 100,
    lives: lives,
    livesRegenAnchor: anchor,
    levelStars: stars,
    soundEnabled: true,
    vibrationEnabled: true,
  );
}

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider
          .overrideWithValue(InMemoryProgressRepository(stored)),
      clockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          AppRoutes.gameplay => Scaffold(
              body: Text('GAMEPLAY ${(settings.arguments as GameplayRouteArgs).levelId}'),
            ),
          AppRoutes.outOfLives => Scaffold(
              body: Text('OUT OF LIVES ${(settings.arguments as OutOfLivesRouteArgs).levelId}'),
            ),
          _ => Consumer(
              builder: (context, ref, _) {
                final ready = ref.watch(appProgressControllerProvider).hasValue;
                return Scaffold(
                  body: ready
                      ? const SizedBox(height: 240, child: LevelMapView())
                      : const SizedBox.shrink(),
                );
              },
            ),
        },
      ),
    ),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders completed, current and locked cards from progress', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(
        highest: 10,
        completed: {for (var i = 1; i <= 9; i++) i},
        stars: {for (var i = 1; i <= 9; i++) i: 3},
      ),
      t0,
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Play'), findsOneWidget); // level 10
    expect(find.bySemanticsLabel('Replay level 9'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 11 locked'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 15 locked'), findsOneWidget);
  });

  testWidgets('tapping the current card opens gameplay for that level', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_progress(highest: 1), t0));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('GAMEPLAY 1'), findsOneWidget);
  });

  testWidgets('tapping a completed card replays it', (tester) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 3, completed: {1, 2}, stars: {1: 3, 2: 2}),
      t0,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Replay level 2'));
    await tester.pumpAndSettle();

    expect(find.text('GAMEPLAY 2'), findsOneWidget);
  });

  testWidgets('locked cards are not tappable', (tester) async {
    await tester.pumpWidget(_harness(_progress(highest: 2, completed: {1}), t0));
    await tester.pumpAndSettle();

    final locked = tester
        .widgetList<LevelCard>(find.byType(LevelCard))
        .where((c) => c.status == LevelCardStatus.locked);
    expect(locked, isNotEmpty);
    expect(locked.every((c) => c.onTap == null), isTrue);
  });

  testWidgets('current tap with zero lives routes to out-of-lives', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 1, lives: 0, anchor: t0),
      t0.add(const Duration(minutes: 1)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('OUT OF LIVES 1'), findsOneWidget);
  });

  testWidgets('celebration badge plays for the flagged level then clears', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 4, completed: {1, 2, 3}, stars: {1: 3, 2: 3, 3: 3}),
      t0,
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LevelMapView)),
    );
    container.read(celebrateLevelProvider.notifier).state = 3;
    await tester.pump(); // map consumes the flag
    await tester.pump();

    expect(find.byType(StatusBadge), findsOneWidget);

    await tester.pumpAndSettle();
    expect(container.read(celebrateLevelProvider), isNull);
    expect(find.byType(StatusBadge), findsNothing);
  });
}
