import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/repositories/hive_progress_repository.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

typedef ProgressRepositoryInitializer = Future<ProgressRepository> Function();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProgressBootstrap(initializer: initializeProgressRepository));
}

Future<ProgressRepository> initializeProgressRepository() async {
  await Hive.initFlutter();
  final progressBox = await Hive.openBox<Object?>('mindSparkProgress');
  return HiveProgressRepository(progressBox);
}

final class ProgressBootstrap extends StatefulWidget {
  const ProgressBootstrap({super.key, required this.initializer});

  final ProgressRepositoryInitializer initializer;

  @override
  State<ProgressBootstrap> createState() => _ProgressBootstrapState();
}

final class _ProgressBootstrapState extends State<ProgressBootstrap> {
  ProgressRepository? _repository;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _repository = null;
      _error = null;
    });
    try {
      final repository = await Future<ProgressRepository>.sync(
        widget.initializer,
      );
      if (mounted) {
        setState(() => _repository = repository);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository != null) {
      return ProviderScope(
        overrides: [progressRepositoryProvider.overrideWithValue(repository)],
        child: const MindSparkApp(),
      );
    }

    return MaterialApp(
      title: 'MindSpark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MindSpark',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 46,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_error == null)
                    const CircularProgressIndicator()
                  else ...[
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.coralPulse,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Progress storage could not be opened.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('RETRY'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
