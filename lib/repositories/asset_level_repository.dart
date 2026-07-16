import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/level_repository.dart';

final class AssetLevelRepository implements LevelRepository {
  AssetLevelRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/levels/levels.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  List<LevelModel>? _cachedLevels;
  Future<List<LevelModel>>? _inFlightLoad;

  @override
  Future<List<LevelModel>> loadLevels() {
    final cachedLevels = _cachedLevels;
    if (cachedLevels != null) {
      return Future.value(cachedLevels);
    }

    return _inFlightLoad ??= _loadLevels();
  }

  Future<List<LevelModel>> _loadLevels() async {
    try {
      final contents = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(contents);
      if (decoded is! List<Object?>) {
        throw const LevelFormatException('levels must be a JSON list');
      }

      final levels = <LevelModel>[];
      final ids = <int>{};
      for (var index = 0; index < decoded.length; index++) {
        final rawLevel = decoded[index];
        if (rawLevel is! Map<String, Object?>) {
          throw LevelFormatException('levels[$index] must be an object');
        }

        final level = LevelModel.fromJson(rawLevel);
        if (level.id <= 0) {
          throw LevelFormatException('levels[$index].id must be positive');
        }
        if (!ids.add(level.id)) {
          throw LevelFormatException('levels has duplicate id ${level.id}');
        }
        levels.add(level);
      }

      levels.sort((left, right) => left.id.compareTo(right.id));
      final validatedLevels = List<LevelModel>.unmodifiable(levels);
      _cachedLevels = validatedLevels;
      return validatedLevels;
    } on LevelLoadException {
      rethrow;
    } catch (error) {
      final detail = switch (error) {
        LevelFormatException(:final message) => ': $message',
        _ => '',
      };
      throw LevelLoadException(
        'Failed to load levels from "$assetPath"$detail',
        error,
      );
    } finally {
      _inFlightLoad = null;
    }
  }

  @override
  Future<LevelModel> levelById(int id) async {
    final levels = await loadLevels();
    for (final level in levels) {
      if (level.id == id) {
        return level;
      }
    }
    throw LevelLoadException('Level id $id was not found');
  }
}
