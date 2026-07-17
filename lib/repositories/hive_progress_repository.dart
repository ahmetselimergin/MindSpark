import 'package:hive_ce/hive.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';

typedef ProgressDiagnosticCallback =
    void Function(ProgressFormatException cause, StackTrace stackTrace);

final class HiveProgressRepository implements ProgressRepository {
  HiveProgressRepository(this.box, {this.onDiagnostic = _ignoreDiagnostic});

  static const _recordKey = 'playerProgress';

  final Box<Object?> box;
  final ProgressDiagnosticCallback onDiagnostic;

  @override
  Future<PlayerProgress> load() async {
    if (!box.containsKey(_recordKey)) {
      return const PlayerProgress.initial();
    }

    final record = box.get(_recordKey);
    try {
      return PlayerProgress.fromPersistedMap(record);
    } on ProgressFormatException catch (cause, stackTrace) {
      onDiagnostic(cause, stackTrace);
      return const PlayerProgress.initial();
    }
  }

  @override
  Future<void> save(PlayerProgress progress) {
    return box.put(_recordKey, progress.toMap());
  }
}

void _ignoreDiagnostic(ProgressFormatException cause, StackTrace stackTrace) {}
