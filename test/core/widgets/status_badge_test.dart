import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';

void main() {
  Finder badgeImage() => find.descendant(
    of: find.byType(StatusBadge),
    matching: find.byType(Image),
  );

  testWidgets('renders the asset for the star tier', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBadge(stars: 3))),
    );
    await tester.pump();
    final image = tester.widget<Image>(badgeImage());
    expect((image.image as AssetImage).assetName, AppImages.statusPerfect);
  });

  testWidgets('entrance animation settles and fires onCompleted', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StatusBadge(stars: 1, onCompleted: () => done = true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });
}
