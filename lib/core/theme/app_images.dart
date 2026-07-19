abstract final class AppImages {
  static const String playButton = 'assets/ui/playbutton.png';
  static const String nextButton = 'assets/ui/nextbutton.png';
  static const String heart = 'assets/ui/heart.png';
  static const String replayButton = 'assets/ui/replaybutton.png';
  static const String refillButton = 'assets/ui/refillbutton.png';
  static const String watchAddButton = 'assets/ui/watchaddbutton.png';
  static const String soundButton = 'assets/ui/soundbutton.png';
  static const String wonBoard = 'assets/ui/wonboard.png';
  static const String star1 = 'assets/ui/1star.png';
  static const String star2 = 'assets/ui/2star.png';
  static const String star3 = 'assets/ui/3star.png';

  static String starN(int stars) => switch (stars) {
    <= 1 => star1,
    2 => star2,
    _ => star3,
  };
}
