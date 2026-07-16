final class GridPosition {
  const GridPosition(this.x, this.y);

  final int x;
  final int y;

  int manhattanDistanceTo(GridPosition other) =>
      (x - other.x).abs() + (y - other.y).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
