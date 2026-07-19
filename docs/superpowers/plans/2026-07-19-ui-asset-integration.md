# UI Asset Integration + Star Rating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap the cartoon PNGs in `assets/ui/` into every screen (buttons, hearts, win board), add a time-based 1–3 star rating on a redesigned win screen, and persist each level's best stars (schema v2 → v3).

**Architecture:** A shared `ImageButton` and `HeartsRow` render the PNGs; a pure `starsForResult` computes stars from remaining/limit at win; `PlayerProgress` gains a `levelStars` map behind a v3 migration; the Result screen becomes a `wonboard.png` stack with the matching star row and `nextbutton.png`.

**Tech Stack:** Flutter, Flame, flutter_riverpod, hive_ce; Dart `^3.12.2`.

## Global Constraints

- Dart SDK `^3.12.2`; **add no new dependencies**. `final class`, Riverpod, one atomic version-stamped progress record.
- Max lives is `LivesRegen.maxLives` (currently 3) — never hardcode; reference it.
- Star thresholds (by `remaining/timeLimit`): `>= 0.7 → 3`, `>= 0.4 → 2`, else `1`. Finishing always earns ≥ 1.
- `levelStars` values are 1..3; keys are completed level ids. Persist best (max) only.
- Button PNGs carry baked labels — never overlay text on them. HOME uses a Material home icon (no asset).
- Keep the dark background and current layouts; swap only asset-covered widgets. Ad refill stays a disabled placeholder.
- Asset paths live only in `AppImages`.
- Spec: `docs/superpowers/specs/2026-07-19-ui-asset-integration-design.md`.

---

### Task 1: Assets, `AppImages`, and `ImageButton`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/theme/app_images.dart`
- Create: `lib/core/widgets/image_button.dart`
- Test: `test/core/widgets/image_button_test.dart`

**Interfaces:**
- Produces:
  - `AppImages.{playButton, nextButton, heart, replayButton, refillButton, watchAddButton, soundButton, wonBoard, star1, star2, star3, starN(int)}` → `String` asset paths. `starN(n)` returns `star1|star2|star3`.
  - `ImageButton({required String asset, required VoidCallback? onPressed, double? width, double? height, String? semanticLabel})` — tappable image; dims + ignores taps when `onPressed == null`.

- [ ] **Step 1: Declare the assets**

In `pubspec.yaml` under `flutter:`, add to the existing `assets:` list (which currently has `assets/levels/levels.json`):
```yaml
    - assets/ui/
```
Run `flutter pub get`.

- [ ] **Step 2: Create `AppImages`**

`lib/core/theme/app_images.dart`:
```dart
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
```

- [ ] **Step 3: Write the failing `ImageButton` test**

`test/core/widgets/image_button_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/image_button.dart';

void main() {
  testWidgets('fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ImageButton(
          asset: 'assets/ui/playbutton.png',
          semanticLabel: 'Play',
          onPressed: () => taps++,
        ),
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Play'));
    expect(taps, 1);
  });

  testWidgets('ignores taps and dims when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ImageButton(
          asset: 'assets/ui/playbutton.png',
          semanticLabel: 'Play',
          onPressed: null,
        ),
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Play'), warnIfMissed: false);
    expect(taps, 0);
    expect(
      tester.widget<Opacity>(find.byType(Opacity)).opacity,
      lessThan(1.0),
    );
  });
}
```

- [ ] **Step 4: Run — verify it fails**

Run: `flutter test test/core/widgets/image_button_test.dart`
Expected: FAIL ("Target of URI doesn't exist: 'image_button.dart'").

- [ ] **Step 5: Implement `ImageButton`**

