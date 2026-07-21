import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Fixed slot height so the gameplay layout never shifts as the ad loads.
const double _kBannerSlotHeight = 60;

/// Yandex Advertising Network banner block id for Mind Spark (Android).
const String _kBannerBlockId = 'R-M-19628695-1';

/// Bottom-of-screen banner slot shown during gameplay. Renders an empty
/// reserved box under `flutter test` and never touches the ads plugin there.
final class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

final class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _banner;
  bool _requested = false;

  bool get _adsDisabled => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_adsDisabled || _requested) {
      return;
    }
    _requested = true;
    // Inline banner capped to 50dp high so it always fits the reserved slot;
    // the Yandex AdWidget resizes itself to the loaded ad's actual height.
    final width = MediaQuery.of(context).size.width.truncate();
    final banner = BannerAd(
      adSize: BannerAdSize.inline(width: width, maxHeight: 50),
    );
    banner.load(const AdRequest(adUnitId: _kBannerBlockId));
    _banner = banner;
  }

  @override
  void dispose() {
    _banner?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return SizedBox(
      height: _kBannerSlotHeight,
      child: banner == null
          ? const SizedBox.shrink()
          : Center(child: AdWidget(bannerAd: banner)),
    );
  }
}
