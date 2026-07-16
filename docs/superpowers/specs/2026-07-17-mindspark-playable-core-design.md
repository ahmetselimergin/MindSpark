# MindSpark Playable Core Design

**Date:** 2026-07-17  
**Status:** Approved design, pending written-spec review  
**Target:** Android-first Flutter application using Flame

## 1. Purpose

This specification defines MindSpark's first independently testable vertical slice. It delivers a small set of playable 5×5 Color Connect levels, deterministic puzzle rules, local progress, and the Home → Game → Result loop. It intentionally establishes the architecture before bulk level content, advertising, sound, and advanced effects are added.

The wider MVP is split into three increments:

1. **Playable core:** this specification.
2. **Content and polish:** 200 validated levels, audio, richer animation, settings, and accessibility refinements.
3. **Monetization:** AdMob consent, interstitial/rewarded flows, and a product-defined failure mechanic for lives.

Each increment must remain playable and testable on its own.

## 2. Product Decisions

- Completing a level requires connecting every same-colour endpoint pair.
- Filling every grid cell is not required.
- Paths move only between orthogonally adjacent cells.
- A cell can belong to at most one path, so paths cannot overlap or cross.
- Completing a level awards exactly 100 score points once.
- A completed level unlocks the next level. Replaying a completed level cannot award score again.
- Restarting a level does not consume a life.
- Lives are stored in the future player model but are inactive in the playable core because the supplied rules have no natural failure condition. Monetization will not invent an arbitrary penalty; lives become active only with a separately approved move, time, or attempt constraint.
- The first content set contains at least three hand-authored 5×5 levels used to prove the complete flow.
- The playable core works fully offline and contains no Firebase or AdMob dependency.

## 3. Considered Architectures

### 3.1 Selected: Flutter shell + pure Dart domain + Flame adapter

Flutter owns navigation and screens. A pure Dart domain session owns all puzzle rules and mutable board state. Flame renders domain snapshots, converts pointer positions into grid coordinates, and runs visual effects. Riverpod provides application state and dependencies. Hive persists progress.

This keeps rules testable without a rendering engine, prevents Flame components and Riverpod from becoming competing state authorities, and supports later solver-based level validation.

### 3.2 Rejected: Flame-first component state

Keeping board state inside Flame components makes the prototype quick but distributes rules across the component tree. Headless validation, undo behaviour, persistence events, and generated-level verification become harder to test.

### 3.3 Rejected: Flutter CustomPainter-only board

This puzzle can be implemented with Flutter gestures and `CustomPainter`, but that approach does not honour the selected Flame stack and provides less room for future game effects.

## 4. Architecture and Ownership

### 4.1 Application layer

The application layer creates the `ProviderScope`, initializes storage before exposing dependent screens, and declares named routes for splash, home, gameplay, and result. Route arguments contain stable level identifiers, not mutable game objects.

### 4.2 Domain layer

The domain layer has no Flutter, Flame, Hive, Riverpod, advertising, or analytics imports. It owns:

- Immutable level definitions and endpoint validation.
- Grid positions and colour identifiers.
- Current paths and cell occupancy.
- Gesture commands and their results.
- Completion detection.
- Idempotent completion scoring rules.

`PuzzleSession` is the single authority for an active board. It exposes immutable snapshots after accepted commands. Rendering code never mutates paths directly.

### 4.3 Game adapter

`MindSparkGame` receives a `PuzzleSession` and a completion callback. Flame components render the grid, endpoints, and paths from the current snapshot. Pointer input is converted to a grid position and forwarded to the session.

Only a changed snapshot causes board components to update. Pointer movement does not write to Hive or update application-wide Riverpod state.

### 4.4 Feature and persistence layer

`LevelRepository` loads and validates bundled JSON assets. `ProgressRepository` exposes progress operations independently of Hive. `HiveProgressRepository` is the production implementation and an in-memory repository supports tests.

`AppProgressController` owns unlocked level, completed level identifiers, total score, and settings exposed to Flutter screens. It persists only meaningful application events such as initial load and first-time completion.

## 5. Proposed File Boundaries

```text
lib/
  main.dart
  app/
    app.dart
    routes.dart
  core/
    theme/app_theme.dart
  game/
    mind_spark_game.dart
    components/board_component.dart
    domain/grid_position.dart
    domain/path_state.dart
    domain/puzzle_session.dart
    domain/puzzle_snapshot.dart
  features/
    home/home_screen.dart
    gameplay/gameplay_screen.dart
    result/result_screen.dart
  models/
    level_model.dart
    player_progress.dart
  repositories/
    level_repository.dart
    progress_repository.dart
    asset_level_repository.dart
    hive_progress_repository.dart
  state/
    app_progress_controller.dart
  assets/levels/
    levels.json
```

Files remain focused by responsibility. UI features may add small private widgets in the same feature directory when a screen grows beyond a readable single unit.

## 6. Data Model

### 6.1 Level definition

Each level uses the supplied coordinate convention: `x` increases left-to-right, `y` increases top-to-bottom, and both are zero-based.

```json
{
  "id": 1,
  "size": 5,
  "points": [
    {"x": 0, "y": 0, "color": "red"},
    {"x": 4, "y": 4, "color": "red"}
  ]
}
```