`lib/core/widgets/image_button.dart`:
```dart
import 'package:flutter/material.dart';

/// A tappable PNG button. Dims and ignores input when [onPressed] is null.
final class ImageButton extends StatefulWidget {
  const ImageButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String asset;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  State<ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Image.asset(
              widget.asset,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run — verify it passes**

Run: `flutter test test/core/widgets/image_button_test.dart`
Expected: PASS. Then `flutter analyze` → no issues.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml lib/core/theme/app_images.dart lib/core/widgets/image_button.dart test/core/widgets/image_button_test.dart
git commit -m "feat: declare ui assets, add AppImages paths and ImageButton"
```

---

### Task 2: `HeartsRow` (heart.png) across screens

**Files:**
- Modify: `lib/core/widgets/lives_bar.dart`
- Modify: `lib/features/gameplay/gameplay_screen.dart` (header hearts)
- Test: `test/core/widgets/hearts_row_test.dart`
- Test (update): `test/features/home_screen_lives_test.dart`

**Interfaces:**
- Consumes: `AppImages.heart`, `LivesRegen.maxLives`.
- Produces: `HeartsRow({required int lives, double size = 26})` — a `Row` of `LivesRegen.maxLives` `heart.png` images; the first `lives` at full opacity, the rest at 0.25. Exported from `lives_bar.dart`.

- [ ] **Step 1: Write the failing `HeartsRow` test**

`test/core/widgets/hearts_row_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';

void main() {
  testWidgets('renders maxLives hearts, dimming the empties', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HeartsRow(lives: 1)),
    ));

    final images = find.byType(Image);
    expect(images, findsNWidgets(LivesRegen.maxLives));

    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .toList();
    expect(opacities.where((o) => o == 1.0).length, 1); // 1 full
    expect(opacities.where((o) => o < 1.0).length, LivesRegen.maxLives - 1);
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/core/widgets/hearts_row_test.dart`
Expected: FAIL ("HeartsRow isn't defined").

- [ ] **Step 3: Add `HeartsRow` and use it in `LivesBar`**

In `lib/core/widgets/lives_bar.dart`, add the import `import 'package:mind_spark/core/theme/app_images.dart';` and this widget:
```dart
/// A row of heart.png icons: [lives] filled, the rest dimmed.
final class HeartsRow extends StatelessWidget {
  const HeartsRow({super.key, required this.lives, this.size = 26});

  final int lives;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < LivesRegen.maxLives; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: i < lives ? 1.0 : 0.25,
              child: Image.asset(AppImages.heart, width: size, height: size),
            ),
          ),
      ],
    );
  }
}
```
In `_LivesBarState.build`, replace the inline `Row(... Icon(...) ...)` hearts with `HeartsRow(lives: result.lives)`. Keep the "Next life" countdown text below it.

- [ ] **Step 4: Swap the gameplay header hearts**

In `lib/features/gameplay/gameplay_screen.dart` `_GameplayView.build`, replace the inline `for (var i = 0; i < LivesRegen.maxLives; i++) Icon(...)` heart loop with `HeartsRow(lives: lives, size: 16)`. (`lives_bar.dart` is already imported for `formatCountdown`.)

- [ ] **Step 5: Update the Home lives test to heart images**

In `test/features/home_screen_lives_test.dart`, the hearts are now `Image` widgets, not `Icon`s. Replace icon finders:
- `find.byIcon(Icons.favorite)` (filled) → count full-opacity heart images:
```dart
int _fullHearts(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .where((o) => o.opacity == 1.0)
    .length;
```
- In 'renders one filled heart per life' (lives 1): `expect(_fullHearts(tester), 1);` and keep `expect(find.textContaining('Next life'), findsOneWidget);`.
- In 'shows three filled hearts ... when full': `expect(_fullHearts(tester), 3);` and `expect(find.textContaining('Next life'), findsNothing);`.
- 'locks PLAY when out of lives' is unaffected (it checks the PLAY button); leave it (it still uses the current FilledButton — Task 7 changes PLAY, which will update this test then).

- [ ] **Step 6: Run — verify green**

