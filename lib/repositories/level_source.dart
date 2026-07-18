import 'package:mind_spark/models/level_model.dart';

/// Supplies a single [LevelModel] for any positive level id.
abstract interface class LevelSource {
  Future<LevelModel> levelById(int id);
}
