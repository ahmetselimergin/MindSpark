import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/game/generation/level_timer.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

typedef MindSparkGameFactory =
    MindSparkGame Function(LevelModel level, VoidCallback onCompleted);

final mindSparkGameFactoryProvider = Provider<MindSparkGameFactory>(
  (ref) =>
      (level, onCompleted) =>
          MindSparkGame(level: level, onCompleted: onCompleted),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('RETRY'),
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
      timeLimit: _timeLimit,
      lives: ref.watch(appProgressControllerProvider).value?.lives ?? 0,
      saveFailed: _saveFailed,
      needsProgressReload: _needsProgressReload,
      saving: _saving,
      onRestart: game.restart,
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
    required this.timeLimit,
    required this.lives,
    required this.saveFailed,
    required this.needsProgressReload,
    required this.saving,
    required this.onRestart,
    required this.onRetry,
  });

  final int levelId;
  final MindSparkGame game;
  final Duration remaining;
  final Duration timeLimit;
  final int lives;
  final bool saveFailed;
  final bool needsProgressReload;
  final bool saving;
  final VoidCallback onRestart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Level $levelId',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.home_rounded),
                    color: AppColors.frost,
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  ),
                  TextButton(
                    onPressed: onRestart,
                    child: const Text('RESTART'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCountdown(remaining),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          color: remaining.inSeconds <= 10
                              ? AppColors.coralPulse
                              : AppColors.frost,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: timeLimit.inMilliseconds == 0
                          ? 0
                          : (remaining.inMilliseconds / timeLimit.inMilliseconds)
                                .clamp(0.0, 1.0),
                      backgroundColor: AppColors.deepCircuit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  HeartsRow(lives: lives, size: 16),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: ColoredBox(
                        color: AppColors.deepCircuit,
                        child: GameWidget(game: game),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (saveFailed)
                _SaveFailure(
                  needsProgressReload: needsProgressReload,
                  saving: saving,
                  onRetry: onRetry,
                )
              else
                Text(
                  'Connect matching sparks to fill the board.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.frost.withAlpha(180),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
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
