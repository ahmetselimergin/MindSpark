/// Countdown budget for a level, derived from board size (the difficulty proxy;
/// full-board coverage is required to win, so time scales with cell count).
Duration levelTimeLimit(int boardSize) {
  final cells = boardSize * boardSize;
  final seconds = (20 + cells * 1.6).round();
  return Duration(seconds: seconds < 45 ? 45 : seconds);
}
