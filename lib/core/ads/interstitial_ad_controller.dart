import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob interstitial ad unit id for Mind Spark (Android).
const String _kInterstitialAdUnitId = 'ca-app-pub-7351480239032506/9324405379';

/// Show an interstitial on every Nth level completion.
const int _kShowEveryNCompletions = 3;

/// App-scoped controller that keeps one interstitial preloaded and shows it at
/// natural transition points. A single preloaded ad plus the [_showing] guard
/// gives a soft frequency cap, so triggers never stack back-to-back.
final interstitialAdControllerProvider = Provider<InterstitialAdController>((
  ref,
) {
  final controller = InterstitialAdController();
  controller.preload();
  ref.onDispose(controller.dispose);
  return controller;
});

final class InterstitialAdController {
  InterstitialAd? _ad;
  bool _showing = false;
  int _completions = 0;

  bool get _adsDisabled => Platform.environment.containsKey('FLUTTER_TEST');

  /// Loads an interstitial to have ready for the next trigger. No-op under
  /// tests or when one is already loaded.
  void preload() {
    if (_adsDisabled || _ad != null) {
      return;
    }
    InterstitialAd.load(
      adUnitId: _kInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  /// Called on every level completion; shows an ad on every Nth one.
  void maybeShowOnLevelComplete() {
    _completions++;
    if (_completions % _kShowEveryNCompletions == 0) {
      _show();
    }
  }

  /// Called when returning to the home screen; shows an ad if one is ready.
  void maybeShowOnHome() => _show();

  void _show() {
    if (_adsDisabled || _showing) {
      return;
    }
    final ad = _ad;
    if (ad == null) {
      preload(); // nothing ready — warm up for next time
      return;
    }
    _showing = true;
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showing = false;
        preload();
      },
    );
    ad.show();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
