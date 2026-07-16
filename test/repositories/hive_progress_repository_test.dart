import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/hive_progress_repository.dart';

void main() {
  group('HiveProgressRepository', () {
    Directory? temporaryDirectory;
    Box<Object?>? box;
    HiveProgressRepository? repository;

    setUp(() async {
      temporaryDirectory = null;
      box = null;
      repository = null;
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'mind_spark_progress_test_',
      );
      Hive.init(temporaryDirectory!.path);
      box = await Hive.openBox<Object?>('progress');
      repository = HiveProgressRepository(box!);
    });

    tearDown(() async {
      final openedBox = box;
      final createdDirectory = temporaryDirectory;
      try {
        if (openedBox?.isOpen ?? false) {
          await openedBox!.deleteFromDisk();
        }
      } finally {
        if (createdDirectory?.existsSync() ?? false) {
          await createdDirectory!.delete(recursive: true);
        }
      }
    });

    test('returns initial defaults when the record is missing', () async {
      expect(await repository!.load(), const PlayerProgress.initial());
    });

    test('saves and loads progress under the single record key', () async {
      final progress = PlayerProgress(
        schemaVersion: 1,
        highestUnlockedLevel: 3,
        completedLevelIds: {1, 2},
        totalScore: 200,
        lives: 2,
        soundEnabled: false,
        vibrationEnabled: true,
      );

      await repository!.save(progress);

      expect(box!.keys, ['playerProgress']);
      expect(await repository!.load(), progress);
    });

    test('returns initial defaults for corrupt records', () async {
      for (final corruptRecord in <Object?>[
        'not a map',
        42,
        <Object?>['not', 'a', 'record'],
      ]) {
        await box!.put('playerProgress', corruptRecord);

        expect(
          await repository!.load(),
          const PlayerProgress.initial(),
          reason: 'record: $corruptRecord',
        );
      }
    });

    test('normalizes corrupt fields without throwing', () async {
      await box!.put('playerProgress', <Object?, Object?>{
        'highestUnlockedLevel': -3,
        'completedLevelIds': [1, 'bad'],
        'totalScore': -100,
      });

      expect(
        await repository!.load(),
        PlayerProgress(
          schemaVersion: 1,
          highestUnlockedLevel: 1,
          completedLevelIds: {1},
          totalScore: 0,
          lives: 3,
          soundEnabled: true,
          vibrationEnabled: true,
        ),
      );
    });
  });
}
