<!--
Design document (no code imports it). No existing spec covers lives/timer mechanics.
Reads/writes no data files. User approved this design in-session ("evet").
Builds on the Home/Settings sub-project (2026-07-18-home-settings-reset-design.md)
and the endless procedural level system (2026-07-18-procedural-level-system-design.md).
-->

# Arcade Lives + Countdown Timer — Design

**Date:** 2026-07-18
**Status:** Approved (design)
**Scope:** Add three interlocking mechanics to the existing color-connect puzzle: (1) a
per-level **countdown timer**, (2) a Candy-Crush-style **5-lives system with real-time
regeneration**, and (3) a **refreshed Home menu** plus a new **Out-of-Lives screen** that
surface both. Ad-based life refill is explicitly deferred (a disabled "coming soon"
placeholder only).

## 0. Current state (baseline)

- The game has **no lose condition**: filling the board wins; nothing else ends a level.
- `PlayerProgress` already persists a `lives` field (int, default 3) but **nothing reads or
  mutates it** as a mechanic. There is **no regeneration timestamp**.
- Flow: Splash → Home → Gameplay → Result. Home is minimal (level numeral, best score, PLAY,
  ⚙ Settings). `AppProgressController` owns progress mutations over a Hive-backed repository
  through an `_enqueueMutation` → set `state` → `_save` pattern.
- `difficultyForLevel(id)` (generated ids ≥ 11) yields board `size` 7–8; curated levels 1–10
  range up to 7×7. Full-board coverage is required to win.

## 1. Rules (authoritative)

**Lives**
- Maximum **5**. A fresh install / reset starts at **5**.
- A life is spent **only** when the level countdown reaches zero. Winning a level and using
  the manual RESTART button do **not** cost a life.
- **Regeneration:** while lives < 5, one life is restored every **10 minutes** of real
  wall-clock time. Regen continues while the app is closed. Regen stops at 5 (cap).
- When lives reach **0**, the player cannot start a level until at least one life regenerates
  (or, in a future phase, watches an ad).

**Countdown timer**
- Each level attempt starts with a time limit derived from board size (see §2.4).
- On expiry: spend one life, then
  - if lives remain > 0 → reset the board and restart the **same** level with a **fresh**
    full timer (a brief "Time's up −1 life" cue precedes the reset);
  - if lives are now 0 → navigate to the Out-of-Lives screen.
- The level countdown **pauses when the app is backgrounded** or the gameplay screen is not
  the active route, and resumes on return (fairness; lives regen is unaffected and keeps
  running on wall-clock time).
- Manual **RESTART** clears the board but **preserves the remaining time** (prevents refilling
  the clock as an exploit).

## 2. State & persistence (domain)

### 2.1 `PlayerProgress`
- Keep `lives` (now capped at 5) and add **`livesRegenAnchor`** — a nullable
  `DateTime?` persisted as UTC epoch-milliseconds (`int?`). Semantics: the instant from which
  the *next* life is being counted. `null` ⇔ lives are full (no regen in progress).
- `PlayerProgress.initial()` → `lives: 5`, `livesRegenAnchor: null`.
- `copyWith` and equality/hashCode extended to include the anchor.
- **Schema migration v1 → v2** in `fromPersistedMap`: accept `schemaVersion` 1 or 2.
  - v2 record: read `lives` (0..5) and `livesRegenAnchor` (int millis or absent/null).
  - v1 record: **preserve** `highestUnlockedLevel`, `completedLevelIds`, `totalScore`,
    `soundEnabled`, `vibrationEnabled`; **reset lives to 5 (full), anchor null** (old lives
    semantics differ; give a full tank). Persist back as v2 on next save.
  - Anything else (unsupported version, malformed) → existing reset-to-defaults path.
- `toMap()` writes `schemaVersion: 2` and the anchor (omit/`null` when full).
- Validation: `lives` in 0..5; if `lives == 5` then anchor must be null; if `lives < 5` anchor
  must be present (a `< 5`-with-null record is treated as "anchor = load time").

### 2.2 `LivesState` — pure calculator (new, no Flutter/Flame)
A small value type + pure function that projects stored state to *now*:
`reconcile({required int lives, required DateTime? anchor, required DateTime now, Duration regenInterval = 10 min, int maxLives = 5})`
returns `(int lives, DateTime? anchor, Duration? untilNextLife)`:
- If `lives >= maxLives` → `(maxLives, null, null)`.
- Else `elapsed = now - anchor` (anchor defaulting to `now` if null); `gained = elapsed ~/
  interval`; `newLives = min(maxLives, lives + gained)`.
- If `newLives >= maxLives` → anchor `null`, `untilNextLife` `null`.
- Else advance `anchor += gained * interval` (carry the remainder) and
  `untilNextLife = interval - (now - anchor)`.
- Monotonic and idempotent: reconciling an already-reconciled state at the same `now` is a
  no-op.

