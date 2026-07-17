import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../models/level_model.dart';
import 'domain/grid_position.dart';
import 'domain/puzzle_session.dart';
import 'domain/puzzle_snapshot.dart';

final class MindSparkGame extends FlameGame with DragCallbacks {
  MindSparkGame({required LevelModel level, required VoidCallback onCompleted})
    : _level = level,
      _session = PuzzleSession(level: level, onCompleted: onCompleted);

  static const Map<String, Color> _palette = {
    'red': Color(0xFFE84545),
    'blue': Color(0xFF3478F6),
    'green': Color(0xFF2FA568),
    'yellow': Color(0xFFF4B942),
    'purple': Color(0xFF8B5CF6),
    'orange': Color(0xFFF47B35),
  };
  static const Color _fallbackColor = Color(0xFFD946EF);

  final LevelModel _level;
  final PuzzleSession _session;
  final Vector2 _canvasSize = Vector2.zero();
  GridPosition? _lastPointerCell;
  GridPosition? _lastRawPointerCell;
  _SyntheticSegment? _syntheticSegment;
  int? _activePointerId;

  PuzzleSnapshot get snapshot => _session.snapshot;

  Rect? get _boardRect {
    if (!_canvasSize.x.isFinite ||
        !_canvasSize.y.isFinite ||
        _canvasSize.x <= 0 ||
        _canvasSize.y <= 0) {
      return null;
    }
    final side = math.min(_canvasSize.x, _canvasSize.y);
    return Rect.fromLTWH(
      (_canvasSize.x - side) / 2,
      (_canvasSize.y - side) / 2,
      side,
      side,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    _canvasSize.setFrom(size);
    super.onGameResize(size);
  }

  GridPosition? cellAtLocalPosition(Vector2 position) {
    final board = _boardRect;
    if (board == null || !position.x.isFinite || !position.y.isFinite) {
      return null;
    }
    if (position.x < board.left ||
        position.x >= board.right ||
        position.y < board.top ||
        position.y >= board.bottom) {
      return null;
    }

    final cellSize = board.width / _level.size;
    return GridPosition(
      ((position.x - board.left) / cellSize).floor(),
      ((position.y - board.top) / cellSize).floor(),
    );
  }

  bool handlePointerStart(Vector2 localPosition) {
    final cell = cellAtLocalPosition(localPosition);
    if (cell == null || !_session.startPath(cell)) {
      return false;
    }
    _lastPointerCell = cell;
    _lastRawPointerCell = cell;
    _syntheticSegment = null;
    return true;
  }

  void handlePointerUpdate(Vector2 localPosition) {
    final target = cellAtLocalPosition(localPosition);
    final start = _lastPointerCell;
    final rawStart = _lastRawPointerCell;
    if (target == null ||
        start == null ||
        rawStart == null ||
        target == rawStart) {
      return;
    }

    final rawDx = target.x - rawStart.x;
    final rawDy = target.y - rawStart.y;
    final segment = _syntheticSegment;
    if (segment != null && segment.projection(rawDx, rawDy) < 0) {
      var steps = rawDx.abs() + rawDy.abs();
      while (steps > 0 && segment.cells.isNotEmpty) {
        final previous = segment.cells.length == 1
            ? segment.start
            : segment.cells[segment.cells.length - 2];
        if (!_session.extendPath(previous)) {
          break;
        }
        segment.cells.removeLast();
        _lastPointerCell = previous;
        steps--;
      }
      if (segment.cells.isEmpty) {
        _syntheticSegment = null;
      }
      _lastRawPointerCell = target;
      return;
    }

    final nextSegment = _SyntheticSegment(
      start: start,
      rawDx: rawDx,
      rawDy: rawDy,
    );
    _syntheticSegment = nextSegment;
    for (final cell in _orthogonalTraversal(start, target)) {
      if (!_session.extendPath(cell)) {
        break;
      }
      nextSegment.cells.add(cell);
      _lastPointerCell = cell;
    }
    if (nextSegment.cells.isEmpty) {
      _syntheticSegment = null;
    }
    _lastRawPointerCell = target;
  }

  void handlePointerEnd() {
    _session.endPath();
    _clearPointerState();
  }

  void restart() {
    _session.restart();
    _clearPointerState();
  }

  void _clearPointerState() {
    _lastPointerCell = null;
    _lastRawPointerCell = null;
    _syntheticSegment = null;
    _activePointerId = null;
  }

  @override
  bool containsLocalPoint(Vector2 point) => cellAtLocalPosition(point) != null;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_activePointerId == null && handlePointerStart(event.localPosition)) {
      _activePointerId = event.pointerId;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId == _activePointerId) {
      handlePointerUpdate(event.localEndPosition);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (event.pointerId == _activePointerId) {
      handlePointerEnd();
    }
    super.onDragEnd(event);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final board = _boardRect;
    if (board == null) {
      return;
    }

    canvas.drawRect(board, Paint()..color = const Color(0xFFF8FAFC));
    _drawGrid(canvas, board);
    _drawPaths(canvas, board);
    _drawEndpoints(canvas, board);
  }

