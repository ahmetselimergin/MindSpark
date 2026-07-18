<!--
Called by: no code — this is a design document referenced by humans and the
forthcoming implementation plan (docs/superpowers/plans/).
No existing spec covers procedural generation (existing ones: playable-core,
progression-ui-refresh). This doc reads/writes no data files. No date fields
beyond the header date (2026-07-18).
User instruction: "onaylıyorum , daha sonrasında anasayfa play,settings tuşları
kaldığımız bölüm numarası felan gçsterilmesi gerekecek.bölümlere timer da eklenmeli"
-->

# MindSpark Endless Procedural Level System — Design

**Date:** 2026-07-18
**Status:** Approved (design)
**Scope:** Add deterministic, guaranteed-solvable procedural level generation from level 11 onward, keeping levels 1–10 hand-authored. Refactor the level-fetching layer from a finite list to on-demand fetch-by-id. Later phases (Home/Settings redesign, per-level timer) captured but not implemented here.

## 1. Goals & Product Decisions

- **Endless play.** Levels beyond the curated set are generated on demand, so the game never runs out.
- **Deterministic.** Level `N` always yields the same puzzle (seeded by the level number). The existing progression/save model (`highestUnlockedLevel`, `completedLevelIds`, `totalScore`) works unchanged.
- **Curated intro preserved.** Levels 1–10 remain hand-authored in `assets/levels/levels.json`. The generator serves ids `> 10`.
- **Guaranteed solvable.** Every generated puzzle is winnable under the game rule "connect every colour's two endpoints without crossing".
- **Difficulty ramps then plateaus.** Board size and colour count grow gradually, then hold at a dense-but-fair ceiling forever.

## 2. Architecture (Approach A)

Introduce a level-source abstraction and refactor consumers away from a materialized list (an endless list cannot be materialized).

- **`LevelSource`** — interface: `Future<LevelModel> levelById(int id)`.
- **`CompositeLevelSource`** implements `LevelSource`:
  - `id <= curatedMax` (10) → delegate to the existing `AssetLevelRepository.levelById` (JSON, unchanged).
  - `id > curatedMax` → `ProceduralLevelGenerator.generate(id)`.
- **`ProceduralLevelGenerator`** — pure, deterministic: derives difficulty params from `id`, generates with `Random(id)` (plus a fixed salt), returns a `LevelModel`.

### Provider refactor

- Replace `levelsProvider` (`FutureProvider<List<LevelModel>>`) with
  `levelByIdProvider = FutureProvider.family<LevelModel, int>((ref, id) => source.levelById(id))`.
- **Home** reads `levelByIdProvider(progress.highestUnlockedLevel)` (single level).
- **Gameplay** reads `levelByIdProvider(widget.levelId)`; `nextLevelId = widget.levelId + 1` (always defined).
- **Result** computes `nextLevelId = levelId + 1` (always) → the primary button is always "NEXT LEVEL".
- **Splash** preloads the current level via `levelByIdProvider(highestUnlockedLevel)` instead of the whole list.
- The finite "all levels cleared" end-state assumption is removed. Consumers no longer index into a whole-list; they compute the next id arithmetically.

## 3. Generation Algorithm (solvability guarantee)

Dart port of the full-cover tiling method already prototyped and verified for the levels 4–10 batch:

