import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';

void main() {
  test('statusForStars maps stars to Good/Great/Perfect', () {
    expect(AppImages.statusForStars(0), AppImages.statusGood);
    expect(AppImages.statusForStars(1), AppImages.statusGood);
    expect(AppImages.statusForStars(2), AppImages.statusGreat);
    expect(AppImages.statusForStars(3), AppImages.statusPerfect);
    expect(AppImages.statusForStars(9), AppImages.statusPerfect);
  });

  test('new asset paths point under assets/ui', () {
    expect(AppImages.background, 'assets/ui/background.png');
    expect(AppImages.star, 'assets/ui/star.png');
    expect(AppImages.statusGood, 'assets/ui/Status/Good.png');
    expect(AppImages.statusGreat, 'assets/ui/Status/Great.png');
    expect(AppImages.statusPerfect, 'assets/ui/Status/Perfect.png');
  });
}
