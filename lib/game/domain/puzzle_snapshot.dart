import 'path_state.dart';

final class PuzzleSnapshot {
  const PuzzleSnapshot({
    required this.size,
    required this.paths,
    required this.isComplete,
  });

  final int size;
  final Map<String, PathState> paths;
  final bool isComplete;
}
