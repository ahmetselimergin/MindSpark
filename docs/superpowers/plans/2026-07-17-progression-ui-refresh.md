# MindSpark Progression and UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop silent final-level repetition, expand the offline game to 12 solved levels, and replace the sparse white-board interface with a polished arcade-blueprint UI.

**Architecture:** Progress completion is derived from existing immutable level IDs and `PlayerProgress.completedLevelIds`; no persistence migration is needed. Static JSON supplies 12 levels, pure Dart tests prove canonical solvability, Flame paints the board, and Flutter feature screens compose the redesigned shell.

**Tech Stack:** Flutter 3.44.5, Dart 3.12.2, Flame 1.37.0, Riverpod 3.3.2, Hive CE 2.19.3, flutter_test

## Global Constraints

- Remain Android-first and fully offline.
- Bundle exactly 12 sequential 5×5 levels with IDs 1–12.
- Full-grid coverage is not required.
- Completing all content must show an explicit completed state; it must not silently reopen level 12.
- Explicit replay opens level 1 without resetting score or completion history.
- Do not change scoring, persistence schema, path legality, or Flame gesture semantics.
- Use only system fonts and existing dependencies.
- Preserve 320×568 at 2× text-scale support.
- Follow RED → GREEN → refactor for every behavior change.

---

### Task 1: Progression regression and 12 solved levels

**Files:**
- Modify: `assets/levels/levels.json`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/result/result_screen.dart`
- Modify: `test/features/app_flow_test.dart`
- Modify: `test/repositories/asset_level_repository_test.dart`
- Create: `test/assets/bundled_levels_test.dart`

**Interfaces:**
- Consumes: `levelsProvider`, `PlayerProgress.completedLevelIds`, `PuzzleSession`.
- Produces: explicit completed Home state and `REPLAY FROM START` action.

- [ ] **Step 1: Add the failing final-content regression**

Extend the existing final-level widget test:

```dart
expect(find.text('ALL LEVELS CLEARED'), findsOneWidget);
expect(find.text('CONTINUE'), findsNothing);
expect(find.text('REPLAY FROM START'), findsOneWidget);
await tester.tap(find.text('REPLAY FROM START'));
await _pumpRoute(tester);
expect(find.text('LEVEL 01'), findsOneWidget);
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/app_flow_test.dart --plain-name 'finishing the final repository level shows completed home state'`

Expected: FAIL because Home still displays Play for the final level.

- [ ] **Step 3: Implement explicit completion state**

In Home derive:

```dart
final allLevelsCompleted = levels.every(
  (level) => progress.completedLevelIds.contains(level.id),
);
final targetLevel = allLevelsCompleted ? levels.first : levels[currentLevelIndex];
```

Render `ALL LEVELS CLEARED` and `REPLAY FROM START` only when complete. Keep ordinary unfinished copy as `CONTINUE`.

- [ ] **Step 4: Add level-content and solvability tests**

The asset test must assert:

```dart
expect(levels.map((level) => level.id), List.generate(12, (index) => index + 1));
expect(levels.every((level) => level.size == 5), isTrue);
```

`bundled_levels_test.dart` must load real JSON, create one `PuzzleSession` per level, replay a canonical list of orthogonally adjacent cells per colour, call `endPath`, and assert `session.isComplete` for all 12 IDs.

- [ ] **Step 5: Verify level 3 advances to level 4**

Add a repository-order widget/integration assertion using real sequential IDs:

```dart
expect(find.text('LEVEL 04'), findsOneWidget);
```

- [ ] **Step 6: Run GREEN and commit**

Run:

```bash
flutter test test/features/app_flow_test.dart test/repositories/asset_level_repository_test.dart test/assets/bundled_levels_test.dart
flutter analyze
git add assets/levels/levels.json lib/features/home/home_screen.dart lib/features/result/result_screen.dart test
git commit -m "fix: advance beyond the final starter level"
```

Expected: focused tests and analyzer exit 0.

---

### Task 2: Arcade-blueprint board renderer and design system

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Create: `lib/core/widgets/circuit_backdrop.dart`
- Modify: `lib/game/mind_spark_game.dart`
- Modify: `test/game/mind_spark_game_test.dart`

**Interfaces:**
- Produces: `CircuitBackdrop({required Widget child})` and the existing unchanged `MindSparkGame` public API.

- [ ] **Step 1: Add a failing dark-board pixel test**

Render a 100×100 board to an image and inspect a cell away from endpoints/lines:

```dart
final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
expect(_pixelAt(byteData!, image.width, 50, 50), isNot(const Color(0xFFF8FAFC)));
```

Also assert endpoint and path render calls remain exception-free.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/game/mind_spark_game_test.dart --plain-name 'renders a dark blueprint board'`

