import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => InMemoryProgressRepository(),
);

/// The wall clock, injectable for deterministic tests. Millisecond-precision
/// UTC so persisted anchors round-trip and compare stably.
final clockProvider = Provider<DateTime Function()>(
  (ref) => () {
    final now = DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch,
      isUtc: true,
    );
  },
);

final appProgressControllerProvider =
    AsyncNotifierProvider<AppProgressController, PlayerProgress>(
      AppProgressController.new,
      retry: (_, _) => null,
    );

final class AppProgressController extends AsyncNotifier<PlayerProgress> {
  PlayerProgress? _lastUnsavedProgress;
  Future<void> _mutationTail = Future<void>.value();

  ProgressRepository get _repository => ref.read(progressRepositoryProvider);

  bool get hasPendingSave => _lastUnsavedProgress != null;

  @override
  Future<PlayerProgress> build() async {
    _lastUnsavedProgress = null;
    return _repository.load();
  }

  Future<void> completeLevel({required int levelId, int? nextLevelId}) {
    return _enqueueMutation(
      () => _completeLevel(levelId: levelId, nextLevelId: nextLevelId),
    );
  }

  Future<void> _completeLevel({
    required int levelId,
    required int? nextLevelId,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final candidate = current.completeLevel(
      levelId: levelId,
      nextLevelId: nextLevelId,
    );
    if (identical(candidate, current)) {
      return;
    }

    state = AsyncData(candidate);
    await _save(candidate);
  }

  DateTime _now() => ref.read(clockProvider)();

  Future<void> spendLife({DateTime? now}) {
    return _enqueueMutation(() => _spendLife(now ?? _now()));
  }

  Future<void> _spendLife(DateTime now) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final candidate = current.spendLife(now: now);
    if (candidate == current) {
      return;
    }
    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> reconcileLives({DateTime? now}) {
    return _enqueueMutation(() => _reconcileLives(now ?? _now()));
  }

  Future<void> _reconcileLives(DateTime now) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final result = LivesRegen.reconcile(
      lives: current.lives,
      anchor: current.livesRegenAnchor,
      now: now,
    );
    if (result.lives == current.lives &&
        result.anchor == current.livesRegenAnchor) {
      return;
    }
    final candidate = current.copyWithLives(
      lives: result.lives,
      anchor: result.anchor,
    );
    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> setSoundEnabled(bool value) {
    return _enqueueMutation(() => _applySettings(soundEnabled: value));
  }

  Future<void> setVibrationEnabled(bool value) {
    return _enqueueMutation(() => _applySettings(vibrationEnabled: value));
  }

  Future<void> _applySettings({
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final candidate = current.copyWith(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    if (candidate == current) {
      return;
    }

    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> resetProgress() {
    return _enqueueMutation(_resetProgress);
  }

  Future<void> _resetProgress() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    // Reset progress but keep the player's sound/vibration preferences.
    final candidate = const PlayerProgress.initial().copyWith(
      soundEnabled: current.soundEnabled,
      vibrationEnabled: current.vibrationEnabled,
    );

    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> retryLastSave() {
    return _enqueueMutation(_retryLastSave);
  }

  Future<void> _retryLastSave() async {
    final candidate = _lastUnsavedProgress;
    if (candidate == null) {
      return;
    }

    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> _save(PlayerProgress candidate) async {
    try {
      await _repository.save(candidate);
      _lastUnsavedProgress = null;
      state = AsyncData(candidate);
    } catch (error, stackTrace) {
      _lastUnsavedProgress = candidate;
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _enqueueMutation(Future<void> Function() mutation) {
    final operation = _mutationTail.then((_) => mutation());
    _mutationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
