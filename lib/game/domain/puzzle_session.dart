import 'dart:collection';

import '../../models/level_model.dart';
import 'grid_position.dart';
import 'path_state.dart';
import 'puzzle_snapshot.dart';

final class PuzzleSession {
  factory PuzzleSession({
    required LevelModel level,
    void Function()? onCompleted,
  }) => PuzzleSession._(level, onCompleted);

  PuzzleSession._(this._level, this._onCompleted) {
    for (final point in _level.points) {
      final position = GridPosition(point.x, point.y);
      _endpointColors[position] = point.color;
      (_endpointsByColor[point.color] ??= <GridPosition>[]).add(position);
    }
  }

  final LevelModel _level;
  final void Function()? _onCompleted;
  final Map<GridPosition, String> _endpointColors = {};
  final Map<String, List<GridPosition>> _endpointsByColor = {};
  final Map<String, _MutablePath> _paths = {};

  String? _activeColor;
  bool _inputLocked = false;

  PuzzleSnapshot get snapshot {
    final paths = <String, PathState>{
      for (final MapEntry(key: color, value: path) in _paths.entries)
        color: PathState(
          color: color,
          cells: List<GridPosition>.unmodifiable(path.cells),
          connected: path.connected,
        ),
    };
    return PuzzleSnapshot(
      size: _level.size,
      paths: UnmodifiableMapView(paths),
      isComplete: isComplete,
    );
  }

  bool get isComplete =>
      _paths.length == _endpointsByColor.length &&
      _paths.values.every((path) => path.connected);

  bool startPath(GridPosition position) {
    if (_inputLocked || _activeColor != null || !_isInBounds(position)) {
      return false;
    }
    final color = _endpointColors[position];
    if (color == null) {
      return false;
    }

    _paths[color] = _MutablePath([position]);
    _activeColor = color;
    return true;
  }

  bool extendPath(GridPosition position) {
    final color = _activeColor;
    if (color == null || _inputLocked || !_isInBounds(position)) {
      return false;
    }

    final path = _paths[color]!;
    final last = path.cells.last;
    if (last.manhattanDistanceTo(position) != 1) {
      return false;
    }

    if (path.cells.length > 1 &&
        position == path.cells[path.cells.length - 2]) {
      path.cells.removeLast();
      path.connected = false;
      return true;
    }
    if (path.connected) {
      return false;
    }
    if (_isOccupied(position)) {
      return false;
    }

    final endpointColor = _endpointColors[position];
    if (endpointColor != null && endpointColor != color) {
      return false;
    }

    path.cells.add(position);
    if (endpointColor == color && position != path.cells.first) {
      path.connected = true;
      if (isComplete) {
        _inputLocked = true;
        _onCompleted?.call();
      }
    }
    return true;
  }

  void endPath() {
    final color = _activeColor;
    if (color != null && !_paths[color]!.connected) {
      _paths.remove(color);
    }
    _activeColor = null;
  }

  void restart() {
    _paths.clear();
    _activeColor = null;
    _inputLocked = false;
  }

  bool _isInBounds(GridPosition position) =>
      position.x >= 0 &&
      position.x < _level.size &&
      position.y >= 0 &&
      position.y < _level.size;

  bool _isOccupied(GridPosition position) =>
      _paths.values.any((path) => path.cells.contains(position));
}

final class _MutablePath {
  _MutablePath(this.cells);

  final List<GridPosition> cells;
  bool connected = false;
}
