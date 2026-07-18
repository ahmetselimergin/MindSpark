import 'dart:math';

import 'package:mind_spark/game/generation/level_difficulty.dart';
import 'package:mind_spark/models/level_model.dart';

/// A generated level plus its witness solution (one path per colour, in
/// palette order). The witness is a legal solution, so the level is solvable.
class GeneratedLevel {
  const GeneratedLevel({required this.level, required this.solution});

  final LevelModel level;
  final List<List<Point<int>>> solution;
}

/// Deterministically generates solvable levels by partitioning the board into
/// non-crossing colour paths that cover every cell.
class ProceduralLevelGenerator {
  const ProceduralLevelGenerator({this.seedSalt = 0x9E3779B9});

  final int seedSalt;

  static const List<String> _palette = [
    'red', 'blue', 'green', 'yellow', 'purple', 'orange',
  ];

  static const List<Point<int>> _deltas = [
    Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1),
  ];

  GeneratedLevel generate(int id) {
    final base = difficultyForLevel(id);
    final rng = Random(id ^ seedSalt);
    // Deterministic relaxation: hold the seed, relax minLen fully, then colours,
    // until a cover is found. Guarantees termination with a reproducible result.
    for (var colors = base.colors; colors >= 2; colors--) {
      for (var minLen = base.minLen; minLen >= 2; minLen--) {
        final cover = _tryCover(base.size, colors, minLen, rng);
        if (cover != null) {
          return _toGeneratedLevel(id, base.size, cover);
        }
      }
    }
    throw StateError('failed to generate level $id');
  }

  List<List<Point<int>>>? _tryCover(int size, int k, int minLen, Random rng) {
    final avg = size * size / k;
    final maxLen = max(minLen + 1, (avg * 1.6).round());
    for (var attempt = 0; attempt < 10000; attempt++) {
      final cover = _oneCover(size, k, minLen, maxLen, rng);
      if (cover != null) {
        return cover;
      }
    }
    return null;
  }

  List<List<Point<int>>>? _oneCover(
      int size, int k, int minLen, int maxLen, Random rng) {
    final uncovered = <Point<int>>{
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++) Point(x, y),
    };
    final paths = <List<Point<int>>>[];
    while (uncovered.isNotEmpty) {
      if (paths.length >= k) {
        return null;
      }
      final start = uncovered.elementAt(rng.nextInt(uncovered.length));
      final path = <Point<int>>[start];
      uncovered.remove(start);
      var cur = start;
      final target = minLen + rng.nextInt(maxLen - minLen + 1);
      while (path.length < target) {
        final opts = _neighbors(cur, size).where(uncovered.contains).toList();
        if (opts.isEmpty) {
          break;
        }
        final next = opts[rng.nextInt(opts.length)];
        path.add(next);
        uncovered.remove(next);
        cur = next;
      }
      if (path.length < minLen) {
        return null;
      }
      paths.add(path);
    }
    if (paths.length != k) {
      return null;
    }
    var longest = 0;
    for (final p in paths) {
      longest = max(longest, p.length);
    }
    if (longest > maxLen + 1) {
      return null;
    }
    return paths;
  }

  Iterable<Point<int>> _neighbors(Point<int> c, int size) sync* {
    for (final d in _deltas) {
      final nx = c.x + d.x;
      final ny = c.y + d.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        yield Point(nx, ny);
      }
    }
  }

  GeneratedLevel _toGeneratedLevel(
      int id, int size, List<List<Point<int>>> cover) {
    final points = <GridPoint>[];
    for (var i = 0; i < cover.length; i++) {
      final color = _palette[i];
      final path = cover[i];
      final a = path.first;
      final b = path.last;
      points.add(GridPoint(x: a.x, y: a.y, color: color));
      points.add(GridPoint(x: b.x, y: b.y, color: color));
    }
    final level = LevelModel(
      id: id,
      size: size,
      points: List<GridPoint>.unmodifiable(points),
    );
    return GeneratedLevel(level: level, solution: cover);
  }
}
