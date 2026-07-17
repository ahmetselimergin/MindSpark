import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_theme.dart';

final class SparkTrail extends StatelessWidget {
  const SparkTrail({super.key, this.width = 92, this.height = 42});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: const _SparkTrailPainter()),
    );
  }
}

final class _SparkTrailPainter extends CustomPainter {
  const _SparkTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.72),
      Offset(size.width * 0.5, size.height * 0.24),
      Offset(size.width * 0.88, size.height * 0.58),
    ];
    final line = Paint()
      ..color = AppColors.electricCyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(points[0], points[1], line);
    canvas.drawLine(points[1], points[2], line);

    final node = Paint()..color = AppColors.sparkYellow;
    for (final point in points) {
      canvas.drawCircle(point, 5, node);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkTrailPainter oldDelegate) => false;
}
