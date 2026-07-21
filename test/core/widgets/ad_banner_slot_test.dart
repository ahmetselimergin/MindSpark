import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mind_spark/core/widgets/ad_banner_slot.dart';

void main() {
  testWidgets('reserves a fixed height and loads no ad under test', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: AdBannerSlot()))),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(AdBannerSlot)).height, 60);
    expect(find.byType(AdWidget), findsNothing);
  });
}
