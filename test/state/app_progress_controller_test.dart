import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  group('AppProgressController', () {
    test('loads initial progress from the repository', () async {
      const stored = PlayerProgress(
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
        expect(repository.saveAttempts, hasLength(1));
        final unsavedCandidate = repository.saveAttempts.single;
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
      },
    );

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
