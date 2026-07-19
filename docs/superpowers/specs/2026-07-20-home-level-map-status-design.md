# Home Level Map & Status Badges — Design

**Date:** 2026-07-20
**Status:** Approved (design), pending implementation plan

## Summary

Replace the home screen's single big-number + Play-button layout with a
**horizontal, scrollable level map**: a wavy trail of level cards (completed,
current, locked) connected by a dashed curved path, rendered over the home
background image. Each card is the launcher — tapping the current level plays
it, tapping a completed level replays it, locked cards are inert.

Separately, animate the `assets/ui/Status/{Good,Great,Perfect}.png` images as a
celebratory **StatusBadge** in two places: on the win screen after finishing a
level, and on the just-completed card when the player returns to the map.

## Goals

1. Home shows a horizontal, scrollable level map matching the reference:
   staggered (wavy) cards, dashed curved connectors along the played trail,
   auto-centered on the current level.
2. Three card states driven by existing `PlayerProgress`.
3. `StatusBadge` (Good/Great/Perfect) animates on the win screen and on the
   returning map card, mapped to stars earned.
4. Home background = `assets/ui/background.png`, full-bleed behind the map.

## Non-Goals

- No changes to level generation, scoring, lives, or star-award logic.
- No new persisted state (celebration uses ephemeral in-memory state only).
- No lazy/infinite forward generation of locked levels (fixed teaser count).
- No redesign of the won board, score display, or Next-level flow.

## Existing Context (verified)

- **Endless levels:** `levelByIdProvider = FutureProvider.family<LevelModel,int>`
  in `lib/app/app.dart` generates any level on demand; there is no fixed total.
  `nextLevelId = levelId + 1`.
- **Progress model** (`lib/models/player_progress.dart`) exposes:
  `highestUnlockedLevel`, `completedLevelIds: Set<int>`,
  `levelStars: Map<int,int>` (values clamped 1..3), `lives`, `livesRegenAnchor`.
- **Home today** (`lib/features/home/home_screen.dart`): `SparkTrail` + title +
  `LivesBar` + big current-level number + `ImageButton(playButton)` +
  out-of-lives link, over the default dark theme (no background image). Settings
  icon top-right.
- **Win screen** (`lib/features/result/result_screen.dart`): `wonBoard` image
  with star image (`AppImages.starN`), score text, Next button, Home button.
- **Theme colors** (`lib/core/theme/app_theme.dart`): `sparkYellow #FFD166`
  (current/orange), `electricCyan #4CC9F0` (completed/blue), `frost #F7F8FF`,
  `midnightInk`, `deepCircuit`, `coralPulse`.
- **Assets:** `assets/ui/background.png`, `star.png`, `1star.png`/`2star.png`/
  `3star.png`, `Status/Good.png`, `Status/Great.png`, `Status/Perfect.png`.
- **pubspec:** declares `assets/ui/` (covers `background.png`), but Flutter does
  **not** recurse into subfolders — `assets/ui/Status/` must be added
  explicitly.

## Architecture

New/changed units, each with one clear purpose:

### 1. `LevelCardStatus` + `LevelCard` — `lib/features/home/widgets/level_card.dart`

`enum LevelCardStatus { completed, current, locked }`

`LevelCard` is a pure, stateless-in-inputs widget:

```
LevelCard({
  required int levelId,
  required LevelCardStatus status,
  required int stars,          // 0..3, only meaningful when completed
  required VoidCallback? onTap, // null => not tappable (locked)
})
```

Visuals (fixed nominal size ~92×108 logical px):

- **completed** — filled rounded card, `electricCyan` gradient, white level
  number, a bottom row of 3 stars using `assets/ui/star.png`: earned stars full
  opacity, unearned dimmed. Soft drop shadow.
- **current** — filled `sparkYellow` gradient card, white number, subtle
  looping pulse (scale ~1.0↔1.04) to draw the eye. No star row.
- **locked** — transparent fill, white (`frost`) outline border, dimmed number,
  no stars, no shadow. `onTap == null`.

The card owns only presentation + the pulse animation. It does not read
providers; state is passed in.

### 2. `LevelPathPainter` — same file or `level_path_painter.dart`

