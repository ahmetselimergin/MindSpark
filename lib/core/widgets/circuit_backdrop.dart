import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Static, non-interactive circuit traces shared by the arcade-blueprint shell.
final class CircuitBackdrop extends StatelessWidget {
  const CircuitBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.voidNavy,
      child: CustomPaint(
        painter: const _CircuitBackdropPainter(),
        child: child,
      ),
    );
  }
}

final class _CircuitBackdropPainter extends CustomPainter {
  const _CircuitBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final trace = Paint()
      ..color = AppColors.gridBlue.withAlpha(82)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    final node = Paint()..color = AppColors.sparkCyan.withAlpha(52);

    final upper = Path()
      ..moveTo(0, size.height * 0.17)
      ..lineTo(size.width * 0.16, size.height * 0.17)
      ..lineTo(size.width * 0.16, size.height * 0.08)
      ..lineTo(size.width * 0.36, size.height * 0.08);
    final lower = Path()
      ..moveTo(size.width, size.height * 0.79)
      ..lineTo(size.width * 0.83, size.height * 0.79)
      ..lineTo(size.width * 0.83, size.height * 0.91)
      ..lineTo(size.width * 0.61, size.height * 0.91);
    final side = Path()
      ..moveTo(size.width, size.height * 0.31)
      ..lineTo(size.width * 0.92, size.height * 0.31)
      ..lineTo(size.width * 0.92, size.height * 0.46);

    canvas
      ..drawPath(upper, trace)
      ..drawPath(lower, trace)
      ..drawPath(side, trace)
      ..drawCircle(Offset(size.width * 0.36, size.height * 0.08), 2.5, node)
      ..drawCircle(Offset(size.width * 0.61, size.height * 0.91), 2.5, node)
      ..drawCircle(Offset(size.width * 0.92, size.height * 0.46), 2.5, node);
  }

  @override
  bool shouldRepaint(covariant _CircuitBackdropPainter oldDelegate) => false;
}
