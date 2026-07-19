<!--
Design document (no code imports it). No existing spec covers UI asset integration.
User approved this design in-session ("evet"). Builds on the arcade lives + timer
feature (2026-07-18-arcade-lives-timer-design.md).
-->

# UI Asset Integration + Star Rating — Design

**Date:** 2026-07-19
**Status:** Approved (design)
**Scope:** Integrate the custom cartoon PNG assets in `assets/ui/` consistently across
every screen (buttons, hearts, the win board), add a time-based **1–3 star rating** shown
on a redesigned win screen, and **persist each level's best star count** (schema v2 → v3).
The dark background and existing screen layouts are kept; only the specific widgets that
these assets cover are swapped.

## 0. Assets (in `assets/ui/`, not yet declared in pubspec)

| File | Look | Used for |
|---|---|---|
| `playbutton.png` | green pill, baked "Play" | Home PLAY |
| `nextbutton.png` | green pill, baked "Next" | Result → next level |
| `heart.png` | glossy red heart | lives everywhere |
| `replaybutton.png` | round blue, replay arrow | timeout RETRY |
| `refillbutton.png` | blue pill, baked "Refill" | Out-of-Lives (deferred) |
| `watchaddbutton.png` | small purple, video icon | Out-of-Lives watch-ad (deferred) |
| `soundbutton.png` | round green, speaker | Settings sound toggle |
| `wonboard.png` | blank wooden "YOU WON" board | Result panel |
| `1star.png` / `2star.png` / `3star.png` | 3-star row with N gold | Result star overlay |

The button PNGs carry their own baked labels — no text overlay. The star PNGs are the full
three-star row (N filled gold), overlaid on the blank `wonboard.png`.

## 1. Shared pieces

### 1.1 `AppImages` (new `lib/core/theme/app_images.dart`)
- `abstract final class AppImages` with `static const String` paths (e.g. `playButton =
  'assets/ui/playbutton.png'`). Single source for asset paths.

### 1.2 `ImageButton` (new `lib/core/widgets/image_button.dart`)
- `ImageButton({required String asset, required VoidCallback? onPressed, double? width,
  double? height, String? semanticLabel})`.
- Renders `Image.asset(asset)` in a `GestureDetector`; brief press-down scale (~0.94) for
  tactile feedback; when `onPressed == null` it shows at reduced opacity and ignores taps.
- `Semantics(button: true, label: semanticLabel)` for testability/a11y (widget tests find by
  label). Used by play/next/refill/watch-ad/replay/sound.

### 1.3 Hearts (`lib/core/widgets/lives_bar.dart`, updated)
- Replace the `Icon(Icons.favorite/…)` row with `heart.png`: render `LivesRegen.maxLives`
  hearts, filled at full opacity, empty at ~0.25 opacity (no empty-heart asset exists).
- A small reusable `HeartsRow({required int lives, double size})` extracted so Home,
  gameplay, and Out-of-Lives share one heart renderer. `LivesBar` composes `HeartsRow` +
  the "next life" countdown text.

## 2. Star rating (domain, pure)

### 2.1 `starsForResult` (new addition in `lib/game/generation/level_timer.dart`, pure)
- `int starsForResult({required Duration remaining, required Duration timeLimit})`:
  ratio = `timeLimit.inMilliseconds <= 0 ? 0 : remaining / timeLimit` (clamped 0..1);
  `ratio >= 0.7 → 3`, `>= 0.4 → 2`, else `1`. Always 1..3 (finishing earns at least one).

### 2.2 Wiring
- Gameplay owns `_remaining` and `_timeLimit`. On win, `_handleCompletion` computes
  `stars = starsForResult(remaining: _remaining, timeLimit: _timeLimit)` **before** any
  reset, records it, and passes it to the Result route.

## 3. Star persistence (`PlayerProgress`, schema v2 → v3)

- Add `levelStars` — an unmodifiable `Map<int,int>` (levelId → best stars, 1..3).
- `completeLevel` gains an optional `int? stars`: on a win it stores
  `levelStars[levelId] = max(existing, stars)` (clamped 1..3), atomically with the existing
  completion/score update. `stars == null` leaves the map unchanged.
