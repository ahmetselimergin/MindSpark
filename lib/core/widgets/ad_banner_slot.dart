import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Fixed slot height so the gameplay layout never shifts as the ad loads.
const double _kBannerSlotHeight = 60;

/// AdMob banner ad unit id for Mind Spark (Android).
const String _kBannerAdUnitId = 'ca-app-pub-7351480239032506/3880507007';

/// Bottom-of-screen banner slot shown during gameplay. Renders an empty
/// reserved box under `flutter test` and never touches the ads plugin there.
final class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

final class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _requested = false;

  bool get _adsDisabled => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_adsDisabled || _requested) {
      return;
    }
    _requested = true;
    _loadBanner();
  }

  // Fixed 320x50 banner so it always fits the reserved slot with no layout
  // shift; adaptive sizing can exceed the slot height on large screens.
  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _banner = banner;
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return SizedBox(
      height: _kBannerSlotHeight,
      child: (_loaded && banner != null)
          ? Center(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