Run: `flutter test test/core/widgets/hearts_row_test.dart test/features/home_screen_lives_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/lives_bar.dart lib/features/gameplay/gameplay_screen.dart test/core/widgets/hearts_row_test.dart test/features/home_screen_lives_test.dart
git commit -m "feat: render lives with heart.png via shared HeartsRow"
```

---

### Task 3: `starsForResult` pure function

**Files:**
- Modify: `lib/game/generation/level_timer.dart`
- Test: `test/game/generation/level_timer_test.dart`

**Interfaces:**
- Produces: `int starsForResult({required Duration remaining, required Duration timeLimit})` — ratio-based 1..3; zero/`<=0` limit → 1; clamps.

- [ ] **Step 1: Write the failing tests**

Add to `test/game/generation/level_timer_test.dart`:
```dart
  group('starsForResult', () {
    Duration s(int n) => Duration(seconds: n);
    test('thresholds', () {
      expect(starsForResult(remaining: s(70), timeLimit: s(100)), 3);
      expect(starsForResult(remaining: s(69), timeLimit: s(100)), 2);
      expect(starsForResult(remaining: s(40), timeLimit: s(100)), 2);
      expect(starsForResult(remaining: s(39), timeLimit: s(100)), 1);
      expect(starsForResult(remaining: s(0), timeLimit: s(100)), 1);
    });
    test('full time is 3 stars', () {
      expect(starsForResult(remaining: s(100), timeLimit: s(100)), 3);
    });
    test('zero or negative limit yields 1', () {
      expect(starsForResult(remaining: s(0), timeLimit: Duration.zero), 1);
    });
    test('clamps over-full remaining to 3', () {
      expect(starsForResult(remaining: s(200), timeLimit: s(100)), 3);
    });
  });
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/game/generation/level_timer_test.dart`
Expected: FAIL ("starsForResult isn't defined").

- [ ] **Step 3: Implement**

Append to `lib/game/generation/level_timer.dart`:
```dart
/// Stars (1..3) for finishing a level with [remaining] of [timeLimit] left.
int starsForResult({required Duration remaining, required Duration timeLimit}) {
  if (timeLimit.inMilliseconds <= 0) {
    return 1;
  }
  final ratio =
      (remaining.inMilliseconds / timeLimit.inMilliseconds).clamp(0.0, 1.0);
  if (ratio >= 0.7) {
    return 3;
  }
  if (ratio >= 0.4) {
    return 2;
  }
  return 1;
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/game/generation/level_timer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/generation/level_timer.dart test/game/generation/level_timer_test.dart
git commit -m "feat: add time-based star rating function"
```

---

### Task 4: `PlayerProgress.levelStars` + schema v3

**Files:**
- Modify: `lib/models/player_progress.dart`
- Test: `test/models/player_progress_test.dart`
- Test (fix fallout): `test/repositories/hive_progress_repository_test.dart`

**Interfaces:**
- Produces:
  - `PlayerProgress.levelStars` → unmodifiable `Map<int,int>` (levelId → 1..3).
  - `completeLevel({required int levelId, int? nextLevelId, int? stars})` — additionally records `max(existing, stars.clamp(1,3))` when `stars != null`.
  - schema **3** everywhere; `fromPersistedMap` accepts 1/2/3 (v1/v2 → empty `levelStars`).

- [ ] **Step 1: Write failing model tests**

