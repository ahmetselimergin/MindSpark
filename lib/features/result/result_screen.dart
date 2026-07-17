import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';

final class ResultScreen extends ConsumerWidget {
  const ResultScreen({
    super.key,
    required this.levelId,
    required this.awardedScore,
  });

  final int levelId;
  final int awardedScore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(levelsProvider).requireValue;
    final index = levels.indexWhere((level) => level.id == levelId);
    if (index < 0) {
      return const _ResultLoadError();
    }
    final nextLevelId = index + 1 < levels.length ? levels[index + 1].id : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SparkTrail(),
                const SizedBox(height: 22),
                Text(
                  'LEVEL COMPLETE',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 29,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 44),
                Text(
                  '+$awardedScore',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 88,
                    color: AppColors.sparkYellow,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  awardedScore == 0 ? 'Already collected' : 'Spark score',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.frost.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 52),
                FilledButton(
                  onPressed: () {
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
                  },
                  child: Text(nextLevelId == null ? 'HOME' : 'NEXT LEVEL'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ResultLoadError extends StatelessWidget {
  const _ResultLoadError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This result could not be opened.')),
    );
  }
}
