import 'package:mind_spark/game/generation/procedural_level_generator.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/level_repository.dart';
import 'package:mind_spark/repositories/level_source.dart';

/// Serves curated levels from [repository] and generates the rest.
class CompositeLevelSource implements LevelSource {
  CompositeLevelSource({
    required this.repository,
    this.generator = const ProceduralLevelGenerator(),
    this.curatedMax = 10,
  });

  final LevelRepository repository;
  final ProceduralLevelGenerator generator;
  final int curatedMax;

  @override
  Future<LevelModel> levelById(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be positive');
    }
    if (id <= curatedMax) {
      return repository.levelById(id);
    }
    return generator.generate(id).level;
  }
}
