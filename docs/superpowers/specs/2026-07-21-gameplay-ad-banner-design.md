# Gameplay Ad Banner + Conditional Hint Flash — Design

**Date:** 2026-07-21
**Status:** Approved (pending user spec review)
**Area:** `lib/features/gameplay`, `lib/game`, `lib/core/widgets`, Android config

## Goal

Show a real Google AdMob banner in the area beneath the game board during
gameplay, occupying the slot currently used by the static hint text. Remove the
always-on hint. Instead, surface the hint **only** when the player has connected
every color pair but has not filled the whole board (a stuck / no-win state),
flashing it once as an overlay just above the banner.

## Decisions (locked)

- **Ad type:** Real AdMob banner via the `google_mobile_ads` package.
- **Placement:** Replaces the static bottom hint text. The banner is the normal
  bottom-of-screen content during gameplay.
- **Hint behavior:** The hint appears only in the "all pairs connected but board
  not full" state, flashing once (fade in → fade out) as an overlay above the
  banner. It does not consume layout height, so the board is not shrunk.
- **Platform:** Android configuration only for now. Dart code stays
  platform-agnostic; iOS `Info.plist` / App ID is deferred.
- **Audience:** Child-directed. `RequestConfiguration` sets
  `tagForChildDirectedTreatment = true`, `maxAdContentRating = 'G'`, and
  non-personalized ads.

## Architecture

Chosen approach: a self-contained `AdBannerSlot` widget that encapsulates the
banner's load/dispose lifecycle, consistent with the project's existing DI style
(`mindSparkGameFactoryProvider`, `levelTimerProvider`, `clockProvider`).

Rejected alternative: loading the banner directly inside `_GameplayScreenState`.
It couples ad lifecycle to the screen, bloats the screen state, and is hard to
test. Not used.

### Test-safety principle

`google_mobile_ads` calls platform channels that are unavailable under
`flutter test`. `AdBannerSlot` therefore renders a fixed-height empty
`SizedBox` when `Platform.environment.containsKey('FLUTTER_TEST')` is true, and
never touches the plugin. This keeps all existing widget tests (184) green with
no per-test overrides. `MobileAds.instance.initialize()` runs only in `main()`,
which tests do not execute, so the SDK is never initialized in tests.

## Components

### 1. Dependency & initialization

- Add `google_mobile_ads` to `pubspec.yaml` dependencies.
- In `lib/main.dart`, after `WidgetsFlutterBinding.ensureInitialized()`, call
  `MobileAds.instance.initialize()` and apply a child-directed
  `RequestConfiguration`:
  - `maxAdContentRating = MaxAdContentRating.g`
  - `tagForChildDirectedTreatment = TagForChildDirectedTreatment.yes`
  - `tagForUnderAgeOfConsent = TagForUnderAgeOfConsent.yes`
- Initialization is fire-and-forget; it must not block or delay `runApp`.

### 2. Android configuration

