<!--
Design document (no code imports it). No existing spec covers Home/Settings.
Reads/writes no data files. User approved this design in-session ("evet").
Sub-project A of the future-phases in 2026-07-18-procedural-level-system-design.md.
-->

# Home + Settings + Reset — Design

**Date:** 2026-07-18
**Status:** Approved (design)
**Scope:** Add a Settings entry to Home and a Settings screen with sound/vibration preference toggles and a "reset progress" action. Sub-project A of the captured future phases; audio/haptics wiring (making the toggles actually produce sound/vibration) is sub-project B, out of scope here.

## 1. State & persistence

- **`PlayerProgress.copyWith({...})`** — new; currently the model has no copy helper. Copies all seven fields, overriding any provided.
- **`AppProgressController`** gains three mutations, each following the existing `_enqueueMutation` → set `state` → `_save` pattern:
  - `Future<void> setSoundEnabled(bool value)`
  - `Future<void> setVibrationEnabled(bool value)`
  - `Future<void> resetProgress()` — replaces progress with `PlayerProgress.initial()` **but preserves the current `soundEnabled`/`vibrationEnabled`** (settings are not progress). i.e. reset `highestUnlockedLevel→1`, `completedLevelIds→{}`, `totalScore→0`, `lives→3`.
  - Each is a no-op if `state.value` is null (mirrors `_completeLevel`).

## 2. Home (`lib/features/home/home_screen.dart`)

- Add a small **⚙ Settings** `IconButton` in the top-right, inside the existing `SafeArea` (aligned above the centred content). Navigates to `AppRoutes.settings`.
- Existing layout unchanged: big level numeral, "Level N", "Best Score", PLAY. The current level number ("bölüm no") is already shown.

## 3. Settings screen (new `lib/features/settings/settings_screen.dart` + `AppRoutes.settings`)

- `ConsumerWidget`/`ConsumerStatefulWidget` reading `appProgressControllerProvider`.
- **Sound** `SwitchListTile` → `setSoundEnabled`.
- **Vibration** `SwitchListTile` → `setVibrationEnabled`.
- **Reset progress** button → confirmation `AlertDialog` ("This erases all progress"). On confirm → `resetProgress()` → return to Home (`pushNamedAndRemoveUntil(home)`).
- Standard back navigation (AppBar back or a HOME/back control) to Home.
- The toggles persist the preference only; they have no gameplay effect until sub-project B. A short note/subtitle may say sound is coming, but no fake behavior.
- Registered in `app.dart` `_onGenerateRoute` under `AppRoutes.settings`.

## 4. Testing

- `PlayerProgress.copyWith` unit test (overrides one field, preserves the rest).
- Controller tests: `setSoundEnabled`/`setVibrationEnabled` persist via the repository; `resetProgress` resets progress fields and **preserves** sound/vibration.
- Widget tests: Settings toggles reflect and update state; reset confirmation flow calls reset and returns Home; Home ⚙ button navigates to Settings.

## 5. Out of scope (YAGNI)

- No actual sound playback or haptics (sub-project B).
- No countdown timer (sub-project C).
- No extra settings (difficulty, themes, etc.).

## 6. File boundaries

Settings mutation logic lives in the controller; `settings_screen.dart` is UI only. One new screen file, one new route constant, one Home button. Small, focused change.
