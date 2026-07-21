import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A one-shot hint that fades in, holds, and fades out whenever [trigger]
/// increases. It occupies no space (renders nothing) while idle.
final class StuckHintFlash extends StatefulWidget {
  const StuckHintFlash({
    super.key,
    required this.trigger,
    required this.message,
  });

  final int trigger;
  final String message;

  @override
  State<StuckHintFlash> createState() => _StuckHintFlashState();
}

final class _StuckHintFlashState extends State<StuckHintFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _visible = false);
          }
        });
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(StuckHintFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.deepCircuit.withAlpha(230),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          widget.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.frost,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
