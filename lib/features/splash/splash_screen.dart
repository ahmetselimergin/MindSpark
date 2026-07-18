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
    final progress = ref.watch(appProgressControllerProvider);
    final currentId = progress.value?.highestUnlockedLevel ?? 1;
    final levels = ref.watch(levelByIdProvider(currentId));

    if (_isReady(levels) && _isReady(progress) && !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final currentLevels = ref.read(levelByIdProvider(currentId));
        final currentProgress = ref.read(appProgressControllerProvider);
        if (_isReady(currentLevels) && _isReady(currentProgress)) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          _navigationScheduled = false;
        }
      });
    }

    final error = levels.error ?? progress.error;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SparkTrail(),
                    const SizedBox(height: 20),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'MindSpark',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(fontSize: 46, letterSpacing: -1),
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
        ),
      ),
    );
  }

  void _retry() {
    _navigationScheduled = false;
    final id =
        ref.read(appProgressControllerProvider).value?.highestUnlockedLevel ??
        1;
    ref.invalidate(levelByIdProvider(id));
    ref.invalidate(appProgressControllerProvider);
  }
}

bool _isReady(AsyncValue<Object?> value) {
  return value.hasValue && !value.hasError && !value.isLoading;
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