Add to `test/models/player_progress_test.dart` (inside the group):
```dart
    test('initial has empty levelStars', () {
      expect(const PlayerProgress.initial().levelStars, isEmpty);
      expect(const PlayerProgress.initial().schemaVersion, 3);
    });

    test('completeLevel records and keeps the best stars', () {
      final a = const PlayerProgress.initial()
          .completeLevel(levelId: 1, nextLevelId: 2, stars: 2);
      expect(a.levelStars, {1: 2});
      final b = a.completeLevel(levelId: 1, stars: 1); // replay, worse
      expect(b.levelStars, {1: 2}); // best kept
      final c = a.completeLevel(levelId: 1, nextLevelId: 3, stars: 3);
      expect(c.levelStars, {1: 3}); // improved
    });

    test('v3 round-trips levelStars', () {
      final record = <Object?, Object?>{
        'schemaVersion': 3,
        'highestUnlockedLevel': 3,
        'completedLevelIds': <int>[1, 2],
        'totalScore': 200,
        'lives': 2,
        'livesRegenAnchor': null,
        'levelStars': <String, Object?>{'1': 3, '2': 2},
        'soundEnabled': true,
        'vibrationEnabled': true,
      };
      final p = PlayerProgress.fromPersistedMap(record);
      expect(p.levelStars, {1: 3, 2: 2});
      expect(PlayerProgress.fromPersistedMap(p.toMap()), p);
    });

    test('v2 record migrates to v3 with empty levelStars', () {
      final p = PlayerProgress.fromPersistedMap(<Object?, Object?>{
        'schemaVersion': 2,
        'highestUnlockedLevel': 2,
        'completedLevelIds': <int>[1],
        'totalScore': 100,
        'lives': 2,
        'soundEnabled': true,
        'vibrationEnabled': true,
      });
      expect(p.schemaVersion, 3);
      expect(p.levelStars, isEmpty);
      expect(p.lives, 2);
    });

    test('rejects bad levelStars', () {
      Map<Object?, Object?> base() => {
        'schemaVersion': 3,
        'highestUnlockedLevel': 2,
        'completedLevelIds': <int>[1],
        'totalScore': 100,
        'lives': 2,
        'soundEnabled': true,
        'vibrationEnabled': true,
      };
      for (final bad in <Object?>[
        {'1': 0}, // < 1
        {'1': 4}, // > 3
        {'2': 3}, // key not completed
      ]) {
        expect(
          () => PlayerProgress.fromPersistedMap({...base(), 'levelStars': bad}),
          throwsA(isA<ProgressFormatException>()),
          reason: 'levelStars: $bad',
        );
      }
    });
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/models/player_progress_test.dart`
Expected: FAIL (levelStars/schema 3 not present).

- [ ] **Step 3: Implement the model changes**

In `lib/models/player_progress.dart`:
- Add `final Map<int, int> levelStars;` and thread it through the factory (`Map<int,int> levelStars = const {}` param → `Map<int,int>.unmodifiable(levelStars)`), private ctor, `initial` (`const <int,int>{}`), `copyWith`, `copyWithLives`, `==`, `hashCode`.
- Change `_schemaVersion` to return **3**; in `fromPersistedMap` accept `1 || 2 || 3` (else throw); compute `levelStars` = `schemaVersion == 3 ? _requiredLevelStars(record, completedLevelIds) : const <int,int>{}`.
- `completeLevel` signature `{required int levelId, int? nextLevelId, int? stars}`. Replace the second early-return guard `if (!isFirstCompletion && !unlocksNextLevel) return this;` with:
```dart
    final improvesStars = stars != null &&
        stars.clamp(1, 3) > (levelStars[levelId] ?? 0);
    if (!isFirstCompletion && !unlocksNextLevel && !improvesStars) {
      return this;
    }
```
  and when building the returned `PlayerProgress`, compute + pass:
