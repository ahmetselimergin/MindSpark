import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('current card shows number, is labelled Play, and taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(LevelCard(
        levelId: 3,
        status: LevelCardStatus.current,
        stars: 0,
        onTap: () => taps++,
      )),
    );
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Play'));
    expect(taps, 1);
  });

  testWidgets('completed card shows number and three star images', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(LevelCard(
        levelId: 8,
        status: LevelCardStatus.completed,
        stars: 2,
        onTap: () {},
      )),
    );
    expect(find.text('8'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LevelCard),
        matching: find.byType(Image),
      ),
      findsNWidgets(3),
    );
    expect(find.bySemanticsLabel('Replay level 8'), findsOneWidget);
  });

  testWidgets('locked card is not a Play button and ignores taps', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const LevelCard(
        levelId: 5,
        status: LevelCardStatus.locked,
        stars: 0,
        onTap: null,
      )),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsNothing);
    expect(find.bySemanticsLabel('Level 5 locked'), findsOneWidget);
  });
}