Expected: FAIL because the current board pixel is near-white.

- [ ] **Step 3: Implement the renderer**

Use exact tokens:

```dart
static const board = Color(0xFF111A2E);
static const alternateCell = Color(0xFF0E1628);
static const grid = Color(0xFF263653);
```

Draw alternating dark cells, low-contrast center dots, grid and border, then a wide translucent path glow followed by the narrower core path. Endpoints use glow → dark fill → coloured ring → white symbol.

- [ ] **Step 4: Implement the shared backdrop/theme**

`CircuitBackdrop` uses one `CustomPainter` with no animation or state. Update theme background, surfaces, button shapes, typography, and icon theme using the design spec tokens. Remove `sans-serif-condensed`.

- [ ] **Step 5: Verify and commit**

Run:

```bash
flutter test test/game/mind_spark_game_test.dart
flutter analyze
git add lib/core lib/game/mind_spark_game.dart test/game/mind_spark_game_test.dart
git commit -m "feat: render the arcade blueprint board"
```

Expected: renderer tests and analyzer exit 0.

---

### Task 3: Redesign Home, Gameplay, and Result

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/gameplay/gameplay_screen.dart`
- Modify: `lib/features/result/result_screen.dart`
- Modify: `lib/features/splash/splash_screen.dart`
- Modify: `test/features/app_flow_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `CircuitBackdrop`, existing providers, existing `MindSparkGame`.
- Produces: semantic copy `CONTINUE`, `LEVEL NN`, `N / 12`, `N PAIRS`, `ALL LEVELS CLEARED`, `REPLAY FROM START`.

- [ ] **Step 1: Write failing hierarchy tests**

Add widget assertions:

```dart
expect(find.text('LEVEL 01'), findsOneWidget);
expect(find.text('1 / 12'), findsOneWidget);
expect(find.text('3 PAIRS'), findsOneWidget);
expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
expect(find.text('RESTART'), findsNothing);
```

Home must display `0 / 12 CLEARED` and `CONTINUE`. Result must display completion progress and one dominant action.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/app_flow_test.dart test/widget_test.dart`

Expected: FAIL on the new semantic copy and restart icon.

- [ ] **Step 3: Implement the screen composition**

Wrap screens in `CircuitBackdrop`. Gameplay passes the level index, total count, and distinct colour count into its view. Replace text restart with a tooltip-labelled `IconButton(Icons.refresh_rounded)`. Put instructions immediately below the board. Preserve save-error controls and all navigation guards.

- [ ] **Step 4: Re-run compact layout tests**

Keep the existing 320×568, text scale 2 tests and assert `tester.takeException()` is null for all refreshed screens.

- [ ] **Step 5: Capture and inspect a real visual**

Prefer an available Android emulator. If none is available, render the Gameplay widget at 412×915 in a test-only capture and write `/tmp/mindspark-gameplay-refresh.png`. Inspect the image for hierarchy, clipping, board contrast, and empty-space balance before completion.

- [ ] **Step 6: Run full verification and commit**

Run:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
git diff --check
git add lib test tasks README.md
git commit -m "feat: redesign MindSpark game screens"
```

Expected: analyzer clean, all tests pass, APK build exits 0, and the working tree is clean.
