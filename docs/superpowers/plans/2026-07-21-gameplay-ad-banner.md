# Gameplay Ad Banner + Conditional Hint Flash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a child-directed AdMob banner beneath the game board during gameplay (replacing the static hint text), and flash a hint once above the banner when the player connects every pair but leaves the board unfilled.

**Architecture:** A self-contained `AdBannerSlot` widget owns the banner load/dispose lifecycle and renders an empty fixed-height box under `flutter test`. The "stuck" state is detected in the pure-Dart `PuzzleSession` via a new `onAllPairsConnected` callback (mirroring `onCompleted`), forwarded through `MindSparkGame` and the game factory to the gameplay screen, which increments a tick that drives a one-shot `StuckHintFlash` overlay.

**Tech Stack:** Flutter, Dart, Flame, Riverpod, `google_mobile_ads`.

## Global Constraints

- Package: `google_mobile_ads` (Android config only this iteration; Dart stays platform-agnostic).
- Android `minSdk = 23` (google_mobile_ads floor). If the resolved SDK version demands higher at build time, raise to that value.
- Child-directed config (verbatim values): `maxAdContentRating: MaxAdContentRating.g`, `tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes`, `tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes`.
- Test AdMob IDs only, each with a `TODO` to swap the real value: App ID `ca-app-pub-3940256099942544~3347511713`, banner unit `ca-app-pub-3940256099942544/6300978111`.
- Ads are disabled under tests: `AdBannerSlot` renders an empty box when `Platform.environment.containsKey('FLUTTER_TEST')` is true and never touches the plugin.
- Flash copy (exact string, English, matching existing UI): `All linked — now fill every square!`
- Reserved banner slot height: `60`.
- Flame's `GameWidget` renders continuously — in widget tests use fixed `tester.pump(Duration)` calls, never `pumpAndSettle`, when a real game is mounted.
- Full suite must stay green (184 existing tests) and `flutter analyze` clean after every task.

---

### Task 1: Add dependency, initialize the SDK, configure Android

**Files:**
- Modify: `pubspec.yaml` (dependencies)
- Modify: `lib/main.dart:1-15`
- Modify: `android/app/src/main/AndroidManifest.xml` (inside `<application>`)
- Modify: `android/app/build.gradle.kts:22`

**Interfaces:**
- Consumes: nothing.
- Produces: the `google_mobile_ads` package on the classpath and an initialized `MobileAds` instance with child-directed request configuration. No new Dart symbols.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add google_mobile_ads`
Expected: `pubspec.yaml` gains `google_mobile_ads:` under dependencies and `flutter pub get` completes with "Got dependencies".

- [ ] **Step 2: Initialize the SDK in `main.dart`**

Replace the imports block and `main()` in `lib/main.dart` (lines 1-15) with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/repositories/hive_progress_repository.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

typedef ProgressRepositoryInitializer = Future<ProgressRepository> Function();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Child-directed request config must be applied before any ad is requested.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.g,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
    ),
  );
  unawaited(MobileAds.instance.initialize());
  runApp(const ProgressBootstrap(initializer: initializeProgressRepository));
}
```

- [ ] **Step 3: Add the AdMob App ID to the Android manifest**

In `android/app/src/main/AndroidManifest.xml`, add these lines inside the `<application>` element (e.g. immediately before its closing `</application>`):

```xml
        <!-- TODO: replace this test AdMob App ID with the real one before release. -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713"/>
```

- [ ] **Step 4: Raise `minSdk`**

In `android/app/build.gradle.kts`, change line 22 from `minSdk = flutter.minSdkVersion` to:

```kotlin
        minSdk = 23
```

