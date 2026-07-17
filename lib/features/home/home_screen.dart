import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _openingGame = false;

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(levelsProvider).requireValue;
    final progress = ref.watch(appProgressControllerProvider).requireValue;
    final currentLevelIndex = levels.indexWhere(
      (level) => level.id == progress.highestUnlockedLevel,
    );
    if (currentLevelIndex < 0) {
      return _HomeContentError(
        onRetry: () {
          ref.invalidate(levelsProvider);
          ref.invalidate(appProgressControllerProvider);
        },
      );
    }
    final currentLevel = levels[currentLevelIndex];

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
                      SizedBox(height: compact ? 8 : 16),
                      Text(
                        'MindSpark',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontSize: 30, letterSpacing: -.4),
                      ),
                      SizedBox(height: compact ? 20 : 46),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currentLevel.id}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: 112,
                                  height: .85,
                                  color: AppColors.sparkYellow,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Level ${currentLevel.id}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Best Score: ${progress.totalScore}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.frost.withAlpha(190),
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 48),
                      FilledButton(
                        onPressed: _openingGame
                            ? null
                            : () => _openGame(currentLevel.id),
                        child: const Text('PLAY'),
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

  Future<void> _openGame(int levelId) async {
    if (_openingGame) {
      return;
    }
    setState(() => _openingGame = true);
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.gameplay, arguments: GameplayRouteArgs(levelId));
    if (mounted) {
      setState(() => _openingGame = false);
    }
  }
}

final class _HomeContentError extends StatelessWidget {
  const _HomeContentError({required this.onRetry});

  final VoidCallback onRetry;

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
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.coralPulse,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Saved progress does not match the available levels.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
