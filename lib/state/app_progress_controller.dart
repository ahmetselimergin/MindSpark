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
  Future<void> _mutationTail = Future<void>.value();

  ProgressRepository get _repository => ref.read(progressRepositoryProvider);

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
      final failedSave = AsyncError<PlayerProgress>(error, stackTrace);
      // Riverpod 3 uses this API to retain data alongside an error state.
      // ignore: invalid_use_of_internal_member
      state = failedSave.copyWithPrevious(AsyncData(candidate));
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
