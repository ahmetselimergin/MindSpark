import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

/// Hearts row + "next life" countdown, kept live by a 1 Hz ticker. Persists a
/// regenerated life through [AppProgressController.reconcileLives].
final class LivesBar extends ConsumerStatefulWidget {
  const LivesBar({super.key});

  @override
  ConsumerState<LivesBar> createState() => _LivesBarState();
}

class _LivesBarState extends ConsumerState<LivesBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    final progress = ref.read(appProgressControllerProvider).value;
    if (progress == null) {
      return;
    }
    final now = ref.read(clockProvider)();
    final result = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    );
    if (result.lives != progress.lives ||
        result.anchor != progress.livesRegenAnchor) {
      ref.read(appProgressControllerProvider.notifier).reconcileLives(now: now);
    } else {
      setState(() {}); // refresh the countdown text
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(appProgressControllerProvider).value;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final now = ref.read(clockProvider)();
    final result = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeartsRow(lives: result.lives),
        if (result.untilNextLife != null) ...[
          const SizedBox(height: 6),
          Text(
            'Next life ${formatCountdown(result.untilNextLife!)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.frost.withAlpha(180),
            ),
          ),
        ],
      ],
    );
  }
}

/// MM:SS for a non-negative countdown; shared by lives + gameplay timers.
String formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final minutes = clamped.inMinutes.toString().padLeft(2, '0');
  final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// A row of heart.png icons: [lives] filled, the remaining slots dimmed.
final class HeartsRow extends StatelessWidget {
  const HeartsRow({super.key, required this.lives, this.size = 26});

  final int lives;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < LivesRegen.maxLives; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: i < lives ? 1.0 : 0.25,
              child: Image.asset(AppImages.heart, width: size, height: size),
            ),
          ),
      ],
    );
  }
}
