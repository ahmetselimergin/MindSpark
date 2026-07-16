import 'grid_position.dart';

final class PathState {
  const PathState({
    required this.color,
    required this.cells,
    required this.connected,
  });

  final String color;
  final List<GridPosition> cells;
  final bool connected;
}