```dart
    final updatedLevelStars = stars == null
        ? levelStars
        : {
            ...levelStars,
            levelId: [
              stars.clamp(1, 3),
              levelStars[levelId] ?? 0,
            ].reduce((a, b) => a > b ? a : b),
          };
    // ... levelStars: Map<int, int>.unmodifiable(updatedLevelStars),
```
- `toMap`: add `'levelStars': { for (final e in levelStars.entries) e.key: e.value }` and set `schemaVersion: 3`.
- Add the parser helper (top-level, like `_persistedAnchor`):
```dart
Map<int, int> _requiredLevelStars(
  Map<Object?, Object?> record,
  Set<int> completed,
) {
  final raw = record['levelStars'];
  if (raw == null) return const <int, int>{};
  if (raw is! Map) {
    throw const ProgressFormatException(
      field: 'levelStars',
      message: 'must be a map',
    );
  }
  final out = <int, int>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final levelId = key is int ? key : int.tryParse('$key');
    final value = entry.value;
    if (levelId == null ||
        levelId <= 0 ||
        value is! int ||
        value < 1 ||
        value > 3 ||
        !completed.contains(levelId)) {
      throw const ProgressFormatException(
        field: 'levelStars',
        message: 'keys must be completed level ids, values 1..3',
      );
    }
    out[levelId] = value;
  }
  return Map<int, int>.unmodifiable(out);
}
```

- [ ] **Step 4: Run model tests + fix Hive test fallout**

Run: `flutter test test/models/player_progress_test.dart`
Expected: PASS.
Then the Hive repo test's migration test asserts `loaded.schemaVersion, 2` for a v1 record — update it to `3`, and add `expect(loaded.levelStars, isEmpty);`. Run `flutter test test/repositories/hive_progress_repository_test.dart` → PASS.

- [ ] **Step 5: Run the full suite**

Run: `flutter test && flutter analyze`
Expected: PASS. Fix any straggler asserting `schemaVersion == 2` → `3` (mechanical).

- [ ] **Step 6: Commit**

```bash
git add lib/models/player_progress.dart test/models/player_progress_test.dart test/repositories/hive_progress_repository_test.dart
git commit -m "feat: persist best stars per level via schema v3"
```

---

### Task 5: Wire stars from gameplay win → Result

**Files:**
- Modify: `lib/app/routes.dart` (`ResultRouteArgs.stars`)
- Modify: `lib/app/app.dart` (route guard)
- Modify: `lib/state/app_progress_controller.dart` (`completeLevel` passes `stars`)
- Modify: `lib/features/gameplay/gameplay_screen.dart` (`_handleCompletion` computes stars)
- Test (update): `test/features/app_flow_test.dart`, `test/state/app_progress_controller_test.dart`

**Interfaces:**
- Consumes: `starsForResult` (Task 3), `completeLevel(..., stars:)` (Task 4).
- Produces: `ResultRouteArgs({required int levelId, required int awardedScore, required int stars})`; `AppProgressController.completeLevel({required int levelId, int? nextLevelId, int? stars})`.

- [ ] **Step 1: Add `stars` to `ResultRouteArgs`**

In `lib/app/routes.dart`, add `final int stars;` to `ResultRouteArgs` (required, constructor updated).

- [ ] **Step 2: Route guard in `app.dart`**

Update the `AppRoutes.result` arm to destructure and validate stars:
```dart
    AppRoutes.result => switch (settings.arguments) {
      ResultRouteArgs(:final levelId, :final awardedScore, :final stars)
          when levelId > 0 && awardedScore >= 0 && stars >= 1 && stars <= 3 =>
        ResultScreen(levelId: levelId, awardedScore: awardedScore, stars: stars),
      _ => const _SafeRouteError(),
    },
```
(`ResultScreen` gains a `stars` field in Task 6 — land Tasks 5 and 6 together, or add the field first.)

- [ ] **Step 3: Controller passes stars**

In `lib/state/app_progress_controller.dart`, change `completeLevel`/`_completeLevel` to accept `int? stars` and pass it to `current.completeLevel(levelId: levelId, nextLevelId: nextLevelId, stars: stars)`.

- [ ] **Step 4: Gameplay computes + passes stars**

