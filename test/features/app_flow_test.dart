import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/level_repository.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  testWidgets('play opens the current level and restart resets its game', (
    tester,
  ) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);

    expect(find.text('Level 1'), findsWidgets);
    expect(find.text('RESTART'), findsOneWidget);
    expect(harness.games, hasLength(1));

    final game = harness.games.single;
    game.onGameResize(Vector2.all(100));
    expect(game.handlePointerStart(Vector2.all(25)), isTrue);
    expect(game.snapshot.paths['blue']?.cells, hasLength(1));

    await tester.tap(find.text('RESTART'));
    await tester.pump();

    expect(game.snapshot.paths['blue'], isNull);
    expect(harness.games, hasLength(1));
  });

  testWidgets('first completion awards 100 and next follows repository order', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository();
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);

    harness.completeLatest();
    await _pumpRoute(tester);

    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(progress.saved.single.completedLevelIds, {1});
    expect(find.text('NEXT LEVEL'), findsOneWidget);

    await tester.tap(find.text('NEXT LEVEL'));
    await _pumpRoute(tester);

    expect(find.text('Level 5'), findsOneWidget);
    expect(harness.games, hasLength(2));
  });

  testWidgets('replaying a completed level awards zero', (tester) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository(
      PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 1,
        completedLevelIds: {1},
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      ),
    );
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);

    harness.completeLatest();
    await _pumpRoute(tester);

    expect(find.text('+0'), findsOneWidget);
    expect(progress.saved.single.totalScore, 100);
  });

  testWidgets('save failure stays on gameplay and retry navigates once', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository()..failNextSave = true;
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);

    harness.completeLatest();
    harness.completeLatest();
    await _pumpRoute(tester);

    expect(find.text('Progress was not saved.'), findsOneWidget);
    expect(find.text('RETRY SAVE'), findsOneWidget);
    expect(find.text('LEVEL COMPLETE'), findsNothing);
    expect(progress.attempts, hasLength(1));

    await tester.tap(find.text('RETRY SAVE'));
    await _pumpRoute(tester);

    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(progress.attempts, hasLength(2));
    expect(progress.saved, hasLength(1));
    expect(identical(progress.attempts[0], progress.attempts[1]), isTrue);
    expect(progress.saved.single.completedLevelIds, {1});
  });

  testWidgets('no-op save retry does not navigate without a candidate', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository()..failNextSave = true;
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    harness.completeLatest();
    await _pumpRoute(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameplayScreen)),
    );
    container.invalidate(appProgressControllerProvider);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('RETRY SAVE'));
    await _pumpRoute(tester);

    expect(find.text('LEVEL COMPLETE'), findsNothing);
    expect(find.text('Progress must be loaded again.'), findsOneWidget);
    expect(find.text('RETRY PROGRESS'), findsOneWidget);
    expect(progress.attempts, hasLength(1));
  });

  testWidgets('save retry does not navigate while progress is loading', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository()..failNextSave = true;
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    harness.completeLatest();
    await _pumpRoute(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameplayScreen)),
    );
    final reload = Completer<PlayerProgress>();
    progress.nextLoad = reload;
    container.invalidate(appProgressControllerProvider);
    await tester.pump();
    await tester.tap(find.text('RETRY SAVE'));
    await _pumpRoute(tester);

    expect(find.text('LEVEL COMPLETE'), findsNothing);
    expect(find.text('Progress must be loaded again.'), findsOneWidget);
    expect(progress.attempts, hasLength(1));

    reload.complete(progress.value);
    await tester.pump();
    await tester.pump();
  });

  testWidgets('save retry does not navigate after progress load error', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository()..failNextSave = true;
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    harness.completeLatest();
    await _pumpRoute(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameplayScreen)),
    );
    progress.failNextLoad = true;
    container.invalidate(appProgressControllerProvider);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('RETRY SAVE'));
    await _pumpRoute(tester);

    expect(find.text('LEVEL COMPLETE'), findsNothing);
    expect(find.text('Progress must be loaded again.'), findsOneWidget);
    expect(find.text('RETRY PROGRESS'), findsOneWidget);
    expect(progress.attempts, hasLength(1));
  });

  testWidgets('finishing the final repository level returns home', (
    tester,
  ) async {
    final harness = _GameHarness();
    final progress = _RecordingProgressRepository(
      PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 5,
        completedLevelIds: {1},
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      ),
    );
    await tester.pumpWidget(
      _testApp(harness: harness, progressRepository: progress),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);

    harness.completeLatest();
    await _pumpRoute(tester);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsNothing);

    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('Best Score: 200'), findsOneWidget);
  });

  testWidgets('invalid gameplay arguments show a safe error page', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _testApp(harness: _GameHarness(), navigatorKey: navigatorKey),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pushNamed(
      AppRoutes.gameplay,
      arguments: const ResultRouteArgs(levelId: 1, awardedScore: 100),
    );
    await tester.pumpAndSettle();

    expect(find.text('This screen could not be opened.'), findsOneWidget);
  });

  testWidgets('existing but locked gameplay level is rejected', (tester) async {
    final harness = _GameHarness();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _testApp(harness: harness, navigatorKey: navigatorKey),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pushNamed(
      AppRoutes.gameplay,
      arguments: const GameplayRouteArgs(5),
    );
    await _pumpRoute(tester);

    expect(find.text('This level could not be opened.'), findsOneWidget);
    expect(harness.games, isEmpty);
  });

  testWidgets('missing gameplay level is rejected', (tester) async {
    final harness = _GameHarness();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _testApp(harness: harness, navigatorKey: navigatorKey),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pushNamed(
      AppRoutes.gameplay,
      arguments: const GameplayRouteArgs(99),
    );
    await _pumpRoute(tester);

    expect(find.text('This level could not be opened.'), findsOneWidget);
    expect(harness.games, isEmpty);
  });

  testWidgets('home reports saved highest level missing from assets', (
    tester,
  ) async {
    final progress = _RecordingProgressRepository(
      PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 3,
        completedLevelIds: const {1},
        totalScore: 100,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: true,
      ),
    );
    await tester.pumpWidget(
      _testApp(harness: _GameHarness(), progressRepository: progress),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Saved progress does not match the available levels.'),
      findsOneWidget,
    );
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  testWidgets('missing result level offers a Home action', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _testApp(harness: _GameHarness(), navigatorKey: navigatorKey),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pushNamed(
      AppRoutes.result,
      arguments: const ResultRouteArgs(levelId: 99, awardedScore: 100),
    );
    await _pumpRoute(tester);

    expect(find.text('This result could not be opened.'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Home fits 320x568 at 2x text scale', (tester) async {
    _useCompactLargeTextView(tester);
    await tester.pumpWidget(_testApp(harness: _GameHarness()));
    await tester.pumpAndSettle();

    expect(find.text('PLAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gameplay fits 320x568 at 2x text scale', (tester) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    tester.takeException();
    _useCompactLargeTextView(tester);
    await tester.pump();

    expect(find.text('RESTART'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Result fits 320x568 at 2x text scale', (tester) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    harness.completeLatest();
    await _pumpRoute(tester);
    tester.takeException();
    _useCompactLargeTextView(tester);
    await tester.pump();

    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid Play callback creates one gameplay route', (tester) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();

    final play = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'PLAY'),
    );
    play.onPressed!();
    play.onPressed!();
    await _pumpRoute(tester);

    expect(harness.games, hasLength(1));
  });

  testWidgets('rapid Next callback creates one next-level game', (
    tester,
  ) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY'));
    await _pumpRoute(tester);
    harness.completeLatest();
    await _pumpRoute(tester);

    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'NEXT LEVEL'),
    );
    next.onPressed!();
    next.onPressed!();
    await _pumpRoute(tester);

    expect(harness.games, hasLength(2));
  });
}

