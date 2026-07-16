import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => InMemoryProgressRepository(),
);

final appProgressControllerProvider =
    AsyncNotifierProvider<AppProgressController, PlayerProgress>(
      AppProgressController.new,
    );

final class AppProgressController extends AsyncNotifier<PlayerProgress> {
  PlayerProgress? _lastUnsavedProgress;

  ProgressRepository get _repository => ref.read(progressRepositoryProvider);

  @override
  Future<PlayerProgress> build() async {
    _lastUnsavedProgress = null;
    return _repository.load();
  }

  Future<void> completeLevel({required int levelId, int? nextLevelId}) async {
    if (_lastUnsavedProgress != null) {
      return;
    }

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

  Future<void> retryLastSave() async {
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
}