`CustomPainter` that draws dashed quadratic-bezier connectors between
consecutive card **centers**. Given deterministic layout (below), the painter
receives the list of card center `Offset`s and their statuses and draws a
connector between card *i* and *i+1* only when both endpoints are on the played
trail (both `completed`, or `completed`→`current`). Locked segments get no
connector (reference: no dashes past the current level). Dash style: white
(`frost`) at ~70% opacity, rounded caps, ~6px dash / ~6px gap, stroke ~3px.

`shouldRepaint` compares the centers list + status list.

### 3. `LevelMapView` — `lib/features/home/widgets/level_map_view.dart`

`ConsumerStatefulWidget`. Responsibilities:

- Watch `appProgressControllerProvider` for `highestUnlockedLevel`,
  `completedLevelIds`, `levelStars`; watch `celebrateLevelProvider`.
- Build the id range: `1 .. highestUnlockedLevel + kLockedTeaser` where
  `kLockedTeaser = 5`. Map each id to a status:
  - `id > highestUnlockedLevel` → `locked`
  - `id == highestUnlockedLevel` → `current`
  - else (`id < highestUnlockedLevel`) → `completed` (stars = `levelStars[id] ?? 0`)
- Lay out with **deterministic positions**: horizontal step `kStep`
  (cardWidth + gap), vertical stagger alternating by index (even → up, odd →
  down) with amplitude `kAmplitude`. Content width = `count * kStep + padding`;
  height = cardHeight + 2*kAmplitude + starRow + margins.
- Compose a `SizedBox(width: contentWidth)` containing a `Stack`:
  `CustomPaint(painter: LevelPathPainter(centers, statuses))` sized to fill,
  then each `LevelCard` in a `Positioned` at its computed offset.
- Wrap the Stack in a horizontal `SingleChildScrollView` with a
  `ScrollController`. On first layout (`addPostFrameCallback`), jump/animate so
  the current level is centered.
- Card `onTap`:
  - `current`: if `livesNow > 0` → play `levelId`; else route to
    `AppRoutes.outOfLives` with `OutOfLivesRouteArgs(levelId)`.
  - `completed`: play `levelId` (replay); gated by the same lives check.
  - `locked`: `null`.
  - "Play" = `Navigator.pushNamed(AppRoutes.gameplay, GameplayRouteArgs(id))`,
    reusing the existing `_openingGame` guard pattern (single-flight).
- Celebration: if `celebrateLevelProvider` holds an id present in the visible
  range, that card overlays a `StatusBadge` (smaller scale) once, then the view
  clears the provider (`ref.read(...).state = null`) after the animation.

`livesNow` is computed via `LivesRegen.reconcile` exactly as the current home
screen does.

### 4. `StatusBadge` — `lib/core/widgets/status_badge.dart`

Reusable animated widget:

```
StatusBadge({
  required int stars,     // 1..3 -> Good/Great/Perfect
  double? width,
  bool autoPlay = true,
})
```

- Picks asset via `AppImages.statusForStars(stars)`.
- Entrance animation: scale-in with overshoot (`Curves.elasticOut` or a
  back-out tween) + fade, ~450ms, plays once on mount when `autoPlay`.
- No provider access; purely driven by inputs.

### 5. `celebrateLevelProvider` — in `lib/state/app_progress_controller.dart`

`final celebrateLevelProvider = StateProvider<int?>((ref) => null);`

- Ephemeral, in-memory, not persisted.
- **Set** on successful completion where the game currently calls
  `completeLevel(...)` (gameplay flow) — set to the completed `levelId`.
- **Consumed & cleared** by `LevelMapView` after playing the card burst.
- Most-recent-wins semantics (single int, not a queue). Playing several levels
  via "Next" before returning home celebrates only the latest.

### 6. Home screen — `lib/features/home/home_screen.dart`

- Add full-bleed `Image.asset(AppImages.background, fit: BoxFit.cover)` as the
  bottom layer of the existing `Stack` (behind content and the settings button).
- Keep: title `MindSpark`, `LivesBar`, settings icon (top-right).
- Remove the big current-level number, "Level N" text, Best-Score text, the
  `ImageButton(playButton)` block, and the out-of-lives `TextButton` (that route
  is now reached by tapping the current card with 0 lives).