Load-time validation rejects an asset when:

- `id` is not positive or is duplicated.
- `size` is less than 2.
- A point falls outside the board.
- Two points occupy the same coordinate.
- A colour does not have exactly two endpoints.
- The point list is empty.

Invalid bundled content is a developer error. The repository reports a typed load failure and the UI displays a recoverable error screen rather than starting a broken session.

### 6.2 Player progress

The persisted record contains:

- `schemaVersion = 1`
- `highestUnlockedLevel`, initially `1`
- `completedLevelIds`, initially empty
- `totalScore`, initially `0`
- `lives`, initially `3` but inactive in this increment
- sound and vibration preferences, both initially enabled

Progress updates are monotonic: unlocked level and score cannot move backwards. Completing the same level more than once is idempotent.

## 7. Gesture and Path Rules

1. A drag must begin on a coloured endpoint.
2. Beginning a drag for a colour that already has a path replaces that colour's path from the selected endpoint.
3. Movement enters one orthogonally adjacent cell at a time. Diagonal pointer motion is resolved into the sequence of crossed orthogonal cells; skipped cells are never silently accepted.
4. Moving back to the immediately previous cell removes the last segment, enabling natural backtracking.
5. Entering a cell occupied by a different colour is rejected without changing the snapshot.
6. Entering an endpoint of a different colour is rejected.
7. A path becomes connected only when it reaches the matching endpoint.
8. Releasing before reaching the matching endpoint removes the incomplete path.
9. Pointer movement outside the board is ignored; releasing outside follows the same incomplete-path rule.
10. When every colour has a connected path, the session emits completion once.

The board remains editable until completion. On completion, input is disabled before the result callback is emitted, preventing duplicate scoring or navigation.

## 8. Screen Flow

### Splash

The splash displays the MindSpark wordmark and a loading indicator while storage and level assets initialize. Success routes to Home. Initialization failure provides a retry action.

### Home

Home displays the highest unlocked level, total score, and a Play button. Play opens the highest unlocked level. Locked-level selection is outside this increment.

### Gameplay

Gameplay displays the current level number, Flame game board, and Restart button. Restart restores the initial snapshot and does not change progress. Hint, active lives, and advertising controls arrive in later increments.

### Result

Result displays “Level Completed”, the first-time score award, total score, and a Next Level button. Completing the final bundled level returns to Home instead of routing to a missing level.

## 9. Event and Persistence Flow

```text
Pointer input
  → Flame converts screen position to GridPosition
  → PuzzleSession validates and updates the board
  → Flame renders the new immutable snapshot
  → completion event fires once
  → AppProgressController records first-time completion
  → ProgressRepository persists the updated record
  → Flutter navigates to Result
```

If persistence fails after puzzle completion, gameplay remains completed and Result shows a retryable save error. Navigation does not silently claim that progress was saved. Retrying the idempotent completion operation cannot duplicate score.

## 10. Error Handling

- Missing or malformed level assets produce a typed repository error and retryable UI state.
- Corrupt Hive data falls back to a fresh version-1 record after preserving the error for diagnostics; it never creates negative or regressing values.
- Storage write failures remain visible and retryable.
- Unsupported pointer sequences are ignored without throwing.
- Rendering and input do not depend on network availability.
- The game adapts its board size on resize and keeps a square play area within available bounds.

## 11. Testing Strategy

### Pure Dart unit tests

- Level JSON parsing and every validation rule.
- Starting, extending, backtracking, replacing, cancelling, and completing paths.
- Bounds, diagonal/skipped input normalization, occupied-cell rejection, endpoint rejection, and single completion emission.
- Idempotent scoring and monotonic unlock behaviour.
- Corrupt/default progress normalization.

### Widget and game-adapter tests

- Splash initialization success, failure, and retry.
- Home values and navigation.
- Gameplay restart and completion callback integration.
- Result behaviour for next and final bundled levels.
- Screen-to-cell coordinate mapping across representative board sizes.

### End-to-end verification

- Fresh install state opens level 1 with score 0.
- Solving level 1 awards 100, unlocks level 2, persists state, and survives app recreation.
- Replaying level 1 does not add score.
- The app analyzes cleanly, all tests pass, and an Android debug APK builds successfully.

## 12. Acceptance Criteria

The playable core is complete only when:

- The Android app can traverse Splash → Home → Game → Result → next Game.
- At least three valid 5×5 levels are bundled and playable.
- Every gesture rule in Section 7 is covered by automated tests.
- Invalid crossings and endpoint connections are impossible through the public session API.
- First-time completion persists exactly 100 score and unlocks the next level.
- Replay is idempotent.
- The application remains usable offline.
- `flutter analyze`, the full Flutter test suite, and an Android debug APK build all exit successfully.

## 13. Later Increment Constraints

The content increment will generate levels offline with deterministic seeds, retain generated JSON as versioned assets, and validate every level with an independent solver before inclusion. The first 10–20 levels will remain manually curated for onboarding.

The monetization increment will keep advertising behind an `AdsService` interface. Failed or unavailable ads cannot block ordinary play. Rewarded benefits are granted only after the SDK's verified reward callback. Interstitial frequency remains every three newly completed levels, subject to consent and store policy review at implementation time.

