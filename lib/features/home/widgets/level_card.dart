import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';

enum LevelCardStatus { completed, current, locked }

const double kLevelCardWidth = 92;
const double kLevelCardHeight = 108;

const Color _currentOrange = Color(0xFFFF8A00);
const Color _completedDeep = Color(0xFF2A78B8);

/// A single level node on the home map. Presentation only — all state is
/// passed in. Current cards use a static glow (no looping animation).
final class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.levelId,
    required this.status,
    required this.stars,
    required this.onTap,
  });

  final int levelId;
  final LevelCardStatus status;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      LevelCardStatus.current => 'Play',
      LevelCardStatus.completed => 'Replay level $levelId',
      LevelCardStatus.locked => 'Level $levelId locked',
    };
    return Semantics(
      button: status != LevelCardStatus.locked,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: kLevelCardWidth,
          height: kLevelCardHeight,
          // The number/stars are purely decorative for accessibility — the
          // Semantics label above already conveys the full accessible name.
          // Without this, Flutter merges the descendant Text/Image semantics
          // into this node (no boundary in between), producing "Play\n3"
          // instead of "Play".
          child: ExcludeSemantics(child: _face()),
        ),
      ),
    );
  }

  Widget _face() {
    switch (status) {
      case LevelCardStatus.current:
        return _CardBox(
          gradient: const [AppColors.sparkYellow, _currentOrange],
          glow: AppColors.sparkYellow,
          child: _number(),
        );
      case LevelCardStatus.completed:
        return _CardBox(
          gradient: const [AppColors.electricCyan, _completedDeep],
          glow: AppColors.electricCyan.withAlpha(120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_number(), const SizedBox(height: 8), _stars()],
          ),
        );
      case LevelCardStatus.locked:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.frost.withAlpha(120), width: 2),
          ),
          child: Center(child: _number(dim: true)),
        );
    }
  }

  Widget _number({bool dim = false}) => Text(
    '$levelId',
    style: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: dim ? AppColors.frost.withAlpha(150) : AppColors.frost,
    ),
  );

  Widget _stars() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Opacity(
          opacity: i < stars ? 1 : 0.28,
          child: Image.asset(AppImages.star, width: 16, height: 16),
        ),
    ],
  );
}

class _CardBox extends StatelessWidget {
  const _CardBox({
    required this.gradient,
    required this.glow,
    required this.child,
  });

  final List<Color> gradient;
  final Color glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Center(child: child),
    );
  }
}