### 2.3 `spendLife` (pure transition on `PlayerProgress`)
- Precondition: `lives > 0`. `newLives = lives - 1`.
- If previous `lives == maxLives` (anchor was null) → set `anchor = now` (start the clock).
- Otherwise keep the existing anchor (its countdown continues toward the next life).

### 2.4 `levelTimeLimit(level)` — pure function (new)
- Derives a `Duration` from the level's board size (difficulty proxy; full coverage required).
- Formula: `seconds = round(20 + totalCells * 1.6)`, floored to a **45 s** minimum.
  Reference points: 5×5 (25 cells) ≈ 60 s, 7×7 (49) ≈ 98 s, 8×8 (64) ≈ 122 s.
- Monotonic non-decreasing in board size. Exact constants tuned in tests; the function is the
  single source of truth.

## 3. State/controller

`AppProgressController` gains, each via the existing `_enqueueMutation`/`_save` pattern
(no-op when `state.value` is null):
- **`spendLife({DateTime? now})`** — applies §2.3, persists.
- **`reconcileLives({DateTime? now})`** — applies §2.2; **persists only if lives/anchor
  changed** (avoid needless writes). Called on app resume and on entering Home / Gameplay /
  Out-of-Lives.
- A clock is injected (defaulting to `DateTime.now().toUtc()`) so tests are deterministic.

## 4. Screens & routing

### 4.1 Home (`home_screen.dart`, refreshed)
- **Lives bar:** row of 5 hearts (filled/empty by effective lives). When lives < 5, show
  "Next life: MM:SS" beneath it, updated by a 1 Hz ticker reading the reconciled state.
- Keep level numeral, "Level N", "Best Score", ⚙ Settings.
- **PLAY:** enabled when lives > 0 → Gameplay. When lives == 0 → locked, labeled with the
  next-life countdown; tapping it opens the Out-of-Lives screen.
- `reconcileLives` runs on entry so regen accrued while away is reflected immediately.

### 4.2 Gameplay (`gameplay_screen.dart`)
- **Header additions:** a countdown display (progress bar + MM:SS) and a compact hearts
  indicator, alongside the existing Level label / Home / RESTART.
- Owns a periodic (≈1 Hz or finer for the bar) ticker for the current attempt's remaining
  time. Pauses via `WidgetsBindingObserver` / route visibility; resumes on return.
- **On expiry:** call `spendLife`, show the "Time's up −1 life" cue, then reconcile lives and
  branch: lives > 0 → reset board (`game.restart`) + reset timer to full; lives == 0 →
  `pushReplacement` to Out-of-Lives.
- **On win (existing):** unchanged next-level/result flow; no life spent; timer stops.
- **RESTART:** clears the board, keeps remaining time.
- **Entry guard:** if lives == 0 on entry (e.g. deep link / back nav), redirect to
  Out-of-Lives instead of starting a level.

### 4.3 Out-of-Lives screen (new `lib/features/out_of_lives/…` + `AppRoutes.outOfLives`)
- Full-screen: "You're out of lives", a 1 Hz next-life countdown (MM:SS), a **disabled**
  "Watch ad (coming soon)" button, and a "Main menu" button (→ Home,
  `pushNamedAndRemoveUntil`).
- When a life regenerates (countdown hits 0 → reconcile yields lives > 0), enable a
  "Continue" action returning to Gameplay for the current level.
- Registered in `app.dart` `_onGenerateRoute`.

## 5. Testing

**Pure unit (no widgets):**
- `LivesState.reconcile`: partial window (no gain), exactly one window, multiple windows,
  cap at 5 (anchor cleared), anchor remainder carry, idempotence.
- `spendLife`: from full sets anchor = now; from partial keeps anchor; refuses below 0.
- `levelTimeLimit`: monotonic non-decreasing in size; 45 s floor; reference points.
- `PlayerProgress`: v1→v2 migration preserves progress and refills lives; v2 round-trips the
  anchor; validation rejects `lives`>5 and inconsistent lives/anchor pairs.

**Controller:**
- `spendLife` persists decrement + anchor; `reconcileLives` applies regen and persists only on
  change; both are no-ops when state is null.

**Widget:**
- Home: hearts reflect lives; at 0 lives PLAY is locked and shows the countdown; tapping opens
  Out-of-Lives; regen accrued "while away" shows on entry (injected clock).
- Gameplay: timer expiry spends a life and restarts the board with a fresh timer; expiry at
  the last life routes to Out-of-Lives; RESTART keeps remaining time; entry with 0 lives
  redirects.
- Out-of-Lives: countdown ticks; on reaching a regenerated life the Continue action enables.

## 6. Out of scope (YAGNI)

- **Ad-based life refill** — placeholder button is disabled; no ad SDK, no reward flow.
- No purchases / "buy lives", no per-level star ratings, no timer-based scoring bonus.
- No audio/haptic cues beyond the existing (sub-project B) wiring.