In `lib/features/gameplay/gameplay_screen.dart`:
- Add a field `int _stars = 1;`.
- In `_handleCompletion`, after `_countdown?.cancel();`, set `_stars = starsForResult(remaining: _remaining, timeLimit: _timeLimit);`.
- Pass `stars: _stars` to the `completeLevel(...)` call.
- In `_navigateToResult()`, add `stars: _stars` to the `ResultRouteArgs(...)`.

- [ ] **Step 5: Update the affected tests**

- `test/state/app_progress_controller_test.dart`: existing `completeLevel(levelId: 1, nextLevelId: 2)` calls still compile (stars optional). Add: `await controller.completeLevel(levelId: 1, nextLevelId: 2, stars: 3);` then `expect(progress.levelStars, {1: 3});`.
- `test/features/app_flow_test.dart`: any direct `ResultRouteArgs(...)` construction now needs `stars:` (use `stars: 3`). Completion flows go through gameplay which supplies stars. (Result-screen content assertions updated in Task 6.)

- [ ] **Step 6: Run + commit**

Run: `flutter test && flutter analyze` → PASS.
```bash
git add lib/app/routes.dart lib/app/app.dart lib/state/app_progress_controller.dart lib/features/gameplay/gameplay_screen.dart test/state/app_progress_controller_test.dart test/features/app_flow_test.dart
git commit -m "feat: compute and thread level stars to the result screen"
```

---

### Task 6: Result win-board redesign

**Files:**
- Modify: `lib/features/result/result_screen.dart`
- Test: `test/features/result_screen_test.dart` (new)
- Test (update): `test/features/app_flow_test.dart` (result assertions)

**Interfaces:**
- Consumes: `AppImages.{wonBoard, starN, nextButton}`, `ImageButton`, `ResultRouteArgs.stars`.
- Produces: `ResultScreen({required int levelId, required int awardedScore, required int stars})`.

- [ ] **Step 1: Write the failing Result test**

`test/features/result_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Widget _harness(int stars) => ProviderScope(
  overrides: [
    progressRepositoryProvider.overrideWithValue(InMemoryProgressRepository()),
  ],
  child: MaterialApp(
    home: ResultScreen(levelId: 1, awardedScore: 100, stars: stars),
  ),
);

bool _hasAsset(WidgetTester tester, String asset) => tester
    .widgetList<Image>(find.byType(Image))
    .any((i) => i.image is AssetImage && (i.image as AssetImage).assetName == asset);

void main() {
  testWidgets('shows the won board, the matching star row, and next', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(2));
    await tester.pump();

    expect(_hasAsset(tester, AppImages.wonBoard), isTrue);
    expect(_hasAsset(tester, AppImages.star2), isTrue);
    expect(find.bySemanticsLabel('Next level'), findsOneWidget);
  });

  testWidgets('three stars uses 3star.png', (tester) async {
    await tester.pumpWidget(_harness(3));
    await tester.pump();
    expect(_hasAsset(tester, AppImages.star3), isTrue);
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/features/result_screen_test.dart`
Expected: FAIL (ResultScreen has no `stars`).

- [ ] **Step 3: Redesign `ResultScreen`**

Add `final int stars;` (required) to `ResultScreen`. Keep `_navigate`/`_navigating` and the total-score read. Replace the `build` body with a board Stack:
```dart
    final totalScore =
        ref.watch(appProgressControllerProvider).requireValue.totalScore;
    final nextLevelId = widget.levelId + 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardWidth =
                  constraints.maxWidth.clamp(0.0, 420.0) - 24;
              return SizedBox(
                width: boardWidth,
                child: AspectRatio(
                  aspectRatio: 3476 / 4031, // wonboard.png
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(AppImages.wonBoard,
                            fit: BoxFit.contain),
                      ),
                      Align(
                        alignment: const Alignment(0, -0.35),
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          child: Image.asset(AppImages.starN(widget.stars)),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.18),
                        child: Text(
                          'Score  $totalScore   (+${widget.awardedScore})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: const Color(0xFF5B3A1A)),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.62),
                        child: FractionallySizedBox(
                          widthFactor: 0.66,
                          child: ImageButton(
                            asset: AppImages.nextButton,
                            semanticLabel: 'Next level',
                            onPressed: _navigating
                                ? null
                                : () => _navigate(nextLevelId),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-0.92, -0.98),
                        child: IconButton(
                          icon: const Icon(Icons.home_rounded),
                          color: const Color(0xFF5B3A1A),
                          onPressed: _navigating
                              ? null
                              : () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(
                                      AppRoutes.home, (_) => false),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
```
Add imports for `AppImages`, `ImageButton`; drop `SparkTrail` import (now unused). The `Alignment` offsets are tuned against the board art — nudge so stars sit on the star plank and Next on the lower plank when you run the app.

