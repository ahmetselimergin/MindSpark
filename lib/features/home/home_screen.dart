import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/features/home/widgets/level_map_view.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appProgressControllerProvider.notifier).reconcileLives();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(appProgressControllerProvider);
    return progressAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _HomeContentError(
        onRetry: () => ref.invalidate(appProgressControllerProvider),
      ),
      data: (progress) => _buildHome(context, progress),
    );
  }

  Widget _buildHome(BuildContext context, PlayerProgress progress) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(AppImages.background, fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 700;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
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
                          const SizedBox(height: 12),
                          const LivesBar(),
                          SizedBox(height: compact ? 16 : 32),
                          const SizedBox(height: 220, child: LevelMapView()),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              color: AppColors.frost,
              tooltip: 'Settings',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
          ),
        ],
      ),
    );
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
                  'Saved progress could not be loaded.',
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
