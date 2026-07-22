# Current Progression and Gameplay UI Fix

**Date:** 2026-07-22
**Scope:** Fix legacy progress on the current endless architecture and refresh only the gameplay visual layer.

## Current architecture

- Levels 1–10 are curated; level 11 onward is deterministic procedural content.
- Gameplay always unlocks `levelId + 1`; there is no end-of-content state.
- Home uses a horizontal level map. Gameplay owns timer, lives, restart/home image buttons, stuck feedback, and a Yandex banner slot.

## Progression defect

Finite-era saves may contain `highestUnlockedLevel: 3` with completed IDs `{1,2,3}`. The current level map treats the stored pointer as current and reopens Level 3 once after upgrade.

Normalize loaded progress at the state boundary: while the stored current ID is completed, advance to the next positive ID. Endless generation guarantees the next level exists. Keep persistence schema, score, stars, lives, and settings unchanged. Home, Gameplay, and every consumer receive the same normalized state.

## Gameplay visual refresh

- Keep the current Home map, Result assets, timer, lives, image controls, stuck hint, banner, and procedural level source.
- Replace the white Flame board with alternating navy cells, restrained grid/dots, glow paths, and ring endpoints with white symbols.
- Remove the condensed debug-style font in favor of the system sans-serif.
- Add a static circuit backdrop to Gameplay and place the instruction directly below the board.
- Preserve a square board, input geometry, game lifecycle, and ad reservation.
- Verify 320×568 at 2× text scale and inspect a Pixel 10 Pro render.

## Acceptance

- Legacy `{1,2,3}/highest=3` exposes and authorizes Level 4 immediately.
- Fresh 1→2 and endless progression through generated levels remain unchanged.
- Locked future routes remain rejected.
- An empty board cell renders dark; endpoint/path smoke tests remain valid.
- Analyzer, full test suite, Android debug build, diff check, and emulator inspection pass.
