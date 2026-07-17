import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/grid_position.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';

void main() {
  group('MindSparkGame board geometry', () {
    test('has no hittable cells before receiving a positive canvas size', () {
      final game = _game();

      expect(game.cellAtLocalPosition(Vector2.zero()), isNull);
    });

    test('maps a centered square board with exclusive outer bounds', () {
      final game = _game()..onGameResize(Vector2(500, 300));

      expect(
        game.cellAtLocalPosition(Vector2(100.001, 0.001)),
        const GridPosition(0, 0),
      );
      expect(
        game.cellAtLocalPosition(Vector2(250, 150)),
        const GridPosition(2, 2),
      );
      expect(
        game.cellAtLocalPosition(Vector2(399.999, 299.999)),
        const GridPosition(4, 4),
      );

      expect(game.cellAtLocalPosition(Vector2(99.999, 150)), isNull);
      expect(game.cellAtLocalPosition(Vector2(400, 150)), isNull);
      expect(game.cellAtLocalPosition(Vector2(250, 300)), isNull);
      expect(game.cellAtLocalPosition(Vector2(-1, 150)), isNull);
      expect(game.cellAtLocalPosition(Vector2(double.nan, 150)), isNull);
    });

    test('recomputes letterboxing deterministically after resize', () {
      final game = _game()..onGameResize(Vector2(500, 300));
      expect(
        game.cellAtLocalPosition(Vector2(110, 10)),
        const GridPosition(0, 0),
      );

      game.onGameResize(Vector2(200, 400));

      expect(game.cellAtLocalPosition(Vector2(10, 90)), isNull);
      expect(
        game.cellAtLocalPosition(Vector2(10, 110)),
        const GridPosition(0, 0),
      );
      expect(game.cellAtLocalPosition(Vector2(200, 200)), isNull);
    });
  });

  group('MindSparkGame gesture adapter', () {
    test(
      'forwards pointer start, adjacent updates, and end to the session',
      () {
        final game = _game()..onGameResize(Vector2.all(500));

        expect(game.handlePointerStart(_cellCenter(0, 0)), isTrue);
        game.handlePointerUpdate(_cellCenter(1, 0));

        expect(game.snapshot.paths['red']!.cells, const [
          GridPosition(0, 0),
          GridPosition(1, 0),
        ]);

        game.handlePointerEnd();

        expect(game.snapshot.paths, isEmpty);
      },
    );

    test('normalizes a fast drag into every crossed orthogonal cell', () {
      final game = _game()..onGameResize(Vector2.all(500));

      game.handlePointerStart(_cellCenter(0, 0));
      game.handlePointerUpdate(_cellCenter(4, 0));

      expect(game.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
        GridPosition(2, 0),
        GridPosition(3, 0),
        GridPosition(4, 0),
      ]);
    });

    test(
      'uses horizontal dominant-axis traversal before vertical movement',
      () {
        final game = _game(level: _diagonalLevel())
          ..onGameResize(Vector2.all(500));

        game.handlePointerStart(_cellCenter(0, 0));
        game.handlePointerUpdate(_cellCenter(4, 2));

        expect(game.snapshot.paths['purple']!.cells, const [
          GridPosition(0, 0),
          GridPosition(1, 0),
          GridPosition(2, 0),
          GridPosition(3, 0),
          GridPosition(4, 0),
          GridPosition(4, 1),
          GridPosition(4, 2),
        ]);
      },
    );

    test('reverses a horizontal-dominant diagonal traversal exactly', () {
      const first = GridPosition(0, 0);
      const second = GridPosition(4, 2);

      final forward = _pathBetween(first, second);
      final reverse = _pathBetween(second, first);

      expect(reverse, forward.reversed);
      _expectManhattanRoute(reverse, start: second, target: first);
    });

    test('reverses a vertical-dominant diagonal traversal exactly', () {
      const first = GridPosition(1, 0);
      const second = GridPosition(3, 4);

      final forward = _pathBetween(first, second);
      final reverse = _pathBetween(second, first);

      expect(reverse, forward.reversed);
      _expectManhattanRoute(reverse, start: second, target: first);
    });

    test('reverses a negative-direction tied traversal exactly', () {
      const first = GridPosition(4, 4);
      const second = GridPosition(1, 1);

      final forward = _pathBetween(first, second);
      final reverse = _pathBetween(second, first);

      expect(reverse, forward.reversed);
      _expectManhattanRoute(reverse, start: second, target: first);
    });

    test('a fast diagonal move fully unwinds when dragged back', () {
      final game = _game(level: _backtrackingLevel())
        ..onGameResize(Vector2.all(500));

      expect(game.handlePointerStart(_cellCenter(0, 0)), isTrue);
      game.handlePointerUpdate(_cellCenter(4, 2));
      game.handlePointerUpdate(_cellCenter(0, 0));

      expect(game.snapshot.paths['purple']!.cells, const [GridPosition(0, 0)]);
    });

    test(
      'partial reverse samples monotonically unwind a synthetic segment',
      () {
        final game = _game(level: _backtrackingLevel())
          ..onGameResize(Vector2.all(500));

        expect(game.handlePointerStart(_cellCenter(0, 0)), isTrue);
        game.handlePointerUpdate(_cellCenter(4, 2));

        const reverseSamples = [
          GridPosition(3, 2),
          GridPosition(3, 1),
          GridPosition(2, 1),
          GridPosition(2, 0),
          GridPosition(1, 0),
          GridPosition(0, 0),
        ];
        for (var index = 0; index < reverseSamples.length; index++) {
          final sample = reverseSamples[index];
          game.handlePointerUpdate(_cellCenter(sample.x, sample.y));
          expect(
            game.snapshot.paths['purple']!.cells.length,
            6 - index,
            reason: 'reverse sample $sample must remove one synthetic cell',
          );
        }

        expect(game.snapshot.paths['purple']!.cells, const [
          GridPosition(0, 0),
        ]);
      },
    );

    test('forward direction change starts a fresh reversible segment', () {
      final game = _game(level: _backtrackingLevel())
        ..onGameResize(Vector2.all(500));

      expect(game.handlePointerStart(_cellCenter(0, 0)), isTrue);
      game.handlePointerUpdate(_cellCenter(4, 2));
      game.handlePointerUpdate(_cellCenter(3, 2));
      expect(game.snapshot.paths['purple']!.cells.length, 6);

      game.handlePointerUpdate(_cellCenter(4, 3));
      expect(game.snapshot.paths['purple']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
        GridPosition(2, 0),
        GridPosition(3, 0),
        GridPosition(4, 0),
        GridPosition(4, 1),
        GridPosition(4, 2),
        GridPosition(4, 3),
      ]);

      game.handlePointerUpdate(_cellCenter(4, 2));
      expect(
        game.snapshot.paths['purple']!.cells.last,
        const GridPosition(4, 2),
      );
      expect(game.snapshot.paths['purple']!.cells.length, 7);
    });

    test(
      'Flame callbacks retain the accepted pointer through its lifecycle',
      () {
        final game = _game()..onGameResize(Vector2.all(500));

        game.onDragStart(_dragStart(game, 11, _cellCenter(0, 0)));
        game.onDragStart(_dragStart(game, 22, _cellCenter(0, 4)));
        game.onDragUpdate(
          _dragUpdate(game, 22, _cellCenter(0, 4), _cellCenter(1, 4)),
        );
        game.onDragEnd(DragEndEvent(22, DragEndDetails()));
        game.onDragUpdate(
          _dragUpdate(game, 11, _cellCenter(0, 0), _cellCenter(1, 0)),
        );

        expect(game.snapshot.paths['red']!.cells, const [
          GridPosition(0, 0),
          GridPosition(1, 0),
        ]);

        game.onDragEnd(DragEndEvent(11, DragEndDetails()));
        game.onDragStart(_dragStart(game, 22, _cellCenter(0, 4)));

        expect(game.snapshot.paths.keys, contains('blue'));
      },
    );

    test('ignores an update outside the board without inventing a cell', () {
      final game = _game()..onGameResize(Vector2(500, 300));

      game.handlePointerStart(Vector2(130, 30));
      game.handlePointerUpdate(Vector2(50, 30));

      expect(game.snapshot.paths['red']!.cells, const [GridPosition(0, 0)]);
    });

    test('does not start from a letterbox or a non-endpoint cell', () {
      final game = _game()..onGameResize(Vector2(500, 300));

      expect(game.handlePointerStart(Vector2(50, 150)), isFalse);
      expect(game.handlePointerStart(Vector2(250, 150)), isFalse);
      expect(game.snapshot.paths, isEmpty);
    });

    test('a rejected second start does not disrupt the active drag', () {
      final game = _game()..onGameResize(Vector2.all(500));

      expect(game.handlePointerStart(_cellCenter(0, 0)), isTrue);
      expect(game.handlePointerStart(_cellCenter(0, 4)), isFalse);
      game.handlePointerUpdate(_cellCenter(1, 0));

      expect(game.snapshot.paths['red']!.cells, const [
        GridPosition(0, 0),
        GridPosition(1, 0),
      ]);
    });
  });

  test(
    'restart restores the initial snapshot and enables a new callback cycle',
    () {
      var completions = 0;
      final game = _game(onCompleted: () => completions++)
        ..onGameResize(Vector2.all(500));

      _completeLevel(game);
      expect(game.snapshot.isComplete, isTrue);
      expect(completions, 1);

      game.restart();
      expect(game.snapshot.paths, isEmpty);
      expect(game.snapshot.isComplete, isFalse);

      _completeLevel(game);
      expect(game.snapshot.isComplete, isTrue);
      expect(completions, 2);
    },
  );

  test('renders the board snapshot to a canvas', () {
    final game = _game()..onGameResize(Vector2.all(500));
    game.handlePointerStart(_cellCenter(0, 0));
    game.handlePointerUpdate(_cellCenter(4, 0));
    final recorder = PictureRecorder();

    expect(() => game.render(Canvas(recorder)), returnsNormally);

    recorder.endRecording();
  });
}

