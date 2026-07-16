import 'package:mind_spark/models/level_model.dart';

abstract interface class LevelRepository {
  Future<List<LevelModel>> loadLevels();

  Future<LevelModel> levelById(int id);
}

final class LevelLoadException implements Exception {
  const LevelLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'LevelLoadException: $message';
}
