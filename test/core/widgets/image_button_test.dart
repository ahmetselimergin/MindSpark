import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/image_button.dart';

void main() {
  testWidgets('fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageButton(
            asset: 'assets/ui/playbutton.png',
            semanticLabel: 'Play',
            width: 200,
            height: 60,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Play'));
    expect(taps, 1);
  });

  testWidgets('ignores taps and dims when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageButton(
            asset: 'assets/ui/playbutton.png',
            semanticLabel: 'Play',
            onPressed: null,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Play'), warnIfMissed: false);
    expect(taps, 0);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1.0));
  });
}