  Iterable<GridPosition> _orthogonalTraversal(
    GridPosition start,
    GridPosition target,
  ) {
    final startIsCanonical =
        start.x < target.x || (start.x == target.x && start.y <= target.y);
    final canonicalStart = startIsCanonical ? start : target;
    final canonicalTarget = startIsCanonical ? target : start;
    var current = canonicalStart;
    final route = <GridPosition>[current];
    final horizontalFirst =
        (canonicalTarget.x - canonicalStart.x).abs() >=
        (canonicalTarget.y - canonicalStart.y).abs();

    if (horizontalFirst) {
      while (current.x != canonicalTarget.x) {
        current = GridPosition(
          current.x + (canonicalTarget.x > current.x ? 1 : -1),
          current.y,
        );
        route.add(current);
      }
    }
    while (current.y != canonicalTarget.y) {
      current = GridPosition(
        current.x,
        current.y + (canonicalTarget.y > current.y ? 1 : -1),
      );
      route.add(current);
    }
    while (current.x != canonicalTarget.x) {
      current = GridPosition(
        current.x + (canonicalTarget.x > current.x ? 1 : -1),
        current.y,
      );
      route.add(current);
    }

    return (startIsCanonical ? route : route.reversed).skip(1);
  }

  void _drawGrid(Canvas canvas, Rect board) {
    final cellSize = board.width / _level.size;
    final paint = Paint()
      ..color = const Color(0xFFD8DEE9)
      ..strokeWidth = math.max(1, cellSize * 0.018);
    for (var index = 0; index <= _level.size; index++) {
      final offset = index * cellSize;
      canvas.drawLine(
        Offset(board.left + offset, board.top),
        Offset(board.left + offset, board.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(board.left, board.top + offset),
        Offset(board.right, board.top + offset),
        paint,
      );
    }
  }

  void _drawPaths(Canvas canvas, Rect board) {
    final cellSize = board.width / _level.size;
    for (final path in snapshot.paths.values) {
      if (path.cells.length < 2) {
        continue;
      }
      final paint = Paint()
        ..color = _colorFor(path.color)
        ..strokeWidth = cellSize * 0.32
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final renderedPath = Path();
      final first = _cellCenterOffset(path.cells.first, board, cellSize);
      renderedPath.moveTo(first.dx, first.dy);
      for (final cell in path.cells.skip(1)) {
        final center = _cellCenterOffset(cell, board, cellSize);
        renderedPath.lineTo(center.dx, center.dy);
      }
      canvas.drawPath(renderedPath, paint);
    }
  }

  void _drawEndpoints(Canvas canvas, Rect board) {
    final cellSize = board.width / _level.size;
    for (final point in _level.points) {
      final center = _cellCenterOffset(
        GridPosition(point.x, point.y),
        board,
        cellSize,
      );
      canvas.drawCircle(
        center,
        cellSize * 0.31,
        Paint()..color = _colorFor(point.color),
      );
      _drawEndpointSymbol(canvas, center, cellSize * 0.13, point.color);
    }
  }

  void _drawEndpointSymbol(
    Canvas canvas,
    Offset center,
    double radius,
    String colorName,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = math.max(2, radius * 0.32)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final symbol = _symbolFor(colorName);
    switch (symbol) {
      case 0:
        canvas.drawCircle(center, radius, paint);
      case 1:
        canvas.drawLine(
          Offset(center.dx - radius, center.dy - radius),
          Offset(center.dx + radius, center.dy + radius),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + radius, center.dy - radius),
          Offset(center.dx - radius, center.dy + radius),
          paint,
        );
      case 2:
        final diamond = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close();
        canvas.drawPath(diamond, paint);
      case 3:
        canvas.drawRect(
          Rect.fromCenter(
            center: center,
            width: radius * 1.7,
            height: radius * 1.7,
          ),
          paint,
        );
      case 4:
        final triangle = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy + radius)
          ..close();
        canvas.drawPath(triangle, paint);
      default:
        canvas.drawLine(
          Offset(center.dx - radius, center.dy),
          Offset(center.dx + radius, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius),
          Offset(center.dx, center.dy + radius),
          paint,
        );
    }
  }

  Color _colorFor(String colorName) =>
      _palette[colorName.toLowerCase()] ?? _fallbackColor;

  int _symbolFor(String colorName) {
    final knownIndex = _palette.keys.toList().indexOf(colorName.toLowerCase());
    if (knownIndex >= 0) {
      return knownIndex;
    }
    return colorName.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 6;
  }

  Offset _cellCenterOffset(GridPosition cell, Rect board, double cellSize) =>
      Offset(
        board.left + (cell.x + 0.5) * cellSize,
        board.top + (cell.y + 0.5) * cellSize,
      );
}

final class _SyntheticSegment {
  _SyntheticSegment({
    required this.start,
    required this.rawDx,
    required this.rawDy,
  });

  final GridPosition start;
  final int rawDx;
  final int rawDy;
  final List<GridPosition> cells = [];

  int projection(int dx, int dy) => dx * rawDx + dy * rawDy;
}