MindSparkGame _game({LevelModel? level, void Function()? onCompleted}) =>
    MindSparkGame(level: level ?? _level(), onCompleted: onCompleted ?? () {});

LevelModel _level() => const LevelModel(
  id: 1,
  size: 5,
  points: [
    GridPoint(x: 0, y: 0, color: 'red'),
    GridPoint(x: 4, y: 0, color: 'red'),
    GridPoint(x: 0, y: 4, color: 'blue'),
    GridPoint(x: 4, y: 4, color: 'blue'),
  ],
);

LevelModel _diagonalLevel() => const LevelModel(
  id: 2,
  size: 5,
  points: [
    GridPoint(x: 0, y: 0, color: 'purple'),
    GridPoint(x: 4, y: 2, color: 'purple'),
  ],
);

LevelModel _backtrackingLevel() => const LevelModel(
  id: 3,
  size: 5,
  points: [
    GridPoint(x: 0, y: 0, color: 'purple'),
    GridPoint(x: 4, y: 4, color: 'purple'),
  ],
);

Vector2 _cellCenter(int x, int y) => Vector2(x * 100 + 50, y * 100 + 50);

List<GridPosition> _pathBetween(GridPosition start, GridPosition target) {
  final game = _game(
    level: LevelModel(
      id: 4,
      size: 5,
      points: [
        GridPoint(x: start.x, y: start.y, color: 'green'),
        GridPoint(x: target.x, y: target.y, color: 'green'),
      ],
    ),
  )..onGameResize(Vector2.all(500));

  expect(game.handlePointerStart(_cellCenter(start.x, start.y)), isTrue);
  game.handlePointerUpdate(_cellCenter(target.x, target.y));
  return game.snapshot.paths['green']!.cells;
}

