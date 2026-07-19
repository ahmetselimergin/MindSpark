abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const gameplay = '/gameplay';
  static const result = '/result';
  static const settings = '/settings';
  static const outOfLives = '/out-of-lives';
}

final class GameplayRouteArgs {
  const GameplayRouteArgs(this.levelId);

  final int levelId;
}

final class OutOfLivesRouteArgs {
  const OutOfLivesRouteArgs(this.levelId);

  final int levelId;
}

final class ResultRouteArgs {
  const ResultRouteArgs({required this.levelId, required this.awardedScore});

  final int levelId;
  final int awardedScore;
}
