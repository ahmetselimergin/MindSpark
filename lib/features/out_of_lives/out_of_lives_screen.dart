import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class OutOfLivesScreen extends ConsumerStatefulWidget {
  const OutOfLivesScreen({super.key, required this.levelId});

  final int levelId;

  @override
  ConsumerState<OutOfLivesScreen> createState() => _OutOfLivesScreenState();
}

class _OutOfLivesScreenState extends ConsumerState<OutOfLivesScreen> {
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
    final progress = ref.watch(appProgressControllerProvider).value;
    final now = ref.read(clockProvider)();
    final livesNow = progress == null
        ? 0
        : LivesRegen.reconcile(
            lives: progress.lives,
            anchor: progress.livesRegenAnchor,
            now: now,
          ).lives;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're out of lives",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 24),
                const LivesBar(),
                const SizedBox(height: 32),
                if (livesNow > 0)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed(
                      AppRoutes.gameplay,
                      arguments: GameplayRouteArgs(widget.levelId),
                    ),
                    child: const Text('CONTINUE'),
                  )
                else
                  const FilledButton(
                    onPressed: null,
                    child: Text('WATCH AD (COMING SOON)'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: const Text('MAIN MENU'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
