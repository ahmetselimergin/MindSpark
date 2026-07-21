import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Fixed slot height so the gameplay layout never shifts as the ad loads.
const double _kBannerSlotHeight = 60;

// TODO: replace this test banner ad unit id with the real one before release.
const String _kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

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
    unawaited(_loadBanner());
  }

  Future<void> _loadBanner() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) {
      return;
    }
    final banner = BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: size,
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
    await banner.load();
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