- `PlayerProgress.initial()` → empty `levelStars`.
- `copyWith`/`copyWithLives`/equality/hashCode thread `levelStars`.
- **Schema v2 → v3 migration** in `fromPersistedMap`: accept `schemaVersion` 1, 2, or 3.
  - v3: read `levelStars` (map of positive-int keys → 1..3 values; keys must be in
    `completedLevelIds`).
  - v1/v2: `levelStars` starts empty (progress otherwise preserved as today; v1 still refills
    lives to `LivesRegen.maxLives`).
  - Reject unsupported versions and malformed `levelStars` (non-map, bad key/value, key not
    completed) via `ProgressFormatException`.
- `toMap()` writes `schemaVersion: 3` and `levelStars`. Keys serialize as ints; the parser
  accepts both int and numeric-string keys defensively (Hive/JSON round-trips).
- Controller: `completeLevel` call sites pass `stars`; no new public method needed.

## 4. Screens

### 4.1 Result / win (`lib/features/result/result_screen.dart`, redesigned)
- `ResultRouteArgs` gains `stars` (1..3). `app.dart` route guard validates `1 <= stars <= 3`.
- Layout: dark scaffold; centered `Stack` sized to `wonboard.png` (fit within safe area,
  scale down on small screens). Overlays, positioned by fractional alignment on the board:
  - the matching `${stars}star.png` in the upper star region;
  - a small score line ("+N" award and total) on a middle plank;
  - `nextbutton.png` (`ImageButton`) on the lower plank → next level (existing next flow);
  - a small **home** `IconButton` (top-left corner of the board) → Home.
- Keeps the existing next-level id / navigation logic; only the presentation changes.

### 4.2 Home (`lib/features/home/home_screen.dart`)
- PLAY → `playbutton.png` via `ImageButton` (disabled/dimmed at 0 lives, with the existing
  Out-of-Lives shortcut). Lives via the updated `HeartsRow`. Settings gear unchanged.

### 4.3 Gameplay (`lib/features/gameplay/gameplay_screen.dart`)
- Header hearts → `HeartsRow` (heart.png), sized small. Countdown + bar unchanged.
- Timeout dialog: RETRY → `replaybutton.png` (`ImageButton`); HOME → a home `IconButton`.
- On win, compute + pass `stars` (see §2.2).

### 4.4 Out-of-Lives (`lib/features/out_of_lives/out_of_lives_screen.dart`)
- Hearts → `HeartsRow`. Deferred refill row: `watchaddbutton.png` and `refillbutton.png`
  shown **disabled** (dimmed) — no ad SDK. Continue-when-regenerated and Main Menu
  (home icon) unchanged in behavior.

### 4.5 Settings (`lib/features/settings/settings_screen.dart`)
- Sound toggle → `soundbutton.png` (`ImageButton`): tapping flips `soundEnabled`; the muted
  state is shown dimmed (~0.4 opacity). Vibration stays a `SwitchListTile`; reset unchanged.

## 5. pubspec

- Add under `flutter: assets:`:
  ```
    - assets/ui/
  ```

## 6. Testing

**Pure unit:**
- `starsForResult`: 3/2/1 at ratio boundaries (0.7, 0.4), full time → 3, no time / zero limit
  → 1, clamps out-of-range.
- `PlayerProgress`: v2→v3 and v1→v3 migration (empty `levelStars`, progress preserved); v3
  round-trips `levelStars`; validation rejects bad values / uncompleted keys; `completeLevel`
  with `stars` keeps the max and is atomic with score/unlock.

**Controller:**
- `completeLevel(..., stars: n)` persists `levelStars`; a lower later score does not lower the
  stored best.

**Widget:**
- `ImageButton`: taps fire `onPressed`; disabled (`onPressed == null`) ignores taps and dims.
- Home: PLAY renders `playbutton.png` and navigates; hearts render `heart.png` (filled/empty
  by opacity count).
- Result: the correct `${stars}star.png` appears; `nextbutton.png` navigates to the next
  level; home icon returns Home. Update the existing `app_flow_test` result assertions (text
  → image finders / semantic labels), preserving behavioral checks.
- Gameplay timeout dialog shows the replay button; Out-of-Lives shows disabled refill/watch-ad.

## 7. Out of scope (YAGNI)

- No level-select screen (best-stars are stored now for a future one).
- No ad SDK / real refill; watch-ad and refill remain disabled placeholders.
- No restyle of the dark background, the Flame board, or the splash; no vibration/haptics.
- No animation of stars beyond the existing button press feedback.
