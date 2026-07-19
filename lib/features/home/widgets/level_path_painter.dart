import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';

/// Segments to connect on the map: a dash between card i and i+1 iff neither
/// endpoint is locked (i.e. only along the played trail).
List<(Offset, Offset)> trailSegments(
  List<Offset> centers,
  List<LevelCardStatus> statuses,
) {
  final segments = <(Offset, Offset)>[];
  for (var i = 0; i + 1 < centers.length; i++) {
    if (statuses[i] != LevelCardStatus.locked &&
        statuses[i + 1] != LevelCardStatus.locked) {
      segments.add((centers[i], centers[i + 1]));
    }
  }
  return segments;
}

/// Draws dashed, gently-arched connectors between consecutive card centers on
/// the played trail.
class LevelPathPainter extends CustomPainter {
  const LevelPathPainter({required this.centers, required this.statuses});

  final List<Offset> centers;
  final List<LevelCardStatus> statuses;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.frost.withAlpha(179)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final (from, to) in trailSegments(centers, statuses)) {
      final control = Offset(
        (from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2 - 24,
      );
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
      _drawDashed(canvas, path, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0;
    const gap = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(LevelPathPainter old) =>
      !listEquals(old.centers, centers) || !listEquals(old.statuses, statuses);
}