void _expectManhattanRoute(
  List<GridPosition> route, {
  required GridPosition start,
  required GridPosition target,
}) {
  expect(route.first, start);
  expect(route.last, target);
  for (var index = 1; index < route.length; index++) {
    expect(route[index - 1].manhattanDistanceTo(route[index]), 1);
  }
}

DragStartEvent _dragStart(MindSparkGame game, int pointerId, Vector2 position) {
  final event = DragStartEvent(
    pointerId,
    game,
    DragStartDetails(globalPosition: Offset(position.x, position.y)),
  );
  event.renderingTrace.add(position);
  return event;
}

DragUpdateEvent _dragUpdate(
  MindSparkGame game,
  int pointerId,
  Vector2 start,
  Vector2 end,
) {
  final event = DragUpdateEvent(
    pointerId,
    game,
    DragUpdateDetails(
      globalPosition: Offset(start.x, start.y),
      delta: Offset(end.x - start.x, end.y - start.y),
    ),
  );
  event.renderingTrace.add((start: start, end: end));
  return event;
}

void _completeLevel(MindSparkGame game) {
  game.handlePointerStart(_cellCenter(0, 0));
  game.handlePointerUpdate(_cellCenter(4, 0));
  game.handlePointerEnd();
  game.handlePointerStart(_cellCenter(0, 4));
  game.handlePointerUpdate(_cellCenter(4, 4));
  game.handlePointerEnd();
}
