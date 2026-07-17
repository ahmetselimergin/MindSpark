import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(levelsProvider).requireValue;
    final progress = ref.watch(appProgressControllerProvider).requireValue;
    final currentLevel = levels.firstWhere(
      (level) => level.id == progress.highestUnlockedLevel,
      orElse: () => levels.first,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SparkTrail(),
                const SizedBox(height: 16),
                Text(
                  'MindSpark',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 46),
                Text(
                  '${currentLevel.id}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 112,
                    height: .85,
                    color: AppColors.sparkYellow,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Level ${currentLevel.id}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Best Score: ${progress.totalScore}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.frost.withAlpha(190),
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.gameplay,
                    arguments: GameplayRouteArgs(currentLevel.id),
                  ),
                  child: const Text('PLAY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
