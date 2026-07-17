import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

final class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigationScheduled = false;

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(levelsProvider);
    final progress = ref.watch(appProgressControllerProvider);

    if (levels.hasValue && progress.hasValue && !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      });
    }

    final error = levels.error ?? progress.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SparkTrail(),
                const SizedBox(height: 20),
                Text(
                  'MindSpark',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 46,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 28),
                if (error == null)
                  const CircularProgressIndicator()
                else
                  _InitializationError(
                    isLevelError: levels.hasError,
                    onRetry: _retry,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry() {
    _navigationScheduled = false;
    ref.invalidate(levelsProvider);
    ref.invalidate(appProgressControllerProvider);
  }
}

final class _InitializationError extends StatelessWidget {
  const _InitializationError({
    required this.isLevelError,
    required this.onRetry,
  });

  final bool isLevelError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.coralPulse),
        const SizedBox(height: 12),
        Text(
          isLevelError
              ? 'Levels could not be loaded.'
              : 'Progress could not be loaded.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Check the app data and try again.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.frost.withAlpha(180),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onRetry, child: const Text('RETRY')),
      ],
    );
  }
}
