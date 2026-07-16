import 'package:hive_ce/hive.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';

final class HiveProgressRepository implements ProgressRepository {
  HiveProgressRepository(this.box);

  static const _recordKey = 'playerProgress';

  final Box<Object?> box;

  @override
  Future<PlayerProgress> load() async {
    final record = box.get(_recordKey);
    if (record is! Map) {
      return const PlayerProgress.initial();
    }

    try {
      return PlayerProgress.fromMap(Map<Object?, Object?>.from(record));
    } on Object {
      return const PlayerProgress.initial();
    }
  }

  @override
  Future<void> save(PlayerProgress progress) {
    return box.put(_recordKey, progress.toMap());
  }
}
