import 'package:mind_spark/models/player_progress.dart';

abstract interface class ProgressRepository {
  Future<PlayerProgress> load();

  Future<void> save(PlayerProgress progress);
}

final class InMemoryProgressRepository implements ProgressRepository {
  InMemoryProgressRepository([this.value = const PlayerProgress.initial()]);

  PlayerProgress value;

  @override
  Future<PlayerProgress> load() async => value;

  @override
  Future<void> save(PlayerProgress progress) async {
    value = progress;
  }
}
