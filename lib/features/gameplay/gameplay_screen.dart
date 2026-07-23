import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/ads/interstitial_ad_controller.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/ad_banner_slot.dart';
import 'package:mind_spark/core/widgets/circuit_backdrop.dart';
import 'package:mind_spark/core/widgets/image_button.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/core/widgets/stuck_hint_flash.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/game/generation/level_timer.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

typedef MindSparkGameFactory =
    MindSparkGame Function(
      LevelModel level,
      VoidCallback onCompleted,
      VoidCallback onAllPairsConnected,
    );

final mindSparkGameFactoryProvider = Provider<MindSparkGameFactory>(
  (ref) =>
      (level, onCompleted, onAllPairsConnected) => MindSparkGame(
        level: level,
        onCompleted: onCompleted,
        onAllPairsConnected: onAllPairsConnected,
      ),
);

/// The per-level time budget, injectable so tests can shorten it.
final levelTimerProvider = Provider<Duration Function(int size)>(
  (ref) => levelTimeLimit,
);

final class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.levelId});

  final int levelId;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

final class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with WidgetsBindingObserver {
  MindSparkGame? _game;
  bool _completionHandled = false;
  bool _saveFailed = false;
  bool _needsProgressReload = false;
  bool _saving = false;
  bool _navigated = false;
  int _awardedScore = 0;
  int _stars = 1;
  Timer? _countdown;
  Duration _timeLimit = Duration.zero;
  Duration _remaining = Duration.zero;
  bool _paused = false;
  bool _timerStarted = false;
  bool _redirectedOutOfLives = false;
  int _stuckFlashTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(interstitialAdControllerProvider); // preload the interstitial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appProgressControllerProvider.notifier).reconcileLives();
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The level countdown pauses off-foreground; lives regen is wall-clock.
    _paused = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      ref.read(appProgressControllerProvider.notifier).reconcileLives();
    }
  }

  void _startTimer(int boardSize) {
    if (_timerStarted) {
      return;
    }
    _timerStarted = true;
    _timeLimit = ref.read(levelTimerProvider)(boardSize);
    _remaining = _timeLimit;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _handleAllPairsConnected() {
    if (!mounted) {
      return;
    }
    setState(() => _stuckFlashTick++);
  }

  void _goHome() {
    ref.read(interstitialAdControllerProvider).maybeShowOnHome();
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  void _tick() {
    if (!mounted || _paused || _completionHandled || _navigated) {
      return;
    }
    setState(() {
      _remaining -= const Duration(seconds: 1);
    });
    if (_remaining <= Duration.zero) {
      _countdown?.cancel();
      unawaited(_handleTimeout());
    }
  }

  Future<void> _handleTimeout() async {
    await ref.read(appProgressControllerProvider.notifier).spendLife();
    if (!mounted) {
      return;
    }
    final livesLeft = ref.read(appProgressControllerProvider).value?.lives ?? 0;
    if (livesLeft <= 0) {
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.outOfLives,
        arguments: OutOfLivesRouteArgs(widget.levelId),
      );
      return;
    }
    // Lives remain: let the player choose to retry the level or go home.
    final retry = await _showTimeUpDialog(livesLeft);
    if (!mounted) {
      return;
    }
    if (retry) {
      _game?.restart();
      setState(() {
        _remaining = _timeLimit;
      });
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _navigated = true;
      ref.read(interstitialAdControllerProvider).maybeShowOnHome();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  Future<bool> _showTimeUpDialog(int livesLeft) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Time's up!"),
        content: Text(
          'You lost a life. $livesLeft ${livesLeft == 1 ? 'life' : 'lives'} left.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('HOME'),
          ),
          ImageButton(
            asset: AppImages.replayButton,
            semanticLabel: 'Retry',
            width: 64,
            height: 64,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(appProgressControllerProvider);
    final levelState = ref.watch(levelByIdProvider(widget.levelId));
    final existingGame = _game;
    if (existingGame != null) {
      return _buildGame(existingGame);
    }
    if (levelState.hasError || progressState.hasError) {
      return const _GameplayLoadError();
    }
    final level = levelState.value;
    final progress = progressState.value;
    if (level == null || progress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.levelId < 1 || widget.levelId > progress.highestUnlockedLevel) {
      return const _GameplayLoadError();
    }
    final now = ref.read(clockProvider)();
    final livesNow = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    ).lives;
    if (livesNow <= 0) {
      if (!_redirectedOutOfLives) {
        _redirectedOutOfLives = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.outOfLives,
              arguments: OutOfLivesRouteArgs(widget.levelId),
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = _game = ref.read(mindSparkGameFactoryProvider)(
      level,
      _handleCompletion,
      _handleAllPairsConnected,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startTimer(level.size);
      }
    });
    return _buildGame(game);
  }

  Widget _buildGame(MindSparkGame game) {
    return _GameplayView(
      levelId: widget.levelId,
      game: game,
      remaining: _remaining,
      lives: ref.watch(appProgressControllerProvider).value?.lives ?? 0,
      saveFailed: _saveFailed,
      needsProgressReload: _needsProgressReload,
      saving: _saving,
      stuckFlashTick: _stuckFlashTick,
      onRestart: game.restart,
      onHome: _goHome,
      onRetry: _needsProgressReload ? _retryProgress : _retrySave,
    );
  }

  Future<void> _handleCompletion() async {
    if (_completionHandled) {
      return;
    }
    _completionHandled = true;
    _countdown?.cancel();
    _stars = starsForResult(remaining: _remaining, timeLimit: _timeLimit);

    final before = ref.read(appProgressControllerProvider).value;
    if (before == null) {
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _needsProgressReload = true;
        });
      }
      return;
    }
    final nextLevelId = widget.levelId + 1; // endless: always a next level

    await ref
        .read(appProgressControllerProvider.notifier)
        .completeLevel(
          levelId: widget.levelId,
          nextLevelId: nextLevelId,
          stars: _stars,
        );
    if (!mounted) {
      return;
    }
    ref.read(celebrateLevelProvider.notifier).state = widget.levelId;
    final savedState = ref.read(appProgressControllerProvider);
    final after = savedState.value;
    _awardedScore =
        after != null &&
            !before.completedLevelIds.contains(widget.levelId) &&
            after.completedLevelIds.contains(widget.levelId)
        ? 100
        : 0;
    final completionPersisted =
        savedState.hasValue &&
        !savedState.hasError &&
        after != null &&
        after.completedLevelIds.contains(widget.levelId);
    if (!completionPersisted) {
      setState(() {
        _saveFailed = true;
        _needsProgressReload = !ref
            .read(appProgressControllerProvider.notifier)
            .hasPendingSave;
      });
      return;
    }
    _navigateToResult();
  }

  Future<void> _retrySave() async {
    if (_saving || _navigated) {
      return;
    }
    setState(() => _saving = true);
    await ref.read(appProgressControllerProvider.notifier).retryLastSave();
    if (!mounted) {
      return;
    }
    final savedState = ref.read(appProgressControllerProvider);
    final savedProgress = savedState.value;
    final completionPersisted =
        savedState.hasValue &&
        !savedState.hasError &&
        savedProgress != null &&
        savedProgress.completedLevelIds.contains(widget.levelId);
    if (!completionPersisted) {
      setState(() {
        _saving = false;
        _needsProgressReload = !ref
            .read(appProgressControllerProvider.notifier)
            .hasPendingSave;
      });
      return;
    }
    _navigateToResult();
  }

  Future<void> _retryProgress() async {
    if (_saving || _navigated) {
      return;
    }
    setState(() => _saving = true);
    ref.invalidate(appProgressControllerProvider);
    try {
      await ref.read(appProgressControllerProvider.future);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = false;
      _needsProgressReload = false;
      _completionHandled = false;
    });
    await _handleCompletion();
  }

  void _navigateToResult() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    ref.read(interstitialAdControllerProvider).maybeShowOnLevelComplete();
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.result,
      arguments: ResultRouteArgs(
        levelId: widget.levelId,
        awardedScore: _awardedScore,
        stars: _stars,
      ),
    );
  }
}

