import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Widget _harness(int stars) => ProviderScope(
  overrides: [
    progressRepositoryProvider.overrideWithValue(InMemoryProgressRepository()),
  ],
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, _) {
        final ready = ref.watch(appProgressControllerProvider).hasValue;
        return ready
            ? ResultScreen(levelId: 1, awardedScore: 100, stars: stars)
            : const SizedBox.shrink();
      },
    ),
  ),
);

bool _hasAsset(WidgetTester tester, String asset) => tester
    .widgetList<Image>(find.byType(Image))
    .any(
      (i) => i.image is AssetImage && (i.image as AssetImage).assetName == asset,
    );

void main() {
  testWidgets('shows the won board, the matching star row, and next', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(2));
    await tester.pumpAndSettle();

    expect(_hasAsset(tester, AppImages.wonBoard), isTrue);
    expect(_hasAsset(tester, AppImages.star2), isTrue);
    expect(find.bySemanticsLabel('Next level'), findsOneWidget);
  });

  testWidgets('three stars uses 3star.png', (tester) async {
    await tester.pumpWidget(_harness(3));
    await tester.pumpAndSettle();
    expect(_hasAsset(tester, AppImages.star3), isTrue);
  });
}
