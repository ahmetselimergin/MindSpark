# Task 6 Report — Flutter application flow

## Outcome

Implemented the playable Flutter flow from persistent startup through splash, home, gameplay, save-gated completion, and result navigation. Production initializes Hive CE and injects `HiveProgressRepository`; tests override level/progress repositories and the `MindSparkGame` factory without changing domain behavior.

The UI follows the supplied Android casual-puzzle direction: Midnight Ink and Deep Circuit foundations, Spark Yellow primary actions, Electric Cyan connections, Coral Pulse failures, Frost text, condensed heavy display numerals, a centered single-action hierarchy, maximum square board space, and one reusable three-node spark-trail motif. No dependency, gradient, glass effect, remote font, life indicator, or decorative animation was added.

## TDD evidence

### Splash and home

RED command:

```text
flutter test test/widget_test.dart
```

Observed expected compilation failure because `lib/app/app.dart`, `levelRepositoryProvider`, and `MindSparkApp` did not exist. Exit code: 1.

GREEN command:

```text
flutter test test/widget_test.dart
```

Observed 3 tests passed. Exit code: 0. During the cycle, the retry test exposed Riverpod 3's automatic provider retry; disabling automatic retry on initialization providers made the visible RETRY action authoritative.

### Gameplay and result

RED command:

```text
flutter test test/features/app_flow_test.dart
```

Observed expected compilation failure because `gameplay_screen.dart`, `mindSparkGameFactoryProvider`, and the test navigator seam did not exist. Exit code: 1.

GREEN command:

```text
flutter test test/widget_test.dart test/features/app_flow_test.dart
```

Observed 9 tests passed. Exit code: 0. The first integrated run also identified that `pumpAndSettle` is inappropriate while Flame's game ticker is active; tests were corrected to use finite route pumps. No production workaround was introduced.

Covered behavior:

- splash loading and explicit level-load retry;
- loaded Home level/score/action values;
- Play routing and exactly one game creation per gameplay screen;
- Restart forwarding to the real `MindSparkGame` instance;
- first completion award of 100 and replay award of 0;
- screen-level duplicate completion guard;
- failed save remaining on gameplay with the optimistic candidate preserved;
- retrying the exact failed candidate before navigating once;
- repository-order navigation across non-sequential IDs `1 → 5`;
- final repository level returning Home;
- invalid gameplay arguments rendering a safe error page.

## Final verification

```text
flutter test
```

Result: 80 tests passed, 0 failed. Exit code: 0.

```text
flutter analyze
```

Result: no issues found. Exit code: 0.

```text
git diff --check
```

Result: no whitespace errors. Exit code: 0.

## Review notes

- Completion is guarded before awaiting persistence and navigation is separately guarded.
- Award is derived from completed-level membership before and after the controller mutation.
- Save failure remains an `AsyncError` carrying the candidate; result navigation is blocked until retry reaches a non-error state.
- Result progression is derived from sorted repository order, never `levelId + 1`.
- Route arguments are type/range checked before screen construction; unknown or missing arguments use a safe page.
- All post-await UI work checks `mounted`.
- Existing level, progress, puzzle, and renderer domain behavior was not broadened.

## Review fixes

### Retryable Hive bootstrap

RED command:

```text
flutter test test/widget_test.dart --plain-name 'bootstrap failure can retry and mount the app'
```

Observed the expected compile failure because `ProgressBootstrap` did not exist. Exit code: 1.

GREEN evidence: `main()` now mounts `ProgressBootstrap` immediately after binding initialization. Its injected initializer catches synchronous and asynchronous Hive setup failures, renders branded loading/error UI, retries on demand, and mounts `MindSparkApp` under the `HiveProgressRepository` override only after success. The fail→retry→success widget test passed.

### Route authorization and safe content errors

RED commands exercised locked gameplay ID `5`, a missing gameplay ID, stale `highestUnlockedLevel: 3`, and a missing result ID. Each failed for the expected missing guard or action.

GREEN evidence: `levelsProvider` returns an immutable ID-sorted list; gameplay resolves requested and highest-unlocked indexes before creating a game and allows only indexes at or below the unlock boundary. Home no longer substitutes the first level when saved progress references absent assets, and the recoverable content error offers RETRY. Missing result IDs offer HOME.

### Save retry persistence proof

RED regressions showed that a rebuilt controller with no pending candidate, and a controller still loading, could be treated as save success. A progress-load error also left the wrong retry action.

GREEN evidence: retry navigation now requires `hasValue && !hasError` and a saved value whose `completedLevelIds` contains the current level. `AppProgressController.hasPendingSave` distinguishes a genuine failed write from a no-candidate no-op. No-candidate/loading/load-error cases remain on gameplay and offer RETRY PROGRESS; the successful retry test proves both attempts use the identical candidate and that it reaches repository `saved` state.

### Responsive layout and duplicate transitions

RED widget runs at `320×568` with text scale `2.0` produced RenderFlex overflows on Home, Gameplay, and Result. Programmatic double invocation produced two gameplay routes from Play and two next-level games from Next.

GREEN evidence: Home, Splash, and Result use safe-area layout constraints with scroll fallback; compact gaps shrink and large score/level numerals scale down. Gameplay uses a wrapping header. Home Play and Result Next/Home maintain synchronous stateful navigation latches and disable immediately during transition. The compact-screen tests report no framework exception, and rapid callback tests create exactly one destination game.

### Fix verification

```text
flutter test test/widget_test.dart test/features/app_flow_test.dart
```

Result: 22 focused widget tests passed, 0 failed. Exit code: 0.

```text
flutter test
```

Result: 93 tests passed, 0 failed. Exit code: 0.

```text
flutter analyze
```

Result: no issues found. Exit code: 0.

```text
git diff --check
```

Result: no whitespace errors. Exit code: 0.

No dependencies, gradients, glass effects, remote fonts, life indicators, animations, or unrelated features were added.
