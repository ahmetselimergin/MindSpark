import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  testWidgets('result screen shows a StatusBadge for the awarded stars', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            InMemoryProgressRepository(const PlayerProgress.initial()),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final ready =
                  ref.watch(appProgressControllerProvider).hasValue;
              return ready
                  ? const ResultScreen(
                      levelId: 1,
                      awardedScore: 100,
                      stars: 2,
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StatusBadge), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName, AppImages.statusGreat);
  });
}
