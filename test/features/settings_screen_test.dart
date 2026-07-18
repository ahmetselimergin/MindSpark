import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/features/settings/settings_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  // Advanced progress with sound on, vibration off, so we can prove the toggle
  // flips sound and that reset preserves the (non-default) vibration setting.
  final advanced = PlayerProgress(
    schemaVersion: 1,
    highestUnlockedLevel: 5,
    completedLevelIds: const {1, 2, 3, 4},
    totalScore: 400,
    lives: 3,
    soundEnabled: true,
    vibrationEnabled: false,
  );

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester,
    PlayerProgress seed,
  ) async {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          InMemoryProgressRepository(seed),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appProgressControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('HOME')),
          },
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('toggling sound persists the preference', (tester) async {
    final container = await pumpSettings(tester, advanced);

    final soundTile = find.widgetWithText(SwitchListTile, 'Sound');
    expect(tester.widget<SwitchListTile>(soundTile).value, isTrue);

    await tester.tap(soundTile);
    await tester.pumpAndSettle();

    expect(
      container.read(appProgressControllerProvider).requireValue.soundEnabled,
      isFalse,
    );
  });

  testWidgets('reset asks for confirmation, clears progress, returns home',
      (tester) async {
    final container = await pumpSettings(tester, advanced);

    await tester.tap(find.text('RESET PROGRESS'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'RESET'));
    await tester.pumpAndSettle();

    final progress = container
        .read(appProgressControllerProvider)
        .requireValue;
    expect(progress.highestUnlockedLevel, 1);
    expect(progress.totalScore, 0);
    expect(progress.vibrationEnabled, isFalse); // settings preserved
    expect(find.text('HOME'), findsOneWidget); // navigated to home
  });

  testWidgets('cancelling reset keeps progress', (tester) async {
    final container = await pumpSettings(tester, advanced);

    await tester.tap(find.text('RESET PROGRESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'CANCEL'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(appProgressControllerProvider)
          .requireValue
          .highestUnlockedLevel,
      5,
    );
  });
}
