import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/repositories/hive_progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final progressBox = await Hive.openBox<Object?>('mindSparkProgress');

  runApp(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          HiveProgressRepository(progressBox),
        ),
      ],
      child: const MindSparkApp(),
    ),
  );
}
