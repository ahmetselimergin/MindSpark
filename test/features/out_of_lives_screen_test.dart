import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/out_of_lives/out_of_lives_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider.overrideWithValue(
        InMemoryProgressRepository(stored),
      ),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const MaterialApp(home: OutOfLivesScreen(levelId: 3)),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('shows countdown and a disabled ad button while empty', (
    tester,
  ) async {
    final stored = const PlayerProgress.initial().copyWithLives(
      lives: 0,
      anchor: t0,
    );
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 2))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Next life'), findsOneWidget);
    final adButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'WATCH AD (COMING SOON)'),
    );
    expect(adButton.onPressed, isNull);
    expect(find.widgetWithText(FilledButton, 'CONTINUE'), findsNothing);
  });

  testWidgets('offers CONTINUE once a life has regenerated', (tester) async {
    // 10+ minutes elapsed on the stored anchor ⇒ one life back.
    final stored = const PlayerProgress.initial().copyWithLives(
      lives: 0,
      anchor: t0,
    );
    await tester.pumpWidget(
      _harness(stored, t0.add(const Duration(minutes: 11))),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'CONTINUE'), findsOneWidget);
  });
}
