import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  test('defaults to null and holds a level id, then clears', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(celebrateLevelProvider), isNull);

    container.read(celebrateLevelProvider.notifier).state = 7;
    expect(container.read(celebrateLevelProvider), 7);

    container.read(celebrateLevelProvider.notifier).state = null;
    expect(container.read(celebrateLevelProvider), isNull);
  });
}
