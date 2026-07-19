import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/features/home/home_screen.dart';
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

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider.overrideWithValue(
        InMemoryProgressRepository(stored),
      ),
      clockProvider.overrideWithValue(() => now),
      levelByIdProvider(
        stored.highestUnlockedLevel,
      ).overrideWith((ref) async => _level(stored.highestUnlockedLevel)),
    ],
    // Mirror production: the splash gates Home until progress has loaded.
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          final ready = ref.watch(appProgressControllerProvider).hasValue;
          return ready ? const HomeScreen() : const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders one filled heart per life', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(
      lives: 3,
      anchor: t0,
    );
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 1))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
    expect(find.textContaining('Next life'), findsOneWidget);
  });

  testWidgets('shows five filled hearts and no countdown when full', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlayerProgress.initial(), t0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsNWidgets(5));
    expect(find.textContaining('Next life'), findsNothing);
  });

  testWidgets('locks PLAY when out of lives', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(
      lives: 0,
      anchor: t0,
    );
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 1))));
    await tester.pumpAndSettle();

    final playButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'PLAY'),
    );
    expect(playButton.onPressed, isNull); // disabled
  });
}
