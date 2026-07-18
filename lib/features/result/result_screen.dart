import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.levelId,
    required this.awardedScore,
  });

  final int levelId;
  final int awardedScore;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

final class _ResultScreenState extends ConsumerState<ResultScreen> {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: compact ? 12 : 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SparkTrail(),
                      SizedBox(height: compact ? 12 : 22),
                      Text(
                        'LEVEL COMPLETE',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontSize: 29, letterSpacing: 1.2),
                      ),
                      SizedBox(height: compact ? 20 : 44),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '+${widget.awardedScore}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: 88,
                                  color: AppColors.sparkYellow,
                                  height: 1,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.awardedScore == 0
                            ? 'Already collected'
                            : 'Spark score',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.frost.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Score: $totalScore',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: compact ? 24 : 52),
                      FilledButton(
                        onPressed: _navigating
                            ? null
                            : () => _navigate(nextLevelId),
                        child: const Text('NEXT LEVEL'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _navigating
                            ? null
                            : () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(
                                    AppRoutes.home,
                                    (_) => false,
                                  ),
                        child: const Text('HOME'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
