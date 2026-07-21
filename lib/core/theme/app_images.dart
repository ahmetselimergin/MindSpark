abstract final class AppImages {
  static const String playButton = 'assets/ui/playbutton.png';
  static const String nextButton = 'assets/ui/nextbutton.png';
  static const String heart = 'assets/ui/heart.png';
  static const String replayButton = 'assets/ui/replaybutton.png';
  static const String homeButton = 'assets/ui/homebutton.png';
  static const String refillButton = 'assets/ui/refillbutton.png';
  static const String watchAddButton = 'assets/ui/watchaddbutton.png';
  static const String soundButton = 'assets/ui/soundbutton.png';
  static const String wonBoard = 'assets/ui/wonboard.png';
  static const String star1 = 'assets/ui/1star.png';
  static const String star2 = 'assets/ui/2star.png';
  static const String star3 = 'assets/ui/3star.png';

  static const String background = 'assets/ui/background.png';
  static const String star = 'assets/ui/star.png';
  static const String statusGood = 'assets/ui/Status/Good.png';
  static const String statusGreat = 'assets/ui/Status/Great.png';
  static const String statusPerfect = 'assets/ui/Status/Perfect.png';

  static String starN(int stars) => switch (stars) {
    <= 1 => star1,
    2 => star2,
    _ => star3,
  };

  static String statusForStars(int stars) => switch (stars) {
    <= 1 => statusGood,
    2 => statusGreat,
    _ => statusPerfect,
  };
}
