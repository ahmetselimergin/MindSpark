import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';

void main() {
  testWidgets('renders maxLives hearts, dimming the empties', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HeartsRow(lives: 1))),
    );

    expect(find.byType(Image), findsNWidgets(LivesRegen.maxLives));

    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .toList();
    expect(opacities.where((o) => o == 1.0).length, 1); // 1 full
    expect(opacities.where((o) => o < 1.0).length, LivesRegen.maxLives - 1);
  });
}
