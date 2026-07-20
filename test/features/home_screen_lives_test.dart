import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/features/home/home_screen.dart';
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
    child: MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          AppRoutes.gameplay => const Scaffold(body: Text('GAMEPLAY')),
          AppRoutes.outOfLives => const Scaffold(body: Text('OUT OF LIVES')),
          _ => Consumer(
              builder: (context, ref, _) {
                final ready =
                    ref.watch(appProgressControllerProvider).hasValue;
                return ready ? const HomeScreen() : const SizedBox.shrink();
              },
            ),
        },
      ),
    ),
  );
}

int _fullHearts(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .where((o) {
      final child = o.child;
      return o.opacity == 1.0 &&
          child is Image &&
          child.image is AssetImage &&
          (child.image as AssetImage).assetName == AppImages.heart;
    })
    .length;

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders one filled heart per life', (tester) async {
    final stored =
        const PlayerProgress.initial().copyWithLives(lives: 1, anchor: t0);
    await tester.pumpWidget(
      _harness(stored, t0.add(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();

    expect(_fullHearts(tester), 1);
    expect(find.textContaining('Next life'), findsOneWidget);
  });

  testWidgets('shows three filled hearts and no countdown when full', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlayerProgress.initial(), t0));
    await tester.pumpAndSettle();

    expect(_fullHearts(tester), 3);
    expect(find.textContaining('Next life'), findsNothing);
  });

  testWidgets('tapping the current level with no lives opens out-of-lives', (
    tester,
  ) async {
    final stored =
        const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(
      _harness(stored, t0.add(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('OUT OF LIVES'), findsOneWidget);
  });
}
