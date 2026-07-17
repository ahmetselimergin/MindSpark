import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/level_repository.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  testWidgets('completion survives app recreation without duplicate score', (
    tester,
  ) async {
    final repository = InMemoryProgressRepository();
    final firstHarness = _GameHarness();

    await tester.pumpWidget(
      _testApp(repository: repository, harness: firstHarness),
    );
    await _pumpFrames(tester);
    await tester.tap(find.text('PLAY'));
    await _pumpFrames(tester);

    firstHarness.completeLatest();
    await _pumpFrames(tester);

    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(repository.value.totalScore, 100);
    expect(repository.value.highestUnlockedLevel, 2);
    expect(repository.value.completedLevelIds, {1});

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final secondHarness = _GameHarness();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _testApp(
        repository: repository,
        harness: secondHarness,
        navigatorKey: navigatorKey,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Best Score: 100'), findsOneWidget);

    navigatorKey.currentState!.pushNamed(
      AppRoutes.gameplay,
      arguments: const GameplayRouteArgs(1),
    );
    await _pumpFrames(tester);
    expect(find.text('Level 1'), findsWidgets);

    secondHarness.completeLatest();
    await _pumpFrames(tester);

    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
    expect(repository.value.totalScore, 100);
    expect(repository.value.highestUnlockedLevel, 2);
    expect(repository.value.completedLevelIds, {1});
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _testApp({
  required InMemoryProgressRepository repository,
  required _GameHarness harness,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return ProviderScope(
    overrides: [
      levelRepositoryProvider.overrideWithValue(_TestLevelRepository()),
      progressRepositoryProvider.overrideWithValue(repository),
      mindSparkGameFactoryProvider.overrideWithValue(harness.create),
    ],
    child: MindSparkApp(navigatorKey: navigatorKey),
  );
}

final class _GameHarness {
  final List<VoidCallback> completions = [];

  MindSparkGame create(LevelModel level, VoidCallback onCompleted) {
    completions.add(onCompleted);
    return MindSparkGame(level: level, onCompleted: onCompleted);
  }

  void completeLatest() => completions.last();
}

final class _TestLevelRepository implements LevelRepository {
  static const levels = [
    LevelModel(
      id: 1,
      size: 2,
      points: [
        GridPoint(x: 0, y: 0, color: 'blue'),
        GridPoint(x: 1, y: 1, color: 'blue'),
      ],
    ),
    LevelModel(
      id: 2,
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
