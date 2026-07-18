import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/composite_level_source.dart';
import 'package:mind_spark/repositories/level_repository.dart';

class _FakeRepo implements LevelRepository {
  int? requestedId;
  @override
  Future<LevelModel> levelById(int id) async {
    requestedId = id;
    return LevelModel(id: id, size: 5, points: const [
      GridPoint(x: 0, y: 0, color: 'red'),
      GridPoint(x: 4, y: 4, color: 'red'),
    ]);
  }

  @override
  Future<List<LevelModel>> loadLevels() async => const [];
}

void main() {
  test('serves ids <= curatedMax from the repository', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(3);
    expect(level.id, 3);
    expect(repo.requestedId, 3);
  });

  test('serves ids > curatedMax from the generator', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(25);
    expect(level.id, 25);
    expect(repo.requestedId, isNull); // repository not touched
    expect(level.size, 8); // difficulty band for id 25 (plateau)
  });

  test('rejects non-positive ids', () async {
    final source = CompositeLevelSource(repository: _FakeRepo());
    await expectLater(source.levelById(0), throwsArgumentError);
  });

  test('routes id == curatedMax to the repository', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(10);
    expect(level.id, 10);
    expect(repo.requestedId, 10);
  });

  test('routes id == curatedMax + 1 to the generator', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(11);
    expect(level.id, 11);
    expect(repo.requestedId, isNull);
  });
}