- `android/app/src/main/AndroidManifest.xml`: add inside `<application>`:
  ```xml
  <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-3940256099942544~3347511713"/>
  ```
  (Google's official **test** App ID. Marked with a `TODO` to swap the real ID.)
- `android/app/build.gradle.kts`: pin `minSdk = 23` (google_mobile_ads
  requirement; currently inherits `flutter.minSdkVersion`).

### 3. `AdBannerSlot` widget — `lib/core/widgets/ad_banner_slot.dart`

- `StatefulWidget`. On init (non-test), loads an **anchored adaptive banner**
  sized to the available width; falls back to `AdSize.banner` (320×50) if the
  adaptive size cannot be resolved.
- Ad unit id: Google's official **test** banner unit
  `ca-app-pub-3940256099942544/6300978111`, with a `TODO` for the real unit.
- Reserves a stable min-height container (≈60 px) so the layout does not jump
  before the ad loads or if it fails to load.
- Disposes the `BannerAd` in `dispose()`.
- Returns an empty fixed-height `SizedBox` under `FLUTTER_TEST`.

### 4. Gameplay layout change — `lib/features/gameplay/gameplay_screen.dart`

In `_GameplayView.build()` bottom section (currently the hint `Text` / save
failure branch, ~L466–494):

- Remove the always-on hint `Text('Connect matching sparks to fill the board.')`.
- Normal state: render `AdBannerSlot()` as the bottom content.
- `saveFailed` state: the `_SaveFailure` widget takes priority and is shown in
  place of the banner (no ad shown during the error path).
- The stuck-hint flash overlay (below) is layered above the banner via a
  `Stack`, so it never shifts layout.

### 5. Stuck-hint flash

**Signal.** Add a second callback to the game domain, mirroring `onCompleted`:

- `PuzzleSession` gains an `onAllPairsConnected` callback (nullable).
- In `extendPath`, when a path becomes `connected` (existing branch at
  L102–108): if `isComplete` → call `onCompleted` (unchanged); else if all
  endpoint-color pairs are now connected (i.e.
  `_paths.length == _endpointsByColor.length &&
  _paths.values.every((p) => p.connected)`) → call `onAllPairsConnected`.
- `MindSparkGame` forwards this callback through its constructor, and
  `mindSparkGameFactoryProvider` passes it from the gameplay screen. The factory
  typedef gains the extra callback parameter.

**Semantics.** Fires each time the player enters the all-connected-but-not-full
state (each time the final pair is connected without filling the board). One
flash per entry; re-entering flashes again.

**Presentation.** The gameplay screen holds a one-shot flash trigger. On the
signal it plays a short fade in → hold → fade out (via `AnimationController` /
`AnimatedOpacity`) of a hint chip positioned as a `Stack` overlay just above the
banner. If a flash is already running, it restarts.

**Copy.** Default hint text: `All linked — now fill every square!`
(English, matching existing UI copy; adjustable later).

### 6. Test strategy

- `AdBannerSlot` is a no-op under `FLUTTER_TEST`; existing gameplay/widget
  tests remain unchanged and green.
- New tests cover the flash mechanism, which is pure Flutter/Dart and driven by
  the callback:
  - `PuzzleSession` invokes `onAllPairsConnected` when the last pair connects
    without completing the board, and does **not** invoke it when the board is
    completed (that path calls `onCompleted`).
  - Widget-level: when the injected fake game triggers the
    all-pairs-connected callback, the gameplay screen shows the hint overlay;
    it is absent otherwise.
- Existing fake-game injection via `mindSparkGameFactoryProvider` is reused to
  drive the widget test.

## Data flow

```
drag → MindSparkGame.handlePointerUpdate → PuzzleSession.extendPath
        └─ path.connected = true
             ├─ isComplete           → onCompleted        → navigate to result
             └─ all pairs connected  → onAllPairsConnected → gameplay screen
                & !isComplete                                flashes hint overlay
```

Banner lifecycle is independent of game state: `AdBannerSlot` loads on mount and
disposes on unmount, unaffected by drags or the flash.

## Error handling

- Banner fails to load / no fill: slot keeps its reserved empty height; no error
  surfaced to the player.
- SDK not initialized (e.g. tests): slot is a no-op `SizedBox`; plugin untouched.
- Save failure during completion: `_SaveFailure` replaces the banner; retry flow
  unchanged.

## Risks / open items

- **Families policy:** child-directed apps must serve non-personalized ads from
  certified networks. `RequestConfiguration` handles the request flags, but the
  AdMob account/app must be reviewed against Google Families policy before
  release.
- **minSdk 23** drops Android API 21–22 device support (hard requirement of the
  ads SDK).
- **Test ad IDs** produce no real revenue; real App ID + ad unit ID must be
  supplied and swapped at the two `TODO` sites before release.

## Out of scope

- iOS configuration (App ID, `Info.plist`, ATT prompt).
- Interstitial / rewarded ad formats.
- Consent management platform (UMP / GDPR consent form).
- Ads on any screen other than gameplay.
