/// Countdown budget for a level, derived from board size (the difficulty proxy;
/// full-board coverage is required to win, so time scales with cell count).
Duration levelTimeLimit(int boardSize) {
  final cells = boardSize * boardSize;
  final seconds = (20 + cells * 1.6).round();
  return Duration(seconds: seconds < 45 ? 45 : seconds);
}

/// Stars (1..3) for finishing a level with [remaining] of [timeLimit] left.
int starsForResult({required Duration remaining, required Duration timeLimit}) {
  if (timeLimit.inMilliseconds <= 0) {
    return 1;
  }
  final ratio = (remaining.inMilliseconds / timeLimit.inMilliseconds).clamp(
    0.0,
    1.0,
  );
  if (ratio >= 0.7) {
    return 3;
  }
  if (ratio >= 0.4) {
    return 2;
  }
  return 1;
}
