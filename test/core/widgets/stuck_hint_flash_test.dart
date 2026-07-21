import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/stuck_hint_flash.dart';

void main() {
  testWidgets('is hidden until triggered, then flashes once', (tester) async {
    var trigger = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                StuckHintFlash(trigger: trigger, message: 'fill it up'),
                ElevatedButton(
                  onPressed: () => setState(() => trigger++),
                  child: const Text('go'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('fill it up'), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pump(); // rebuild with new trigger
    await tester.pump(const Duration(milliseconds: 100)); // fade-in underway
    expect(find.text('fill it up'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // animation completes
    expect(find.text('fill it up'), findsNothing);
  });
}
