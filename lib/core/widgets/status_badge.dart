import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_images.dart';

/// Animated Good/Great/Perfect badge. Scales in with a slight overshoot and
/// fades in once on mount, then holds. Non-interactive; driven purely by
/// [stars] (1..3). Calls [onCompleted] when the entrance animation finishes.
final class StatusBadge extends StatefulWidget {
  const StatusBadge({
    super.key,
    required this.stars,
    this.width = 220,
    this.autoPlay = true,
    this.onCompleted,
  });

  final int stars;
  final double width;
  final bool autoPlay;
  final VoidCallback? onCompleted;

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _controller.forward().whenComplete(() {
        if (mounted) {
          widget.onCompleted?.call();
        }
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Image.asset(
            AppImages.statusForStars(widget.stars),
            width: widget.width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
