import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/features/home/home_screen.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/features/splash/splash_screen.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/asset_level_repository.dart';
import 'package:mind_spark/repositories/level_repository.dart';

final levelRepositoryProvider = Provider<LevelRepository>(
  (ref) => AssetLevelRepository(),
);

final levelsProvider = FutureProvider<List<LevelModel>>((ref) async {
  final levels = await ref.read(levelRepositoryProvider).loadLevels();
  if (levels.isEmpty) {
    throw const LevelLoadException('No playable levels were found');
  }
  return levels;
}, retry: (_, _) => null);

final class MindSparkApp extends StatelessWidget {
  const MindSparkApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSpark',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

Route<void> _onGenerateRoute(RouteSettings settings) {
  final Widget page = switch (settings.name) {
    AppRoutes.splash => const SplashScreen(),
    AppRoutes.home => const HomeScreen(),
    AppRoutes.gameplay => switch (settings.arguments) {
      GameplayRouteArgs(:final levelId) when levelId > 0 => GameplayScreen(
        levelId: levelId,
      ),
      _ => const _SafeRouteError(),
    },
    AppRoutes.result => switch (settings.arguments) {
      ResultRouteArgs(:final levelId, :final awardedScore)
          when levelId > 0 && awardedScore >= 0 =>
        ResultScreen(levelId: levelId, awardedScore: awardedScore),
      _ => const _SafeRouteError(),
    },
    _ => const _SafeRouteError(),
  };
  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}

final class _SafeRouteError extends StatelessWidget {
  const _SafeRouteError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This screen could not be opened.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                child: const Text('HOME'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
