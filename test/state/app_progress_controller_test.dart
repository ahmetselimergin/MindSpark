import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  group('AppProgressController', () {
    test('loads initial progress from the repository', () async {
      final stored = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 3,
        completedLevelIds: {1, 2},
        totalScore: 200,
        lives: 3,
        soundEnabled: true,
        vibrationEnabled: false,
      );
      final repository = RecordingProgressRepository(stored);
      final container = _container(repository);
      addTearDown(container.dispose);

      expect(
        await container.read(appProgressControllerProvider.future),
        stored,
      );
      expect(repository.loadCount, 1);
    });

    test('saves first completion and skips an idempotent replay', () async {
      final repository = RecordingProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.completeLevel(levelId: 1, nextLevelId: 2);
      await controller.completeLevel(levelId: 1, nextLevelId: 2);

      final progress = container
          .read(appProgressControllerProvider)
          .requireValue;
      expect(progress.totalScore, 100);
      expect(progress.highestUnlockedLevel, 2);
      expect(repository.saved, [progress]);
    });

    test('persists sound and vibration preference changes', () async {
      final repository = RecordingProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.setSoundEnabled(false);
      await controller.setVibrationEnabled(false);

      final progress = container
          .read(appProgressControllerProvider)
          .requireValue;
      expect(progress.soundEnabled, isFalse);
      expect(progress.vibrationEnabled, isFalse);
      expect(repository.saved.last, progress);
    });

    test('resetProgress clears progress but keeps the sound/vibration settings',
        () async {
      final stored = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 7,
        completedLevelIds: const {1, 2, 3, 4, 5, 6},
        totalScore: 600,
        lives: 2,
        soundEnabled: false,
        vibrationEnabled: false,
      );
      final repository = RecordingProgressRepository(stored);
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.resetProgress();

      final progress = container
          .read(appProgressControllerProvider)
          .requireValue;
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.completedLevelIds, isEmpty);
      expect(progress.totalScore, 0);
      expect(progress.lives, 5);
      expect(progress.soundEnabled, isFalse); // preserved
      expect(progress.vibrationEnabled, isFalse); // preserved
      expect(repository.saved.last, progress);
    });

    test(
      'exposes save failure and retries the exact unsaved candidate',
      () async {
        final repository = RecordingProgressRepository()..failNextSave = true;
        final container = _container(repository);
        addTearDown(container.dispose);
        final controller = container.read(
          appProgressControllerProvider.notifier,
        );
        await container.read(appProgressControllerProvider.future);

        await controller.completeLevel(levelId: 1, nextLevelId: 2);

        final failedState = container.read(appProgressControllerProvider);
        expect(failedState, isA<AsyncError<PlayerProgress>>());
        expect(failedState.hasError, isTrue);
        expect(failedState.hasValue, isTrue);
        expect(repository.saveAttempts, hasLength(1));
        final unsavedCandidate = repository.saveAttempts.single;
        expect(failedState.value, unsavedCandidate);
        expect(unsavedCandidate.totalScore, 100);

        await controller.retryLastSave();

        final recovered = container
            .read(appProgressControllerProvider)
            .requireValue;
        expect(
          identical(repository.saveAttempts.last, unsavedCandidate),
          isTrue,
        );
        expect(repository.saveAttempts, hasLength(2));
        expect(recovered, unsavedCandidate);
        expect(recovered.totalScore, 100);
        expect(
          container.read(appProgressControllerProvider),
          isA<AsyncData<PlayerProgress>>(),
        );
      },
    );

    test('serializes concurrent completions in persisted order', () async {
      final repository = DeferredProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      final first = controller.completeLevel(levelId: 1, nextLevelId: 2);
      final second = controller.completeLevel(levelId: 2, nextLevelId: 3);
      repository.resolveWhenAttempted(
        (progress) => progress.completedLevelIds.contains(2),
      );
      await repository.waitForAttempts(1);

      expect(repository.saveAttempts, hasLength(1));
      expect(repository.saveAttempts.single.completedLevelIds, {1});
      expect(await _isCompleted(second), isFalse);

      repository.resolveAttempt(0);
      await Future.wait([first, second]);

      expect(
        repository.persisted.map((progress) => progress.completedLevelIds),
        [
          {1},
          {1, 2},
        ],
      );
      expect(repository.value.completedLevelIds, {1, 2});
    });

    test('queue continues with fresh state after a save failure', () async {
      final repository = DeferredProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      final first = controller.completeLevel(levelId: 1, nextLevelId: 2);
      final second = controller.completeLevel(levelId: 2, nextLevelId: 3);
      await repository.waitForAttempts(1);
      repository.rejectAttempt(0);
      await first;
      await repository.waitForAttempts(2);

      expect(repository.saveAttempts.last.completedLevelIds, {1, 2});
      repository.resolveAttempt(1);
      await second;

      final state = container.read(appProgressControllerProvider);
      expect(state, isA<AsyncData<PlayerProgress>>());
      expect(state.requireValue.completedLevelIds, {1, 2});
      expect(repository.persisted.single.completedLevelIds, {1, 2});
    });

    test('serializes repeated retry without duplicate writes', () async {
      final repository = DeferredProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      final completion = controller.completeLevel(levelId: 1, nextLevelId: 2);
      await repository.waitForAttempts(1);
      repository.rejectAttempt(0);
      await completion;

      final firstRetry = controller.retryLastSave();
      final repeatedRetry = controller.retryLastSave();
      final nextCompletion = controller.completeLevel(
        levelId: 2,
        nextLevelId: 3,
      );
      await repository.waitForAttempts(2);

      expect(repository.saveAttempts, hasLength(2));
      expect(await _isCompleted(repeatedRetry), isFalse);
      expect(await _isCompleted(nextCompletion), isFalse);

      repository.resolveAttempt(1);
      await firstRetry;
      await repository.waitForAttempts(3);

      expect(repository.saveAttempts, hasLength(3));
      expect(repository.saveAttempts.last.completedLevelIds, {1, 2});
      repository.resolveAttempt(2);
      await Future.wait([repeatedRetry, nextCompletion]);

      expect(
        repository.persisted.map((progress) => progress.completedLevelIds),
        [
          {1},
          {1, 2},
        ],
      );
    });

    test('retry without a failed save does nothing', () async {
      final repository = RecordingProgressRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.retryLastSave();

      expect(repository.saveAttempts, isEmpty);
      expect(
        container.read(appProgressControllerProvider).requireValue,
        const PlayerProgress.initial(),
      );
    });
  });
}