- [ ] **Step 4: Update `app_flow_test` result assertions**

Where `app_flow_test` asserts `find.text('+100')`, `find.text('Total Score: 100')`, `find.text('NEXT LEVEL')`, `find.text('LEVEL COMPLETE')`, replace with the new surface:
- Next action → `find.bySemanticsLabel('Next level')` (tap it the same way).
- Score → `find.textContaining('Score')`.
- Remove the `LEVEL COMPLETE` finder.
- HOME on the result screen is now the home `IconButton` → `find.byIcon(Icons.home_rounded)`.
Keep behavioral assertions (tapping Next creates the next game; HOME returns home).

- [ ] **Step 5: Run + commit**

Run: `flutter test && flutter analyze` → PASS.
```bash
git add lib/features/result/result_screen.dart test/features/result_screen_test.dart test/features/app_flow_test.dart
git commit -m "feat: redesign win screen with won board, stars, and next button"
```

---

### Task 7: Swap remaining buttons (Home, Settings, Out-of-Lives, timeout dialog)

**Files:**
- Modify: `lib/features/home/home_screen.dart` (PLAY → playbutton)
- Modify: `lib/features/settings/settings_screen.dart` (sound → soundbutton)
- Modify: `lib/features/out_of_lives/out_of_lives_screen.dart` (refill/watch-ad)
- Modify: `lib/features/gameplay/gameplay_screen.dart` (timeout dialog RETRY → replaybutton)
- Test (update): `test/features/home_screen_lives_test.dart`, `test/features/out_of_lives_screen_test.dart`, `test/features/settings_screen_test.dart`, `test/features/gameplay_timer_test.dart`, `test/features/app_flow_test.dart`

**Interfaces:**
- Consumes: `ImageButton`, `AppImages.*`.

- [ ] **Step 1: Home PLAY → playbutton**

Replace the `FilledButton(... 'PLAY')` in `home_screen.dart` with:
```dart
                      ImageButton(
                        asset: AppImages.playButton,
                        semanticLabel: 'Play',
                        width: 220,
                        onPressed: (_openingGame || livesNow <= 0)
                            ? null
                            : () => _openGame(currentLevel.id),
                      ),
```
Add imports for `AppImages`/`ImageButton`. Update `test/features/home_screen_lives_test.dart`:
- 'locks PLAY when out of lives' → assert `find.bySemanticsLabel('Play')` exists and is disabled: `tester.widget<Semantics>(find.bySemanticsLabel('Play')).properties.enabled == false` (or assert the OUT OF LIVES button is present).
- Add a full-lives test: tapping `find.bySemanticsLabel('Play')` pushes a gameplay route (use a `navigatorObserver` or assert a route change).

- [ ] **Step 2: Settings sound → soundbutton**

In `settings_screen.dart`, replace the Sound `SwitchListTile` with a `ListTile(title: const Text('Sound'), trailing: ...)` whose trailing dims when muted:
```dart
                    Opacity(
                      opacity: progress.soundEnabled ? 1 : 0.4,
                      child: ImageButton(
                        asset: AppImages.soundButton,
                        semanticLabel: 'Sound',
                        width: 48,
                        height: 48,
                        onPressed: () =>
                            controller.setSoundEnabled(!progress.soundEnabled),
                      ),
                    ),
```
Update `test/features/settings_screen_test.dart`: the sound toggle is now `find.bySemanticsLabel('Sound')`; tapping it flips `soundEnabled` (assert via provider state). Keep vibration switch + reset assertions.