- Insert `LevelMapView` as the primary content region (vertically centered,
  horizontal scroll). `SparkTrail` may stay above the title (optional; keep for
  continuity).
- Preserve existing error/loading handling (`_HomeContentError`, spinner while
  progress is loading). The map derives ids from `PlayerProgress` alone, so the
  `levelByIdProvider(highestUnlockedLevel)` dependency and its `currentLevel ==
  null` spinner are no longer needed and are removed.

### 7. Win screen — `lib/features/result/result_screen.dart`

- Overlay a `StatusBadge(stars: widget.stars)` centered near the top of the
  board `Stack`, animating in on entry, layered above the won board. Existing
  star image, score, Next, and Home remain unchanged.

### 8. `AppImages` additions — `lib/core/theme/app_images.dart`

```
static const String background = 'assets/ui/background.png';
static const String statusGood = 'assets/ui/Status/Good.png';
static const String statusGreat = 'assets/ui/Status/Great.png';
static const String statusPerfect = 'assets/ui/Status/Perfect.png';
static String statusForStars(int stars) => switch (stars) {
  <= 1 => statusGood,
  2 => statusGreat,
  _ => statusPerfect,
};
```

### 9. pubspec — `pubspec.yaml`

Add `- assets/ui/Status/` under `flutter: assets:` (subfolder not auto-included).

## Data Flow

```
PlayerProgress (highestUnlockedLevel, completedLevelIds, levelStars, lives)
        │  watch
        ▼
   LevelMapView ──build ids 1..highest+5──► [LevelCard × n] + LevelPathPainter
        │  onTap(current/completed)                       ▲
        ▼                                                 │ celebrate id
  Navigator → GameplayScreen ──win──► completeLevel()     │
        │                              set celebrateLevelProvider
        ▼                                                 │
  ResultScreen shows StatusBadge(stars)                   │
        │ Home button                                     │
        ▼                                                 │
  HomeScreen → LevelMapView reads celebrateLevelProvider ─┘
        └─ plays StatusBadge burst on that card, then clears provider
```

## Error / Edge Handling

- **Progress load error/loading:** keep the existing `AsyncValue` guards; show
  `_HomeContentError` on error, spinner while loading.
- **0 lives:** current/completed card tap routes to Out-of-Lives instead of
  gameplay (no silent no-op).
- **Double-tap / rapid taps:** single-flight guard (`_openingGame`) as today.
- **Celebrate id not in visible range** (e.g. very high replay): no-op, clear
  the flag anyway to avoid a stuck badge.
- **Missing/failed asset load:** `Image.asset` shows Flutter's default broken
  state; not specially handled (assets are bundled).
- **Very large `highestUnlockedLevel`:** `ListView`/`SingleChildScrollView`
  content is O(n) widgets; acceptable for expected level counts. (Revisit with a
  `ListView.builder` windowing only if profiling shows a problem — out of scope.)

## Testing

Widget tests in the existing `flutter_test` style, using a fake/in-memory
progress repository overridden via Riverpod `ProviderScope` overrides:

- `LevelCard`: renders number for each status; completed shows star row with
  correct earned/dim counts; locked has no `onTap` (not tappable); current
  pulses (animation present).
- `LevelMapView`: given progress (e.g. highest=10, completed 1..9 with stars),
  renders completed 1..9, current 10, locked 11..15; taps on current →
  gameplay route with correct args; tap on completed → gameplay (replay); tap on
  locked → no navigation; with 0 lives, current tap → out-of-lives route.
- `LevelPathPainter`: connector count equals played-trail segments (unit-style
  check on the painter's derived segment list, or a golden/paint smoke test).
- `StatusBadge`: `statusForStars` mapping (1→Good, 2→Great, 3→Perfect); badge
  image present after mount; animation controller advances.
- `ResultScreen`: shows a `StatusBadge` with the awarded stars.
- Celebration: setting `celebrateLevelProvider` before pumping Home shows the
  badge on that card and the provider is cleared afterward.

## Open Questions

None — approach A (staggered + dashed curves), tap-to-play cards, and the
ephemeral celebration provider were confirmed during brainstorming.
