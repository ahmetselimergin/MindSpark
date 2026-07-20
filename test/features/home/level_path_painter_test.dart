import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';
import 'package:mind_spark/features/home/widgets/level_path_painter.dart';

void main() {
  test('trailSegments connects only consecutive non-locked cards', () {
    final centers = [
      const Offset(0, 0),
      const Offset(1, 0),
      const Offset(2, 0),
      const Offset(3, 0),
    ];
    const statuses = [
      LevelCardStatus.completed,
      LevelCardStatus.completed,
      LevelCardStatus.current,
      LevelCardStatus.locked,
    ];
    final segments = trailSegments(centers, statuses);
    expect(segments, hasLength(2)); // 0-1 and 1-2; 2-3 stops at locked
    expect(segments.first.$1, const Offset(0, 0));
    expect(segments.last.$2, const Offset(2, 0));
  });

  test('trailSegments with a single card yields nothing', () {
    final segments =
        trailSegments(const [Offset.zero], const [LevelCardStatus.current]);
    expect(segments, isEmpty);
  });
}