Future<bool> _isCompleted(Future<void> future) async {
  final marker = Object();
  return await Future<Object?>(() async {
        await future;
        return marker;
      }).timeout(const Duration(milliseconds: 20), onTimeout: () => null) ==
      marker;
}

ProviderContainer _container(ProgressRepository repository) {
  return ProviderContainer(
    overrides: [progressRepositoryProvider.overrideWithValue(repository)],
  );
}

final class RecordingProgressRepository implements ProgressRepository {
  RecordingProgressRepository([this.value = const PlayerProgress.initial()]);

  PlayerProgress value;
  bool failNextSave = false;
  int loadCount = 0;
  final List<PlayerProgress> saveAttempts = [];
  final List<PlayerProgress> saved = [];

  @override
  Future<PlayerProgress> load() async {
    loadCount++;
    return value;
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    saveAttempts.add(progress);
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk full');
    }
    value = progress;
    saved.add(progress);
  }
}

final class DeferredProgressRepository implements ProgressRepository {
  PlayerProgress value = const PlayerProgress.initial();
  final List<PlayerProgress> saveAttempts = [];
  final List<PlayerProgress> persisted = [];
  final List<Completer<void>> _saveCompleters = [];
  final List<({int count, Completer<void> completer})> _attemptWaiters = [];
  final List<bool Function(PlayerProgress)> _autoResolvers = [];

  @override
  Future<PlayerProgress> load() async => value;

  @override
  Future<void> save(PlayerProgress progress) async {
    saveAttempts.add(progress);
    final completer = Completer<void>();
    _saveCompleters.add(completer);
    _notifyAttemptWaiters();
    final autoResolverIndex = _autoResolvers.indexWhere(
      (predicate) => predicate(progress),
    );
    if (autoResolverIndex >= 0) {
      _autoResolvers.removeAt(autoResolverIndex);
      completer.complete();
    }
    await completer.future;
    value = progress;
    persisted.add(progress);
  }

  Future<void> waitForAttempts(int count) {
    if (saveAttempts.length >= count) {
      return Future.value();
    }
    final waiter = Completer<void>();
    _attemptWaiters.add((count: count, completer: waiter));
    return waiter.future;
  }

  void resolveWhenAttempted(bool Function(PlayerProgress) predicate) {
    final existingIndex = saveAttempts.indexWhere(
      (progress) => predicate(progress),
    );
    if (existingIndex >= 0 && !_saveCompleters[existingIndex].isCompleted) {
      _saveCompleters[existingIndex].complete();
      return;
    }
    _autoResolvers.add(predicate);
  }

  void resolveAttempt(int index) {
    _saveCompleters[index].complete();
  }

  void rejectAttempt(int index) {
    _saveCompleters[index].completeError(StateError('disk full'));
  }

  void _notifyAttemptWaiters() {
    for (final waiter in _attemptWaiters.toList()) {
      if (saveAttempts.length >= waiter.count &&
          !waiter.completer.isCompleted) {
        waiter.completer.complete();
        _attemptWaiters.remove(waiter);
      }
    }
  }
}
