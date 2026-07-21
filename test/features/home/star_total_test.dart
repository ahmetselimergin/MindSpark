import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/features/home/widgets/star_total.dart';

void main() {
  testWidgets('renders the total and a star image with a semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StarTotal(total: 42))),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.bySemanticsLabel('Total stars 42'), findsOneWidget);

    final image = tester.widget<Image>(
      find.descendant(of: find.byType(StarTotal), matching: find.byType(Image)),
    );
    expect((image.image as AssetImage).assetName, AppImages.star);
  });
}
