import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/widgets/image_button.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.levelId,
    required this.awardedScore,
    required this.stars,
  });

  final int levelId;
  final int awardedScore;
  final int stars;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

final class _ResultScreenState extends ConsumerState<ResultScreen> {
  static const _plankBrown = Color(0xFF5B3A1A);

  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final totalScore = ref
        .watch(appProgressControllerProvider)
        .requireValue
        .totalScore;
    final nextLevelId = widget.levelId + 1; // endless

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardWidth = constraints.maxWidth.clamp(0.0, 420.0) - 24;
              return SizedBox(
                width: boardWidth,
                child: AspectRatio(
                  aspectRatio: 3476 / 4031, // wonboard.png
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          AppImages.wonBoard,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, -0.78),
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: StatusBadge(stars: widget.stars),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, -0.35),
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          child: Image.asset(AppImages.starN(widget.stars)),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.18),
                        child: Text(
                          'Score  $totalScore   (+${widget.awardedScore})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: _plankBrown),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.62),
                        child: FractionallySizedBox(
                          widthFactor: 0.66,
                          child: ImageButton(
                            asset: AppImages.nextButton,
                            semanticLabel: 'Next level',
                            onPressed: _navigating
                                ? null
                                : () => _navigate(nextLevelId),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-0.92, -0.98),
                        child: IconButton(
                          icon: const Icon(Icons.home_rounded),
                          color: _plankBrown,
                          tooltip: 'Main menu',
                          onPressed: _navigating
                              ? null
                              : () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      AppRoutes.home,
                                      (_) => false,
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigate(int nextLevelId) {
    if (_navigating) {
      return;
    }
    setState(() => _navigating = true);
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.gameplay,
      arguments: GameplayRouteArgs(nextLevelId),
    );
  }
}