1. Partition the `size × size` grid into `k` simple orthogonal paths that together cover every cell.
2. Each path's two ends become one colour's endpoints; the path body is that colour's cells.
3. Because the partition is itself a legal simultaneous solution (each colour on its own vertex-disjoint path, never crossing another path or stepping on another colour's endpoint), the derived puzzle is **guaranteed winnable by construction**.

Balance & termination:

- Path lengths are bounded to `[min_len, ~1.6 × avg]` so no single colour dominates the board.
- Generation uses a seeded PRNG and a bounded attempt budget. **Determinism + guaranteed success:** if the target params fail within the budget, params are relaxed deterministically (`min_len`↓, then `colors`↓) until a cover is found. Because the seed is fixed, the relaxed result is still reproducible.
- The generator exposes the witness cover (solution) so tests can replay it through the real engine.

## 4. Difficulty Curve

For `L >= 11`, let `t = L - 11`:

Difficulty is a function of three monotone, capped formulas:

- `size = min(8, 5 + t ~/ 8)`
- `colors = min(6, 4 + t ~/ 8)`
- `minLen = min(6, 3 + t ~/ 12)`

Evaluated into constant-parameter bands (each row is exactly what the formulas produce):

| Range | Board | Colours | Min path |
|-------|-------|---------|----------|
| L11–18 | 5×5 | 4 | 3 |
| L19–22 | 6×6 | 5 | 3 |
| L23–26 | 6×6 | 5 | 4 |
| L27–34 | 7×7 | 6 | 4 |
| L35–46 | 8×8 | 6 | 5 |
| **L47+ (plateau)** | **8×8** | **6** | **6** |

Feasibility holds throughout (e.g. plateau `6 colours × minLen 6 = 36 cells ≤ 64`). After the plateau, params are constant and only the seed changes, yielding endless fresh dense 8×8 puzzles. Colour count is capped at 6 by the render palette (`red, blue, green, yellow, purple, orange`).

## 5. Progression & UI (this phase)

- **Home** is visually unchanged for now: current level number + PLAY. (Full redesign is Phase 2, below.)
- **Result:** primary "NEXT LEVEL" always; **add** a secondary "HOME" exit so a player can stop an endless run.
- **Gameplay:** add a small exit-to-Home control in the top bar next to RESTART, so a player can leave mid-level.
- **Scoring unchanged:** first completion of a level awards +100; replay awards +0 ("Already collected").

## 6. Testing Strategy

1. **Determinism:** `generate(id)` twice → identical `LevelModel` (same coords/colours/order).
2. **Structural validity:** generated levels for ids 11–200 satisfy `LevelModel` rules (each colour exactly two endpoints, in range, unique coords).
3. **Solvability via the real engine:** for sampled ids, drive `PuzzleSession` with the witness solution and assert `isComplete == true`.
4. **Difficulty monotonicity:** `size`/`colors`/`minLen` never decrease with `id`; plateau stays constant.
5. **Composite routing:** `id ≤ 10` returns the JSON level with matching id; `id > 10` returns a generated level with matching id and expected size band.
6. **Progression:** simulate completion to level 60 → `highestUnlockedLevel == 60`, `totalScore == 6000`.
7. Keep the existing `shipped_levels_test` for the curated 1–10 pack.

## 7. Future Phases (captured, not implemented here)

Requested during this session; each gets its own spec → plan when we reach it.

- **Phase 2 — Home redesign:** Home shows **PLAY**, **SETTINGS**, and the current **level ("bölüm") number** where the player left off. Keeps the endless-progress feel.
- **Phase 3 — Settings screen:** wire the already-persisted prefs (`soundEnabled`, `vibrationEnabled` in `PlayerProgress`) into a real Settings UI; likely add "reset progress".
- **Phase 4 — Per-level timer:** add a timer to each level. **Open decision (decide at Phase 4):**
  - *Stopwatch* — count up, record best completion time; no lose condition. (Lower risk, non-punishing.)
  - *Countdown* — a time limit that can be failed, changing the game into a timed challenge (needs a lose/fail flow and interacts with `lives`).
  - Interactions to resolve then: scoring (time bonus?), pause on background, and how the timer reads on the gameplay top bar.

## 8. Out of Scope (YAGNI)

- No level-select map, stars/worlds, or difficulty-settings screen (procedural endless was chosen over level-select).
- No online/leaderboards.
- The single linear run flow is preserved.
- **Note:** `completedLevelIds` grows by one per new level cleared; thousands of ints in Hive is acceptable. If it ever matters, collapse to `highestUnlockedLevel` + a completed-count — deferred (YAGNI).

## 9. Risks

- **On-device generation cost:** tiling ≤ 8×8 with bounded retries is sub-millisecond; negligible.
- **Generator hang:** prevented by the bounded attempt budget + deterministic param relaxation (§3).
- **Save growth:** addressed in §8.
