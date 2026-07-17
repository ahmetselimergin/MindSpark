# MindSpark Progression and UI Refresh Design

**Date:** 2026-07-17  
**Status:** Approved through delegated product authority  
**Scope:** Fix end-of-content repetition, expand the playable set to 12 levels, and redesign Home, Gameplay, and Result.

## 1. Root Cause

The bundled repository contains only levels 1–3. Completing level 3 passes no `nextLevelId`, so progress correctly leaves `highestUnlockedLevel` at 3 and Result returns Home. Home always treats `highestUnlockedLevel` as the current playable level, even when every bundled level is already completed. Pressing Play therefore silently opens level 3 again.

The defect is not a navigation race. It is a missing end-of-content state combined with too little content.

## 2. Product Decisions

- Bundle 12 sequential, hand-authored 5×5 levels.
- Every bundled level must have a canonical solution exercised through `PuzzleSession` in tests.
- Home uses the highest unlocked level while unfinished content remains.
- When every bundled level ID is completed, Home shows an explicit “All levels cleared” state.
- The completed state never labels the final level as the next level.
- Replay remains available only through an explicit “Replay from start” action that opens level 1.
- Completing level 3 routes to level 4. Completing level 12 routes to the completed Home state.
- Full-grid coverage remains optional; all same-colour pairs must connect without overlap.

## 3. Visual Direction: Arcade Blueprint

The current screen has a bright white board, plain text controls, and large unstructured empty areas. The refresh uses the puzzle itself as the visual language: a dark drafting surface, luminous connection paths, compact instrument-like status elements, and subtle circuit traces.

### Palette

- `Void Navy #080D1C`: app background.
- `Panel Navy #111A2E`: cards and board cells.
- `Grid Blue #263653`: grid and outlines.
- `Spark Cyan #62E6FF`: primary connection accent.
- `Pulse Yellow #FFD76A`: primary action and progress.
- `Signal Coral #FF6B81`: errors and destructive emphasis.
- `Mint #6EE7A8`: success.
- `Cloud #F4F7FF`: primary text.

### Typography

- Display and level numerals: Android system `sans-serif`, weight 800, tight tracking, tabular figures.
- Body and controls: Android system `sans-serif`, weights 500–700.
- The existing condensed face is removed because it reads as a debug/game-template default in the supplied screenshot.

### Signature

A reusable circuit backdrop draws a small number of low-contrast orthogonal traces and nodes. The signature is quiet; the luminous puzzle paths remain the only high-energy element.

## 4. Screen Designs

### Home

```text
┌─────────────────────────────┐
│ MindSpark          12 LEVELS│
│                             │
│       ╭────────────╮        │
│       │   03 / 12  │        │
│       │ NEXT SPARK │        │
│       ╰────────────╯        │
│      2 levels cleared       │
│                             │
│       [ CONTINUE ]          │
└─────────────────────────────┘
```

The current level is shown inside a progress ring/card instead of an isolated oversized number. After all levels are complete, the center reads “All levels cleared” and the action becomes “Replay from start.”

### Gameplay

```text
┌─────────────────────────────┐
│ ‹  LEVEL 03        ↻        │
│    3 / 12 · 3 pairs         │
│                             │
│ ╭─────────────────────────╮ │
│ │  dark blueprint board   │ │
│ │  luminous endpoints     │ │
│ ╰─────────────────────────╯ │
│ Connect every matching pair │
└─────────────────────────────┘
```

The header uses icon controls, level position, and pair count. The instruction sits directly below the board. The board uses dark cells, subtle dots/grid lines, coloured glow paths, and ring endpoints with non-colour symbols.

### Result

Result shows a mint success node, earned score, persisted total, completion progress, and a single next action. On level 12 the action is “View collection,” leading to the completed Home state.

## 5. Architecture

- `PlayerProgress` scoring and unlock semantics remain unchanged.
- Home derives `allLevelsCompleted` from the bundled level IDs and `completedLevelIds`; no new persisted flag is introduced.
- Level content remains static JSON and offline.
- Canonical solutions exist only in tests, not release assets.
- Flame continues to own board painting and input adaptation; screen widgets do not duplicate path rules.
- `CircuitBackdrop` and small UI primitives live in `core/widgets` and contain no game state.

## 6. Testing

- Regression: completing the final repository level returns Home in the explicit completed state; Play cannot silently reopen the final level.
- Explicit replay opens the first level.
- Asset repository loads exactly IDs 1–12.
- Canonical paths solve every bundled level through the public `PuzzleSession` API.
- Level 3 completion opens level 4.
- Home/Game/Result keep their new hierarchy at 320×568 and 2× text scaling.
- Renderer pixel smoke test proves the board is dark rather than white.
- A captured emulator or widget-render image is inspected before completion.

## 7. Non-Goals

- Runtime procedural generation.
- Level selection grid, hints, lives, ads, audio, or Firebase.
- Remote fonts or network-loaded assets.
- Changing puzzle completion rules.

