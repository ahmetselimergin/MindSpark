import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';

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
    final levels = ref.watch(levelsProvider).requireValue;
    final index = levels.indexWhere((level) => level.id == widget.levelId);
    if (index < 0) {
      return const _ResultLoadError();
    }
    final nextLevelId = index + 1 < levels.length ? levels[index + 1].id : null;

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
                      SizedBox(height: compact ? 24 : 52),
                      FilledButton(
                        onPressed: _navigating
                            ? null
                            : () => _navigate(nextLevelId),
                        child: Text(
                          nextLevelId == null ? 'HOME' : 'NEXT LEVEL',
                        ),
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

  void _navigate(int? nextLevelId) {
    if (_navigating) {
      return;
    }
    setState(() => _navigating = true);
    if (nextLevelId == null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } else {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.gameplay,
        arguments: GameplayRouteArgs(nextLevelId),
      );
    }
  }
}

final class _ResultLoadError extends StatelessWidget {
  const _ResultLoadError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This result could not be opened.'),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: const Text('HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