void _useCompactLargeTextView(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _testApp({
  required _GameHarness harness,
  ProgressRepository? progressRepository,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return ProviderScope(
    overrides: [
      levelRepositoryProvider.overrideWithValue(_TestLevelRepository()),
      progressRepositoryProvider.overrideWithValue(
        progressRepository ?? _RecordingProgressRepository(),
      ),
      mindSparkGameFactoryProvider.overrideWithValue(harness.create),
    ],
    child: MindSparkApp(navigatorKey: navigatorKey),
  );
}

final class _GameHarness {
  final List<MindSparkGame> games = [];
  final List<VoidCallback> completions = [];

  MindSparkGame create(LevelModel level, VoidCallback onCompleted) {
    completions.add(onCompleted);
    final game = MindSparkGame(level: level, onCompleted: onCompleted);
    games.add(game);
    return game;
  }

  void completeLatest() => completions.last();
}

final class _TestLevelRepository implements LevelRepository {
  static final levels = [
    const LevelModel(
      id: 1,
      size: 2,
      points: [
        GridPoint(x: 0, y: 0, color: 'blue'),
        GridPoint(x: 1, y: 1, color: 'blue'),
      ],
    ),
    const LevelModel(
      id: 5,
      size: 2,
      points: [
        GridPoint(x: 0, y: 1, color: 'yellow'),
        GridPoint(x: 1, y: 0, color: 'yellow'),
      ],
    ),
  ];

  @override
  Future<List<LevelModel>> loadLevels() async => levels;

  @override
  Future<LevelModel> levelById(int id) async =>
      levels.firstWhere((level) => level.id == id);
}

final class _RecordingProgressRepository implements ProgressRepository {
  _RecordingProgressRepository([this.value = const PlayerProgress.initial()]);

  PlayerProgress value;
  bool failNextSave = false;
  bool failNextLoad = false;
  Completer<PlayerProgress>? nextLoad;
  final List<PlayerProgress> attempts = [];
  final List<PlayerProgress> saved = [];

  @override
  Future<PlayerProgress> load() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('progress unavailable');
    }
    final pendingLoad = nextLoad;
    nextLoad = null;
    return pendingLoad == null ? value : pendingLoad.future;
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    attempts.add(progress);
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk unavailable');
    }
    value = progress;
    saved.add(progress);
  }
}
