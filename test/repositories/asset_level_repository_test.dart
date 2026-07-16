import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/asset_level_repository.dart';
import 'package:mind_spark/repositories/level_repository.dart';

void main() {
  group('AssetLevelRepository', () {
    test('loads, sorts, and caches an immutable level list', () async {
      final bundle = TestAssetBundle(
        jsonEncode([_levelJson(3), _levelJson(1), _levelJson(2)]),
      );
      final repository = AssetLevelRepository(
        bundle: bundle,
        assetPath: 'levels.json',
      );

      final levels = await repository.loadLevels();
      final cachedLevels = await repository.loadLevels();

      expect(levels.map((level) => level.id), [1, 2, 3]);
      expect(identical(cachedLevels, levels), isTrue);
      expect(bundle.loadCount, 1);
      expect(
        () => levels.add(LevelModel.fromJson(_levelJson(4))),
        throwsUnsupportedError,
      );
      expect((await repository.levelById(2)).id, 2);
      expect(bundle.loadCount, 1);
    });

    test('rejects duplicate level IDs', () async {
      final repository = _repositoryFor([_levelJson(1), _levelJson(1)]);

      await expectLater(
        repository.loadLevels(),
        throwsA(_loadErrorContaining('duplicate id')),
      );
    });

    test('rejects non-positive level IDs', () async {
      final repository = _repositoryFor([_levelJson(0)]);

      await expectLater(
        repository.loadLevels(),
        throwsA(_loadErrorContaining('positive')),
      );
    });

    test('wraps malformed JSON as a level load failure', () async {
      final repository = AssetLevelRepository(
        bundle: TestAssetBundle('{not-json'),
        assetPath: 'levels.json',
      );

      await expectLater(
        repository.loadLevels(),
        throwsA(
          isA<LevelLoadException>()
              .having(
                (error) => error.message,
                'message',
                contains('levels.json'),
              )
              .having((error) => error.cause, 'cause', isA<FormatException>()),
        ),
      );
    });

    test('reports a missing level lookup', () async {
      final repository = _repositoryFor([_levelJson(1)]);

      await expectLater(
        repository.levelById(99),
        throwsA(_loadErrorContaining('99')),
      );
    });
  });
}

AssetLevelRepository _repositoryFor(List<Map<String, Object?>> levels) {
  return AssetLevelRepository(
    bundle: TestAssetBundle(jsonEncode(levels)),
    assetPath: 'levels.json',
  );
}

Map<String, Object?> _levelJson(int id) {
  return {
    'id': id,
    'size': 5,
    'points': [
      {'x': 0, 'y': 0, 'color': 'red'},
      {'x': 4, 'y': 4, 'color': 'red'},
    ],
  };
}

Matcher _loadErrorContaining(String text) {
  return isA<LevelLoadException>().having(
    (error) => error.message,
    'message',
    contains(text),
  );
}

final class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(this.contents);

  final String contents;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return ByteData.sublistView(bytes);
  }
}
