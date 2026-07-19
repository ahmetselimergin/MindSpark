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
    late List<ProgressFormatException> diagnostics;
    late List<StackTrace> diagnosticStacks;

    setUp(() async {
      temporaryDirectory = null;
      box = null;
      repository = null;
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'mind_spark_progress_test_',
      );
      Hive.init(temporaryDirectory!.path);
      box = await Hive.openBox<Object?>('progress');
      diagnostics = [];
      diagnosticStacks = [];
      repository = HiveProgressRepository(
        box!,
        onDiagnostic: (cause, stackTrace) {
          diagnostics.add(cause);
          diagnosticStacks.add(stackTrace);
        },
      );
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
      expect(diagnostics, isEmpty);
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
      expect(diagnostics, isEmpty);
    });

    test('rejects a non-map record atomically and diagnoses once', () async {
      await box!.put('playerProgress', 'not a map');

      expect(await repository!.load(), const PlayerProgress.initial());
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.field, 'record');
      expect(diagnosticStacks.single, isNot(StackTrace.empty));
    });

    test('rejects a malformed field without partial salvage', () async {
      await box!.put('playerProgress', <Object?, Object?>{
        'schemaVersion': 1,
        'highestUnlockedLevel': '2',
        'completedLevelIds': const <int>[1],
        'totalScore': 100,
        'lives': 3,
        'soundEnabled': true,
        'vibrationEnabled': true,
      });

      expect(await repository!.load(), const PlayerProgress.initial());
      expect(diagnostics.single.field, 'highestUnlockedLevel');
    });

    test('rejects unsupported persisted schema versions', () async {
      await _putRecord(box!, schemaVersion: 3);

      expect(await repository!.load(), const PlayerProgress.initial());
      expect(diagnostics.single.field, 'schemaVersion');
    });

    test('migrates a persisted v1 record and refills lives to 5', () async {
      await box!.put('playerProgress', <String, Object>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 3,
        'completedLevelIds': const <int>[1, 2],
        'totalScore': 200,
        'lives': 2,
        'soundEnabled': true,
        'vibrationEnabled': true,
      });

      final loaded = await repository!.load();

      expect(loaded.schemaVersion, 2);
      expect(loaded.highestUnlockedLevel, 3);
      expect(loaded.completedLevelIds, {1, 2});
      expect(loaded.lives, 5);
      expect(loaded.livesRegenAnchor, isNull);
      expect(diagnostics, isEmpty);
    });

    test('rejects inconsistent IDs, score, and unlock atomically', () async {
      final invalidRecords = <Map<String, Object>>[
        _record(completedLevelIds: const [1, 1], totalScore: 200),
        _record(completedLevelIds: const [1], totalScore: 0),
        _record(
          highestUnlockedLevel: 1,
          completedLevelIds: const [2],
          totalScore: 100,
        ),
      ];

      for (final record in invalidRecords) {
        diagnostics.clear();
        await box!.put('playerProgress', record);

        expect(await repository!.load(), const PlayerProgress.initial());
        expect(diagnostics, hasLength(1), reason: 'record: $record');
      }
    });

    test(
      'surfaces box read failures instead of calling corruption diagnostics',
      () async {
        await box!.close();

        await expectLater(repository!.load(), throwsA(isA<HiveError>()));
        expect(diagnostics, isEmpty);
      },
    );
  });
}

Future<void> _putRecord(Box<Object?> box, {Object schemaVersion = 1}) =>
    box.put('playerProgress', _record(schemaVersion: schemaVersion));

Map<String, Object> _record({
  Object schemaVersion = 1,
  Object highestUnlockedLevel = 1,
  Object completedLevelIds = const <int>[],
  Object totalScore = 0,
}) => <String, Object>{
  'schemaVersion': schemaVersion,
  'highestUnlockedLevel': highestUnlockedLevel,
  'completedLevelIds': completedLevelIds,
  'totalScore': totalScore,
  'lives': 3,
  'soundEnabled': true,
  'vibrationEnabled': true,
};