- [ ] **Step 5: Verify analyze + full suite still pass**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all existing tests pass (184 passing).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart android/app/src/main/AndroidManifest.xml android/app/build.gradle.kts
git commit -m "feat: add google_mobile_ads dependency, SDK init, and Android config"
```

---

### Task 2: Detect the stuck state in `PuzzleSession`

**Files:**
- Modify: `lib/game/domain/puzzle_session.dart:8-24,71-110`
- Test: `test/game/domain/puzzle_session_test.dart`

**Interfaces:**
- Consumes: existing `PuzzleSession(level:, onCompleted:)` factory.
- Produces: `PuzzleSession({required LevelModel level, void Function()? onCompleted, void Function()? onAllPairsConnected})`. `onAllPairsConnected` fires exactly when a path becomes connected, every color pair is now connected, and the board is not yet fully covered (i.e. `!isComplete`).

- [ ] **Step 1: Write the failing tests**

Add this group to `test/game/domain/puzzle_session_test.dart` (before the final closing `}` of `main`), reusing the file's existing `_level`, `_fillLevel`, `_connectRed`, `_connectBlue`, and `_fillBoard` helpers:

```dart
  group('PuzzleSession stuck signal', () {
    test('fires onAllPairsConnected when all pairs connect but cells remain', () {
      var stuckCount = 0;
      final session = PuzzleSession(
        level: _level,
        onAllPairsConnected: () => stuckCount++,
      );

      _connectRed(session);
      expect(stuckCount, 0); // only one of two pairs connected so far

      _connectBlue(session); // both pairs connected, middle row still empty
      expect(stuckCount, 1);
      expect(session.isComplete, isFalse);
    });

    test('does not fire onAllPairsConnected when the board is completed', () {
      var stuckCount = 0;
      var completionCount = 0;
      final session = PuzzleSession(
        level: _fillLevel,
        onCompleted: () => completionCount++,
        onAllPairsConnected: () => stuckCount++,
      );

      _fillBoard(session);

      expect(completionCount, 1);
      expect(stuckCount, 0);
    });

    test('fires again after restart and re-entering the stuck state', () {
      var stuckCount = 0;
      final session = PuzzleSession(
        level: _level,
        onAllPairsConnected: () => stuckCount++,
      );

      _connectRed(session);
      _connectBlue(session);
      expect(stuckCount, 1);

      session.restart();
      _connectRed(session);
      _connectBlue(session);
      expect(stuckCount, 2);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/game/domain/puzzle_session_test.dart`
Expected: FAIL — compile error, `PuzzleSession` has no named parameter `onAllPairsConnected`.

- [ ] **Step 3: Implement the callback**

In `lib/game/domain/puzzle_session.dart`:

Change the factory and private constructor (lines 9-20) to thread the new callback:

```dart
  factory PuzzleSession({
    required LevelModel level,
    void Function()? onCompleted,
    void Function()? onAllPairsConnected,
  }) => PuzzleSession._(level, onCompleted, onAllPairsConnected);

  PuzzleSession._(this._level, this._onCompleted, this._onAllPairsConnected) {
    for (final point in _level.points) {
      final position = GridPosition(point.x, point.y);
      _endpointColors[position] = point.color;
      (_endpointsByColor[point.color] ??= <GridPosition>[]).add(position);
    }
  }
```

Add the field next to `_onCompleted` (after line 23):

```dart
  final void Function()? _onCompleted;
  final void Function()? _onAllPairsConnected;
```

Add a private helper next to `isComplete` (after line 50):

```dart
  bool get _allPairsConnected =>
      _paths.length == _endpointsByColor.length &&
      _paths.values.every((path) => path.connected);
```

In `extendPath`, replace the completion branch (lines 102-108) with:

```dart
    path.cells.add(position);
    if (endpointColor == color && position != path.cells.first) {
      path.connected = true;
      if (isComplete) {
        _inputLocked = true;
        _onCompleted?.call();
      } else if (_allPairsConnected) {
        _onAllPairsConnected?.call();
      }
    }
    return true;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/game/domain/puzzle_session_test.dart`
Expected: PASS (all tests in the file, including the three new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/game/domain/puzzle_session.dart test/game/domain/puzzle_session_test.dart
git commit -m "feat: signal all-pairs-connected-but-unfilled state from PuzzleSession"
```

---

### Task 3: Forward the signal through `MindSparkGame`

**Files:**
- Modify: `lib/game/mind_spark_game.dart:12-15`
- Test: `test/game/mind_spark_game_test.dart`

**Interfaces:**
- Consumes: `PuzzleSession(onAllPairsConnected:)` from Task 2.
- Produces: `MindSparkGame({required LevelModel level, required VoidCallback onCompleted, VoidCallback? onAllPairsConnected})`. The optional callback is forwarded to the session unchanged.

- [ ] **Step 1: Write the failing tests**

Add this to `test/game/mind_spark_game_test.dart` (before the final closing `}` of `main`), and add the `_stuckLevel` helper alongside the other level helpers near the bottom of the file:

```dart
  test(
    'forwards onAllPairsConnected when pairs connect but the board is unfilled',
    () {
      var stuckCount = 0;
      final game = MindSparkGame(
        level: _stuckLevel(),
        onCompleted: () {},
        onAllPairsConnected: () => stuckCount++,
      )..onGameResize(Vector2.all(300)); // 3x3 board → 100px cells

      game.handlePointerStart(_cellCenter(0, 0));
      game.handlePointerUpdate(_cellCenter(2, 0)); // red across the top row
      game.handlePointerEnd();
      expect(stuckCount, 0);

      game.handlePointerStart(_cellCenter(0, 2));
      game.handlePointerUpdate(_cellCenter(2, 2)); // blue across the bottom row
      game.handlePointerEnd();

      expect(stuckCount, 1);
      expect(game.snapshot.isComplete, isFalse);
    },
  );

  test('does not forward onAllPairsConnected on full completion', () {
    var stuckCount = 0;
    final game = MindSparkGame(
      level: _fillLevel(),
      onCompleted: () {},
      onAllPairsConnected: () => stuckCount++,
    )..onGameResize(Vector2.all(500));

    _completeLevel(game);

    expect(game.snapshot.isComplete, isTrue);
    expect(stuckCount, 0);
  });
```

Add this helper next to `_fillLevel()` / `_diagonalLevel()` near the bottom of the file:

```dart
// A 3x3 board whose direct pair connections leave the middle row empty, so
// connecting both pairs reaches "all pairs connected" without full coverage.
LevelModel _stuckLevel() => const LevelModel(
  id: 6,
  size: 3,
  points: [
    GridPoint(x: 0, y: 0, color: 'red'),
    GridPoint(x: 2, y: 0, color: 'red'),
    GridPoint(x: 0, y: 2, color: 'blue'),
    GridPoint(x: 2, y: 2, color: 'blue'),
  ],
);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/game/mind_spark_game_test.dart`
Expected: FAIL — compile error, `MindSparkGame` has no named parameter `onAllPairsConnected`.

- [ ] **Step 3: Implement the forwarding**

In `lib/game/mind_spark_game.dart`, replace the constructor (lines 12-15) with:

```dart
final class MindSparkGame extends FlameGame with DragCallbacks {
  MindSparkGame({
    required LevelModel level,
    required VoidCallback onCompleted,
    VoidCallback? onAllPairsConnected,
  }) : _level = level,
       _session = PuzzleSession(
         level: level,
         onCompleted: onCompleted,
         onAllPairsConnected: onAllPairsConnected,
       );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/game/mind_spark_game_test.dart`
Expected: PASS (all tests in the file, including the two new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/game/mind_spark_game.dart test/game/mind_spark_game_test.dart
git commit -m "feat: forward all-pairs-connected signal through MindSparkGame"
```

---

### Task 4: Build the `StuckHintFlash` overlay widget

**Files:**
- Create: `lib/core/widgets/stuck_hint_flash.dart`
- Test: `test/core/widgets/stuck_hint_flash_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `StuckHintFlash({Key? key, required int trigger, required String message})`. It is invisible (renders `SizedBox.shrink()`) until `trigger` changes to a value `> 0`; then it fades the message in, holds, and fades out once, returning to invisible.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/stuck_hint_flash_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/stuck_hint_flash.dart';

void main() {
  testWidgets('is hidden until triggered, then flashes once', (tester) async {
    var trigger = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                StuckHintFlash(trigger: trigger, message: 'fill it up'),
                ElevatedButton(
                  onPressed: () => setState(() => trigger++),
                  child: const Text('go'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('fill it up'), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pump(); // rebuild with new trigger
    await tester.pump(const Duration(milliseconds: 100)); // fade-in underway
    expect(find.text('fill it up'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // animation completes
    expect(find.text('fill it up'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/widgets/stuck_hint_flash_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mind_spark/core/widgets/stuck_hint_flash.dart'`.

- [ ] **Step 3: Implement the widget**

Create `lib/core/widgets/stuck_hint_flash.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A one-shot hint that fades in, holds, and fades out whenever [trigger]
/// increases. It occupies no space (renders nothing) while idle.
final class StuckHintFlash extends StatefulWidget {
  const StuckHintFlash({
    super.key,
    required this.trigger,
    required this.message,
  });

  final int trigger;
  final String message;

  @override
  State<StuckHintFlash> createState() => _StuckHintFlashState();
}

final class _StuckHintFlashState extends State<StuckHintFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _visible = false);
          }
        });
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(StuckHintFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      setState(() => _visible = true);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.deepCircuit.withAlpha(230),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          widget.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.frost,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/widgets/stuck_hint_flash_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/stuck_hint_flash.dart test/core/widgets/stuck_hint_flash_test.dart
git commit -m "feat: add one-shot StuckHintFlash overlay widget"
```

---

### Task 5: Build the `AdBannerSlot` widget

**Files:**
- Create: `lib/core/widgets/ad_banner_slot.dart`
- Test: `test/core/widgets/ad_banner_slot_test.dart`

**Interfaces:**
- Consumes: `google_mobile_ads` (Task 1).
- Produces: `AdBannerSlot({Key? key})` — a `const`-constructible widget that reserves a 60px-tall slot. Under `flutter test` it loads no ad and renders no `AdWidget`; at runtime it loads an anchored adaptive banner (falling back to `AdSize.banner`) and shows it once loaded.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/ad_banner_slot_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mind_spark/core/widgets/ad_banner_slot.dart';

void main() {
  testWidgets('reserves a fixed height and loads no ad under test', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: AdBannerSlot()))),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(AdBannerSlot)).height, 60);
    expect(find.byType(AdWidget), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/widgets/ad_banner_slot_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mind_spark/core/widgets/ad_banner_slot.dart'`.

- [ ] **Step 3: Implement the widget**

Create `lib/core/widgets/ad_banner_slot.dart`:

```dart
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
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/widgets/ad_banner_slot_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/ad_banner_slot.dart test/core/widgets/ad_banner_slot_test.dart
git commit -m "feat: add AdBannerSlot banner widget with test-safe no-op"
```

---

### Task 6: Wire the banner and flash into the gameplay screen

**Files:**
- Modify: `lib/features/gameplay/gameplay_screen.dart:18-25,207-231,359-501`
- Modify: `test/features/app_flow_test.dart:502-507`
- Modify: `test/features/persistence_flow_test.dart:100-103`
- Test: `test/features/gameplay_stuck_hint_test.dart` (create)

**Interfaces:**
- Consumes: `AdBannerSlot` (Task 5), `StuckHintFlash` (Task 4), `MindSparkGame(onAllPairsConnected:)` (Task 3).
- Produces: `MindSparkGameFactory = MindSparkGame Function(LevelModel level, VoidCallback onCompleted, VoidCallback onAllPairsConnected)`. Any test overriding `mindSparkGameFactoryProvider` must supply a `create` matching this 3-argument shape.

- [ ] **Step 1: Write the failing integration test**

Create `test/features/gameplay_stuck_hint_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

LevelModel _level(int id) => LevelModel(
  id: id,
  size: 5,
  points: const [
    GridPoint(x: 0, y: 0, color: 'red'),
    GridPoint(x: 4, y: 4, color: 'red'),
  ],
);

final class _GameHarness {
  VoidCallback? onAllPairsConnected;

  MindSparkGame create(
    LevelModel level,
    VoidCallback onCompleted,
    VoidCallback onAllPairsConnectedCb,
  ) {
    onAllPairsConnected = onAllPairsConnectedCb;
    return MindSparkGame(
      level: level,
      onCompleted: onCompleted,
      onAllPairsConnected: onAllPairsConnectedCb,
    );
  }
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  Widget app(_GameHarness harness, ProgressRepository repo) => ProviderScope(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => t0),
      levelByIdProvider(3).overrideWith((ref) async => _level(3)),
      levelTimerProvider.overrideWithValue((_) => const Duration(seconds: 60)),
      mindSparkGameFactoryProvider.overrideWithValue(harness.create),
    ],
    child: const MaterialApp(home: GameplayScreen(levelId: 3)),
  );

  testWidgets('shows the banner slot and no static hint during gameplay', (
    tester,
  ) async {
    final harness = _GameHarness();
    final repo = InMemoryProgressRepository(
      const PlayerProgress.initial()
          .copyWith(highestUnlockedLevel: 3)
          .copyWithLives(lives: 3, anchor: t0),
    );
    await tester.pumpWidget(app(harness, repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Connect matching sparks to fill the board.'), findsNothing);
    expect(find.byType(AdWidget), findsNothing); // ads are no-op under test
  });

  testWidgets('flashes the stuck hint when all pairs connect but board unfilled', (
    tester,
  ) async {
    final harness = _GameHarness();
    final repo = InMemoryProgressRepository(
      const PlayerProgress.initial()
          .copyWith(highestUnlockedLevel: 3)
          .copyWithLives(lives: 3, anchor: t0),
    );
    await tester.pumpWidget(app(harness, repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('All linked — now fill every square!'), findsNothing);

    harness.onAllPairsConnected!.call();
    await tester.pump(); // screen setState → new trigger
    await tester.pump(const Duration(milliseconds: 100)); // fade-in underway
    expect(find.text('All linked — now fill every square!'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/gameplay_stuck_hint_test.dart`
Expected: FAIL — compile error: `harness.create` does not match the 2-argument `MindSparkGameFactory`.

- [ ] **Step 3: Update the factory type, provider, and screen state**

In `lib/features/gameplay/gameplay_screen.dart`, add these imports next to the other `core/widgets` imports (near lines 10-11):

```dart
import 'package:mind_spark/core/widgets/ad_banner_slot.dart';
```
```dart
import 'package:mind_spark/core/widgets/stuck_hint_flash.dart';
```

Replace the typedef and provider (lines 18-25) with:

```dart
typedef MindSparkGameFactory =
    MindSparkGame Function(
      LevelModel level,
      VoidCallback onCompleted,
      VoidCallback onAllPairsConnected,
    );

final mindSparkGameFactoryProvider = Provider<MindSparkGameFactory>(
  (ref) =>
      (level, onCompleted, onAllPairsConnected) => MindSparkGame(
        level: level,
        onCompleted: onCompleted,
        onAllPairsConnected: onAllPairsConnected,
      ),
);
```

Add a state field next to `_redirectedOutOfLives` (after line 56):

```dart
  int _stuckFlashTick = 0;
```

Add a handler method (place it right after `_startTimer`, near line 93):

```dart
  void _handleAllPairsConnected() {
    if (!mounted) {
      return;
    }
    setState(() => _stuckFlashTick++);
  }
```

Update the factory call (lines 207-210) to pass the handler:

```dart
    final game = _game = ref.read(mindSparkGameFactoryProvider)(
      level,
      _handleCompletion,
      _handleAllPairsConnected,
    );
```

Update `_buildGame` (lines 219-231) to pass the tick:

```dart
  Widget _buildGame(MindSparkGame game) {
    return _GameplayView(
      levelId: widget.levelId,
      game: game,
      remaining: _remaining,
      lives: ref.watch(appProgressControllerProvider).value?.lives ?? 0,
      saveFailed: _saveFailed,
      needsProgressReload: _needsProgressReload,
      saving: _saving,
      stuckFlashTick: _stuckFlashTick,
      onRestart: game.restart,
      onRetry: _needsProgressReload ? _retryProgress : _retrySave,
    );
  }
```

- [ ] **Step 4: Update `_GameplayView` (constructor, board overlay, bottom slot)**

In `lib/features/gameplay/gameplay_screen.dart`, replace the `_GameplayView` constructor and fields (lines 359-380) with:

```dart
final class _GameplayView extends StatelessWidget {
  const _GameplayView({
    required this.levelId,
    required this.game,
    required this.remaining,
    required this.lives,
    required this.saveFailed,
    required this.needsProgressReload,
    required this.saving,
    required this.stuckFlashTick,
    required this.onRestart,
    required this.onRetry,
  });

  final int levelId;
  final MindSparkGame game;
  final Duration remaining;
  final int lives;
  final bool saveFailed;
  final bool needsProgressReload;
  final bool saving;
  final int stuckFlashTick;
  final VoidCallback onRestart;
  final VoidCallback onRetry;
```

Replace the board `Expanded` (lines 466-479) with a `Stack` that adds the flash overlay:

```dart
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ColoredBox(
                            color: AppColors.deepCircuit,
                            child: GameWidget(game: game),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: StuckHintFlash(
                          trigger: stuckFlashTick,
                          message: 'All linked — now fill every square!',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
```

Replace the bottom `if (saveFailed) … else Text(hint)` block (lines 481-494) with:

```dart
              if (saveFailed)
                _SaveFailure(
                  needsProgressReload: needsProgressReload,
                  saving: saving,
                  onRetry: onRetry,
                )
              else
                const AdBannerSlot(),
```

- [ ] **Step 5: Update the two existing test harnesses to the 3-argument factory**

In `test/features/app_flow_test.dart`, replace the `create` method (lines 502-507) with:

```dart
  MindSparkGame create(
    LevelModel level,
    VoidCallback onCompleted,
    VoidCallback onAllPairsConnected,
  ) {
    completions.add(onCompleted);
    final game = MindSparkGame(
      level: level,
      onCompleted: onCompleted,
      onAllPairsConnected: onAllPairsConnected,
    );
    games.add(game);
    return game;
  }
```

In `test/features/persistence_flow_test.dart`, replace the `create` method (lines 100-103) with:

```dart
  MindSparkGame create(
    LevelModel level,
    VoidCallback onCompleted,
    VoidCallback onAllPairsConnected,
  ) {
    completions.add(onCompleted);
    return MindSparkGame(
      level: level,
      onCompleted: onCompleted,
      onAllPairsConnected: onAllPairsConnected,
    );
  }
```

- [ ] **Step 6: Run the new test and the full suite**

Run: `flutter test test/features/gameplay_stuck_hint_test.dart`
Expected: PASS (both tests).

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests pass (the prior 184 plus the new files).

- [ ] **Step 7: Commit**

```bash
git add lib/features/gameplay/gameplay_screen.dart test/features/app_flow_test.dart test/features/persistence_flow_test.dart test/features/gameplay_stuck_hint_test.dart
git commit -m "feat: replace gameplay hint with AdMob banner and stuck-state flash"
```

---

## Self-Review

**Spec coverage:**
- Dependency + init → Task 1. ✓
- Android config (App ID, minSdk) → Task 1. ✓
- `AdBannerSlot` (adaptive banner, reserved height, test no-op, dispose) → Task 5. ✓
- Layout change (remove static hint, banner as bottom content, save-failure priority) → Task 6 Step 4. ✓
- Stuck-hint signal (`onAllPairsConnected` in session + game + factory) → Tasks 2, 3, 6. ✓
- One-shot flash overlay above the banner (no layout shift, `Stack`/`Positioned`) → Tasks 4, 6. ✓
- Flash copy `All linked — now fill every square!` → Tasks 4/6 (verbatim). ✓
- Child-directed request config values → Task 1 (verbatim). ✓
- Test strategy (session unit tests, widget flash test, existing suite green) → Tasks 2, 4, 6. ✓
- Out of scope (iOS, interstitial/rewarded, consent platform) → not planned. ✓

**Placeholder scan:** No `TBD`/`TODO`/"handle edge cases" in plan steps. The two `TODO` comments in code (real App ID / ad unit) are intentional, spec-mandated markers, not plan gaps. ✓

**Type consistency:** `onAllPairsConnected` is the name used across `PuzzleSession` (Task 2), `MindSparkGame` (Task 3), `MindSparkGameFactory` and provider (Task 6), and both harnesses (Task 6). `StuckHintFlash(trigger:, message:)` matches between Tasks 4 and 6. `AdBannerSlot()` const constructor matches between Tasks 5 and 6. `_stuckFlashTick` is the single source feeding `stuckFlashTick`. ✓
