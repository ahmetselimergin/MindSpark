import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/grid_position.dart';
import 'package:mind_spark/game/domain/puzzle_session.dart';
import 'package:mind_spark/game/generation/level_difficulty.dart';
import 'package:mind_spark/game/generation/procedural_level_generator.dart';

const _palette = {'red', 'blue', 'green', 'yellow', 'purple', 'orange'};

void main() {
  const generator = ProceduralLevelGenerator();

  test('is deterministic for a given id', () {
    final a = generator.generate(42).level;
    final b = generator.generate(42).level;
    expect(a.size, b.size);
    expect(a.points.map((p) => '${p.x},${p.y},${p.color}'),
        b.points.map((p) => '${p.x},${p.y},${p.color}'));
  });

  test('produces structurally valid levels for ids 11..200', () {
    for (var id = kFirstGeneratedLevel; id <= 200; id++) {
      final level = generator.generate(id).level;
      final want = difficultyForLevel(id);
      expect(level.id, id);
      expect(level.size, want.size);

      final coords = <String>{};
      final counts = <String, int>{};
      for (final p in level.points) {
        expect(p.x, inInclusiveRange(0, level.size - 1));
        expect(p.y, inInclusiveRange(0, level.size - 1));
        expect(_palette, contains(p.color));
        expect(coords.add('${p.x},${p.y}'), isTrue, reason: 'dup coord at id $id');
        counts.update(p.color, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final entry in counts.entries) {
        expect(entry.value, 2, reason: 'colour ${entry.key} not a pair at id $id');
      }
    }
  });

  test('every generated level is solvable via its witness (real engine)', () {
    for (final id in [11, 19, 27, 35, 47, 88, 150]) {
      final generated = generator.generate(id);
      final session = PuzzleSession(level: generated.level);
      for (final path in generated.solution) {
        expect(session.startPath(GridPosition(path.first.x, path.first.y)), isTrue);
        for (final cell in path.skip(1)) {
          expect(session.extendPath(GridPosition(cell.x, cell.y)), isTrue,
              reason: 'blocked extend at id $id');
        }
        session.endPath();
      }
      expect(session.isComplete, isTrue, reason: 'id $id not complete');
    }
  });
}