final class _GameplayView extends StatelessWidget {
  const _GameplayView({
    required this.levelId,
    required this.game,
    required this.remaining,
    required this.lives,
    required this.saveFailed,
    required this.needsProgressReload,
    required this.saving,
    required this.stuckFlashTick,
    required this.onRestart,
    required this.onHome,
    required this.onRetry,
  });

  final int levelId;
  final MindSparkGame game;
  final Duration remaining;
  final int lives;
  final bool saveFailed;
  final bool needsProgressReload;
  final bool saving;
  final int stuckFlashTick;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: level number.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Level $levelId',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    // Center: countdown as plain text (no progress bar).
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCountdown(remaining),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: remaining.inSeconds <= 10
                                      ? AppColors.coralPulse
                                      : AppColors.frost,
                                ),
                          ),
                        ),
                      ),
                    ),
                    // Right: replay + home buttons, with lives below them.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ImageButton(
                                asset: AppImages.replayButton,
                                semanticLabel: 'Restart',
                                width: 40,
                                height: 40,
                                onPressed: onRestart,
                              ),
                              const SizedBox(width: 8),
                              ImageButton(
                                asset: AppImages.homeButton,
                                semanticLabel: 'Home',
                                width: 40,
                                height: 40,
                                onPressed: onHome,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          HeartsRow(lives: lives, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxHeight - constraints.maxWidth < 170;
                      final boardSide = math.min(
                        constraints.maxWidth,
                        compact
                            ? constraints.maxHeight * 0.7
                            : constraints.maxWidth,
                      );
                      return Column(
                        children: [
                          SizedBox.square(
                            dimension: boardSide,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: AppColors.gridBlue,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.sparkCyan.withAlpha(
                                            24,
                                          ),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: ColoredBox(
                                        color: AppColors.panelNavy,
                                        child: GameWidget(game: game),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 8,
                                  child: Center(
                                    child: StuckHintFlash(
                                      trigger: stuckFlashTick,
                                      message:
                                          'All linked — now fill every square!',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Connect every pair. Fill every square.',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.cloud.withAlpha(190),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.35,
                                ),
                          ),
                          if (!compact) ...[const Spacer(), const _GoalStrip()],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                if (saveFailed)
                  _SaveFailure(
                    needsProgressReload: needsProgressReload,
                    saving: saving,
                    onRetry: onRetry,
                  )
                else
                  const AdBannerSlot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _GoalStrip extends StatelessWidget {
  const _GoalStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.panelNavy.withAlpha(210),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridBlue),
      ),
      child: Row(
        children: [
          const Expanded(
            child: _GoalItem(icon: Icons.grid_4x4_rounded, label: 'FULL GRID'),
          ),
          Container(width: 1, height: 28, color: AppColors.gridBlue),
          const Expanded(
            child: _GoalItem(
              icon: Icons.alt_route_rounded,
              label: 'NO OVERLAPS',
            ),
          ),
        ],
      ),
    );
  }
}

final class _GoalItem extends StatelessWidget {
  const _GoalItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.sparkCyan),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11,
                letterSpacing: 1,
                color: AppColors.cloud.withAlpha(210),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _SaveFailure extends StatelessWidget {
  const _SaveFailure({
    required this.needsProgressReload,
    required this.saving,
    required this.onRetry,
  });

  final bool needsProgressReload;
  final bool saving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          needsProgressReload
              ? 'Progress must be loaded again.'
              : 'Progress was not saved.',
          style: const TextStyle(color: AppColors.coralPulse),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: saving ? null : onRetry,
          child: Text(
            saving
                ? 'SAVING…'
                : needsProgressReload
                ? 'RETRY PROGRESS'
                : 'RETRY SAVE',
          ),
        ),
      ],
    );
  }
}

final class _GameplayLoadError extends StatelessWidget {
  const _GameplayLoadError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This level could not be opened.'),
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
    );
  }
}
