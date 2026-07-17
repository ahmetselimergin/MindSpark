import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/main.dart' as app;
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/level_repository.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  testWidgets('bootstrap failure can retry and mount the app', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      app.ProgressBootstrap(
        initializer: () async {
          attempts++;
          if (attempts == 1) {
            throw StateError('Hive unavailable');
          }
          return InMemoryProgressRepository();
        },
      ),
    );
    await tester.pump();

    expect(find.text('MindSpark'), findsOneWidget);
    expect(find.text('Progress storage could not be opened.'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Level 1'), findsOneWidget);
  });

  testWidgets('rapid bootstrap retry starts one initializer and mounts once', (
    tester,
  ) async {
    var attempts = 0;
    final retry = Completer<ProgressRepository>();
    final repository = _CountingProgressRepository();

    await tester.pumpWidget(
      app.ProgressBootstrap(
        initializer: () {
          attempts++;
          if (attempts == 1) {
            return Future<ProgressRepository>.error(
              StateError('Hive unavailable'),
            );
          }
          if (attempts == 2) {
            return retry.future;
          }
          return Future<ProgressRepository>.value(InMemoryProgressRepository());
        },
      ),
    );
    await tester.pump();

    final retryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'RETRY'),
    );
    retryButton.onPressed!();
    retryButton.onPressed!();
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('RETRY'), findsNothing);

    retry.complete(repository);
    for (var pump = 0; pump < 20 && repository.loadAttempts == 0; pump++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(attempts, 2);
    expect(repository.loadAttempts, 1);
    expect(find.text('Progress storage could not be opened.'), findsNothing);
  });

  testWidgets('splash waits while initialization is still loading', (
    tester,
  ) async {
    final levels = Completer<List<LevelModel>>();

    await tester.pumpWidget(
      _testApp(
        levelRepository: _TestLevelRepository(load: () => levels.future),
      ),
    );

    expect(find.text('MindSpark'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  testWidgets('splash explains a level load failure and retries', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _TestLevelRepository(
      load: () async {
        attempts++;
        if (attempts == 1) {
          throw const LevelLoadException('Bundled levels are unavailable');
        }
        return _levels;
      },
    );

    await tester.pumpWidget(_testApp(levelRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Levels could not be loaded.'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Level 1'), findsOneWidget);
  });

  testWidgets('splash does not navigate with retained data on retry error', (
    tester,
  ) async {
    var levelAttempts = 0;
    var progressAttempts = 0;
    final levelRepository = _TestLevelRepository(
      load: () async {
        levelAttempts++;
        if (levelAttempts == 1) {
          throw const LevelLoadException('levels unavailable');
        }
        return _levels;
      },
    );
    final progressRepository = _TestProgressRepository(
      loadProgress: () async {
        progressAttempts++;
        if (progressAttempts == 2) {
          throw StateError('progress unavailable');
        }
        return const PlayerProgress.initial();
      },
    );

    await tester.pumpWidget(
      _testApp(
        levelRepository: levelRepository,
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Levels could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(levelAttempts, 2);
    expect(progressAttempts, 2);
    expect(find.text('Progress could not be loaded.'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
    expect(find.text('Best Score: 0'), findsNothing);
  });

  testWidgets('home shows the current level and score', (tester) async {
    await tester.pumpWidget(
      _testApp(
        levelRepository: _TestLevelRepository(load: () async => _levels),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MindSpark'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Best Score: 0'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}

Widget _testApp({
  required LevelRepository levelRepository,
  ProgressRepository? progressRepository,
}) {
  return ProviderScope(
    overrides: [
      levelRepositoryProvider.overrideWithValue(levelRepository),
      progressRepositoryProvider.overrideWithValue(
        progressRepository ?? InMemoryProgressRepository(),
      ),
    ],
    child: const MindSparkApp(),
  );
}

final _levels = [
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

final class _TestLevelRepository implements LevelRepository {
  _TestLevelRepository({required this.load});

  final Future<List<LevelModel>> Function() load;

  @override
  Future<List<LevelModel>> loadLevels() => load();

  @override
  Future<LevelModel> levelById(int id) async {
    final levels = await loadLevels();
    return levels.firstWhere((level) => level.id == id);
  }
}

final class _TestProgressRepository implements ProgressRepository {
  _TestProgressRepository({required this.loadProgress});

  final Future<PlayerProgress> Function() loadProgress;

  @override
  Future<PlayerProgress> load() => loadProgress();

  @override
  Future<void> save(PlayerProgress progress) async {}
}

final class _CountingProgressRepository implements ProgressRepository {
  int loadAttempts = 0;

  @override
  Future<PlayerProgress> load() async {
    loadAttempts++;
    return const PlayerProgress.initial();
  }

  @override
  Future<void> save(PlayerProgress progress) async {}
}
