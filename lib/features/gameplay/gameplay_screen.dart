import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
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

final class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.levelId});

  final int levelId;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

final class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  MindSparkGame? _game;
  bool _completionHandled = false;
  bool _saveFailed = false;
  bool _saving = false;
  bool _navigated = false;
  int _awardedScore = 0;

  @override
  Widget build(BuildContext context) {
    final levelsState = ref.watch(levelsProvider);
    return levelsState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _GameplayLoadError(),
      data: (levels) {
        final level = _findLevel(levels, widget.levelId);
        if (level == null) {
          return const _GameplayLoadError();
        }
        final game = _game ??= ref.read(mindSparkGameFactoryProvider)(
          level,
          _handleCompletion,
        );
        return _GameplayView(
          levelId: level.id,
          game: game,
          saveFailed: _saveFailed,
          saving: _saving,
          onRestart: game.restart,
          onRetrySave: _retrySave,
        );
      },
    );
  }

  Future<void> _handleCompletion() async {
    if (_completionHandled) {
      return;
    }
    _completionHandled = true;

    final levels = ref.read(levelsProvider).requireValue;
    final before = ref.read(appProgressControllerProvider).value;
    if (before == null) {
      if (mounted) {
        setState(() => _saveFailed = true);
      }
      return;
    }
    final nextLevelId = _nextLevelId(levels, widget.levelId);

    await ref
        .read(appProgressControllerProvider.notifier)
        .completeLevel(levelId: widget.levelId, nextLevelId: nextLevelId);
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
    if (savedState.hasError) {
      setState(() => _saveFailed = true);
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
    if (savedState.hasError) {
      setState(() => _saving = false);
      return;
    }
    _navigateToResult();
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
      ),
    );
  }
}

final class _GameplayView extends StatelessWidget {
  const _GameplayView({
    required this.levelId,
    required this.game,
    required this.saveFailed,
    required this.saving,
    required this.onRestart,
    required this.onRetrySave,
  });

  final int levelId;
  final MindSparkGame game;
  final bool saveFailed;
  final bool saving;
  final VoidCallback onRestart;
  final VoidCallback onRetrySave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level $levelId',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                  ),
                  TextButton(
                    onPressed: onRestart,
                    child: const Text('RESTART'),
                  ),
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
                _SaveFailure(saving: saving, onRetry: onRetrySave)
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
  const _SaveFailure({required this.saving, required this.onRetry});

  final bool saving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Progress was not saved.',
          style: TextStyle(color: AppColors.coralPulse),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: saving ? null : onRetry,
          child: Text(saving ? 'SAVING…' : 'RETRY SAVE'),
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

LevelModel? _findLevel(List<LevelModel> levels, int id) {
  for (final level in levels) {
    if (level.id == id) {
      return level;
    }
  }
  return null;
}

int? _nextLevelId(List<LevelModel> levels, int id) {
  final index = levels.indexWhere((level) => level.id == id);
  return index >= 0 && index + 1 < levels.length ? levels[index + 1].id : null;
}
