import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/main.dart' as app;
import 'package:mind_spark/models/level_model.dart';
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
