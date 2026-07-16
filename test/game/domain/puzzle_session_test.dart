import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/grid_position.dart';
import 'package:mind_spark/game/domain/puzzle_session.dart';
import 'package:mind_spark/models/level_model.dart';

void main() {
  group('PuzzleSession starting and extending', () {
    test('starts only from a level endpoint', () {
      final session = PuzzleSession(level: _level);

      expect(session.startPath(const GridPosition(1, 1)), isFalse);
      expect(session.startPath(const GridPosition(0, 0)), isTrue);
      expect(session.snapshot.paths['red']!.cells, const [GridPosition(0, 0)]);
    });

    test('rejects starts outside the board', () {
      final session = PuzzleSession(level: _level);

      expect(session.startPath(const GridPosition(-1, 0)), isFalse);
      expect(session.startPath(const GridPosition(3, 0)), isFalse);
      expect(session.snapshot.paths, isEmpty);
    });

    test('extends through orthogonally adjacent cells', () {
      final session = PuzzleSession(level: _level);

      expect(session.startPath(const GridPosition(0, 0)), isTrue);
      expect(session.extendPath(const GridPosition(1, 0)), isTrue);
      expect(session.extendPath(const GridPosition(1, 1)), isTrue);
      expect(session.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
        GridPosition(1, 1),
      ]);
    });

    test('rejects extension outside the board', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));

      expect(session.extendPath(const GridPosition(-1, 0)), isFalse);
      expect(session.snapshot.paths['red']!.cells, const [GridPosition(0, 0)]);
    });

    test('rejects extension through an occupied cell', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      session.extendPath(const GridPosition(1, 0));
      session.extendPath(const GridPosition(2, 0));
      session.endPath();

      session.startPath(const GridPosition(0, 2));
      session.extendPath(const GridPosition(1, 2));
      session.extendPath(const GridPosition(1, 1));

      expect(session.extendPath(const GridPosition(1, 0)), isFalse);
      expect(session.snapshot.paths['blue']!.cells, const [
        GridPosition(0, 2),
        GridPosition(1, 2),
        GridPosition(1, 1),
      ]);
    });

    test('rejects extension onto an endpoint of another colour', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      session.extendPath(const GridPosition(0, 1));

      expect(session.extendPath(const GridPosition(0, 2)), isFalse);
      expect(session.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(0, 1),
      ]);
    });

    test('marks a path connected at its matching endpoint', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      session.extendPath(const GridPosition(1, 0));

      expect(session.extendPath(const GridPosition(2, 0)), isTrue);
      expect(session.snapshot.paths['red']!.connected, isTrue);
    });

    test('snapshots are defensive unmodifiable copies', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      final beforeExtension = session.snapshot;

      expect(
        () => beforeExtension.paths['red']!.cells.add(const GridPosition(1, 0)),
        throwsUnsupportedError,
      );
      expect(() => beforeExtension.paths.remove('red'), throwsUnsupportedError);

      session.extendPath(const GridPosition(1, 0));
      expect(beforeExtension.paths['red']!.cells, const [GridPosition(0, 0)]);
      expect(session.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
      ]);
    });
  });

  group('PuzzleSession editing', () {
    test('immediately backtracks by one cell', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      session.extendPath(const GridPosition(1, 0));
      session.extendPath(const GridPosition(1, 1));

      expect(session.extendPath(const GridPosition(1, 0)), isTrue);
      expect(session.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
      ]);
    });

    test('replaces a same-colour path from its first endpoint', () {
      final session = PuzzleSession(level: _level);
      _connectRed(session);

      expect(session.startPath(const GridPosition(0, 0)), isTrue);
      expect(session.snapshot.paths['red']!.cells, const [GridPosition(0, 0)]);
      expect(session.snapshot.paths['red']!.connected, isFalse);
    });

    test('replaces a same-colour path from its second endpoint', () {
      final session = PuzzleSession(level: _level);
      _connectRed(session);

      expect(session.startPath(const GridPosition(2, 0)), isTrue);
      expect(session.snapshot.paths['red']!.cells, const [GridPosition(2, 0)]);
      expect(session.snapshot.paths['red']!.connected, isFalse);
    });

    test('cancels an unconnected path when the gesture ends', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));
      session.extendPath(const GridPosition(0, 1));

      session.endPath();

      expect(session.snapshot.paths, isEmpty);
    });

    test('restart restores the initial empty unlocked state', () {
      final session = PuzzleSession(level: _level);
      _connectRed(session);

      session.restart();

      expect(session.snapshot.paths, isEmpty);
      expect(session.isComplete, isFalse);
      expect(session.startPath(const GridPosition(0, 0)), isTrue);
    });

    test('rejects a non-adjacent skipped cell', () {
      final session = PuzzleSession(level: _level);
      session.startPath(const GridPosition(0, 0));

      expect(session.extendPath(const GridPosition(2, 0)), isFalse);
      expect(session.snapshot.paths['red']!.cells, const [GridPosition(0, 0)]);
    });
  });

  group('PuzzleSession completion', () {
    test('locks input before emitting completion exactly once', () {
      late PuzzleSession session;
      var completionCount = 0;
      var inputWasLockedDuringCallback = false;
      session = PuzzleSession(
        level: _level,
        onCompleted: () {
          completionCount++;
          inputWasLockedDuringCallback = !session.startPath(
            const GridPosition(0, 0),
          );
        },
      );
      _connectRed(session);

      _connectBlue(session);

      expect(session.isComplete, isTrue);
      expect(session.snapshot.isComplete, isTrue);
      expect(inputWasLockedDuringCallback, isTrue);
      expect(completionCount, 1);
      expect(session.extendPath(const GridPosition(1, 2)), isFalse);
      session.endPath();
      expect(session.startPath(const GridPosition(0, 0)), isFalse);
      expect(completionCount, 1);
    });

    test('restart unlocks input and permits one new completion emission', () {
      var completionCount = 0;
      final session = PuzzleSession(
        level: _level,
        onCompleted: () => completionCount++,
      );
      _connectRed(session);
      _connectBlue(session);
      expect(completionCount, 1);

      session.restart();

      expect(session.startPath(const GridPosition(0, 0)), isTrue);
      session.extendPath(const GridPosition(1, 0));
      session.extendPath(const GridPosition(2, 0));
      session.endPath();
      _connectBlue(session);
      expect(session.isComplete, isTrue);
      expect(completionCount, 2);
      expect(session.startPath(const GridPosition(0, 0)), isFalse);
      expect(completionCount, 2);
    });
  });
}

void _connectRed(PuzzleSession session) {
  session.startPath(const GridPosition(0, 0));
  session.extendPath(const GridPosition(1, 0));
  session.extendPath(const GridPosition(2, 0));
  session.endPath();
}

void _connectBlue(PuzzleSession session) {
  session.startPath(const GridPosition(0, 2));
  session.extendPath(const GridPosition(1, 2));
  session.extendPath(const GridPosition(2, 2));
  session.endPath();
}

const _level = LevelModel(
  id: 1,
  size: 3,
  points: [
    GridPoint(x: 0, y: 0, color: 'red'),
    GridPoint(x: 2, y: 0, color: 'red'),
    GridPoint(x: 0, y: 2, color: 'blue'),
    GridPoint(x: 2, y: 2, color: 'blue'),
  ],
);
