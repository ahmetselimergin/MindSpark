import 'dart:ui';

import 'package:flame/components.dart';
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

Vector2 _cellCenter(int x, int y) => Vector2(x * 100 + 50, y * 100 + 50);

void _completeLevel(MindSparkGame game) {
  game.handlePointerStart(_cellCenter(0, 0));
  game.handlePointerUpdate(_cellCenter(4, 0));
  game.handlePointerEnd();
  game.handlePointerStart(_cellCenter(0, 4));
  game.handlePointerUpdate(_cellCenter(4, 4));
  game.handlePointerEnd();
}