- [ ] **Step 3: Out-of-Lives refill/watch-ad**

In `out_of_lives_screen.dart`, replace the disabled `FilledButton('WATCH AD (COMING SOON)')` with a `Row` of two **disabled** image buttons (shown only when `livesNow <= 0`, alongside the existing CONTINUE-when-regenerated `FilledButton`):
```dart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ImageButton(
                        asset: AppImages.watchAddButton,
                        semanticLabel: 'Watch ad (coming soon)',
                        width: 90,
                        onPressed: null,
                      ),
                      const SizedBox(width: 16),
                      ImageButton(
                        asset: AppImages.refillButton,
                        semanticLabel: 'Refill (coming soon)',
                        width: 150,
                        onPressed: null,
                      ),
                    ],
                  ),
```
Update `test/features/out_of_lives_screen_test.dart`: replace `find.widgetWithText(FilledButton, 'WATCH AD (COMING SOON)')` with `find.bySemanticsLabel('Watch ad (coming soon)')`; CONTINUE-when-regenerated assertion unchanged.

- [ ] **Step 4: Timeout dialog RETRY → replaybutton**

In `gameplay_screen.dart` `_showTimeUpDialog`, replace the RETRY `FilledButton` with:
```dart
          ImageButton(
            asset: AppImages.replayButton,
            semanticLabel: 'Retry',
            width: 64,
            height: 64,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
```
keep HOME as the `TextButton`. Update `test/features/gameplay_timer_test.dart` 'timeout ... dialog': assert `find.bySemanticsLabel('Retry')` and `find.text('HOME')` instead of `find.text('RETRY')`.

- [ ] **Step 5: Run the full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues. Fix any remaining finders in `app_flow_test` that referenced the old PLAY `FilledButton` (PLAY is now `find.bySemanticsLabel('Play')`).

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_screen.dart lib/features/settings/settings_screen.dart lib/features/out_of_lives/out_of_lives_screen.dart lib/features/gameplay/gameplay_screen.dart test/features/
git commit -m "feat: swap play/sound/refill/replay buttons to PNG assets"
```

---

## Self-Review

**Spec coverage:** §0 assets → T1. §1.1 AppImages → T1. §1.2 ImageButton → T1. §1.3 HeartsRow → T2. §2 starsForResult → T3. §2.2 wiring → T5. §3 levelStars/v3 → T4. §4.1 Result → T6. §4.2 Home → T7. §4.3 gameplay hearts+timeout → T2/T7 (win-stars T5). §4.4 Out-of-Lives → T7. §4.5 Settings → T7. §5 pubspec → T1. §6 tests → each task. ✓

**Placeholder scan:** No TBD/TODO; code shown for every code step. The Result `Alignment` offsets are explicitly a visual calibration (nudge on-device), not a missing spec. ✓

**Type consistency:** `AppImages.{...,starN(int)}`, `ImageButton({asset,onPressed,width,height,semanticLabel})`, `HeartsRow({lives,size})`, `starsForResult({remaining,timeLimit})`, `PlayerProgress.levelStars`, `completeLevel({levelId,nextLevelId,stars})`, `ResultRouteArgs({levelId,awardedScore,stars})`, `ResultScreen({levelId,awardedScore,stars})` — consistent across tasks. ✓

**Note for the implementer:** Tasks 5 and 6 both touch `ResultScreen`/`ResultRouteArgs`; land them together. Verify on a device/emulator after Task 7 to nudge the board overlay `Alignment` offsets so stars/next sit on the right planks.
