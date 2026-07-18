# Arcade Lives + Countdown Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-level countdown timer, a Candy-Crush-style 5-lives system with 10-minute real-time regeneration, a refreshed Home menu, and an Out-of-Lives screen to the existing color-connect puzzle.

**Architecture:** Lives + a regen anchor timestamp live in the single atomic `PlayerProgress` Hive record (schema bumped v1→v2 with migration). Pure, Flutter-free domain functions own the regen math (`LivesRegen.reconcile`), the life-spend transition (`PlayerProgress.spendLife`), and the per-level time limit (`levelTimeLimit`). `AppProgressController` gains `spendLife`/`reconcileLives` mutations over an injectable clock. Screens own their own 1 Hz tickers; the countdown lives in the gameplay screen (not the Flame game).

**Tech Stack:** Flutter, Flame, flutter_riverpod (AsyncNotifier), hive_ce; Dart `^3.12.2`.

## Global Constraints

- Dart SDK floor `^3.12.2`; **add no new dependencies**.
- Follow existing idioms: `final class`, Riverpod providers, `_enqueueMutation`→set `state`→`_save` mutation pattern, one atomic version-stamped progress record.
- **Max lives = 5**; **regen = one life per 10 minutes** of wall-clock time, continuing while the app is closed; regen stops at 5.
- A life is spent **only** on countdown expiry — never on a win or a manual RESTART.
- Level countdown **pauses** while backgrounded/off-route; lives regen is wall-clock and never pauses.
- Manual RESTART clears the board but **keeps** remaining time.
- Ad-based refill is **deferred**: a disabled "coming soon" placeholder only. No ad SDK.
- All timestamps are **UTC at millisecond precision** (persisted as epoch-millis `int?`).
- Spec: `docs/superpowers/specs/2026-07-18-arcade-lives-timer-design.md`.

---

### Task 1: `PlayerProgress` — schema v2, regen anchor, lives cap 5, migration

**Files:**
- Modify: `lib/models/player_progress.dart`
- Test: `test/models/player_progress_test.dart` (update existing expectations + add v2/migration cases)
- Test (fix fallout): `test/repositories/hive_progress_repository_test.dart`, `test/state/app_progress_controller_test.dart`

**Interfaces:**
- Produces:
  - `PlayerProgress.livesRegenAnchor` → `DateTime?` (null ⇔ lives full).
  - `PlayerProgress.initial()` → `lives: 5`, `livesRegenAnchor: null`, `schemaVersion: 2`.
  - `PlayerProgress copyWithLives({required int lives, required DateTime? anchor})` — full copy that can set the anchor to `null`.
  - `toMap()`/`fromMap()`/`fromPersistedMap()` speaking schema **2**, accepting persisted v1 (migrated) and v2, rejecting others.
  - Current schema constant behavior: the constructor stamps `schemaVersion` to **2** always.

- [ ] **Step 1: Update the model tests to the new defaults and schema (write them failing first)**

In `test/models/player_progress_test.dart`:

Change the initial-defaults expectations (currently lines ~9 and ~13):
```dart
    test('initial progress uses schema defaults', () {
      const progress = PlayerProgress.initial();

      expect(progress.schemaVersion, 2);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.completedLevelIds, isEmpty);
      expect(progress.totalScore, 0);
      expect(progress.lives, 5);
      expect(progress.livesRegenAnchor, isNull);
      expect(progress.soundEnabled, isTrue);
      expect(progress.vibrationEnabled, isTrue);
    });
```

In the `'strict persisted parsing rejects every malformed record shape'` case list, **remove** the line `('schemaVersion', {...valid, 'schemaVersion': 2}),` and **add** rejection of a genuinely unsupported version and an over-cap lives value (keep a single `('lives', {...valid, 'lives': -1})`):
```dart
        ('schemaVersion', {...valid, 'schemaVersion': 3}),
        ('lives', {...valid, 'lives': -1}),
        ('lives', {...valid, 'lives': 6}),
```

Replace the `'normalizes every unsupported schema version to version one'` test with one asserting the current stamp is 2 and that v2 is a first-class value:
```dart
    test('stamps the current schema version (2) on every constructed record', () {
      for (final raw in <Object?>[99, 0, -1, true, false, 1.0, '1', 1]) {
        expect(
          PlayerProgress.fromMap({'schemaVersion': raw}).schemaVersion,
          2,
          reason: 'schemaVersion: $raw',
        );
      }
      expect(
        PlayerProgress(
          schemaVersion: 2,
          highestUnlockedLevel: 1,
          completedLevelIds: const {},
          totalScore: 0,
          lives: 5,
          soundEnabled: true,
          vibrationEnabled: true,
        ).schemaVersion,
        2,
      );
    });
```

Add two new tests (v2 round-trip with an anchor, and v1→v2 migration):
```dart
    test('round-trips a v2 record carrying a regen anchor', () {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final record = <Object?, Object?>{
        'schemaVersion': 2,
        'highestUnlockedLevel': 4,
        'completedLevelIds': <int>[1, 2, 3],
        'totalScore': 300,
        'lives': 2,
        'livesRegenAnchor': anchor.millisecondsSinceEpoch,
        'soundEnabled': true,
        'vibrationEnabled': true,
      };

      final progress = PlayerProgress.fromPersistedMap(record);

      expect(progress.lives, 2);
      expect(progress.livesRegenAnchor, anchor);
      expect(PlayerProgress.fromPersistedMap(progress.toMap()), progress);
    });

    test('migrates a persisted v1 record: keeps progress, refills lives to 5', () {
      final progress = PlayerProgress.fromPersistedMap(<Object?, Object?>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 6,
        'completedLevelIds': <int>[1, 2, 3, 4, 5],
        'totalScore': 500,
        'lives': 2,
        'soundEnabled': false,
        'vibrationEnabled': true,
      });

      expect(progress.schemaVersion, 2);
      expect(progress.highestUnlockedLevel, 6);
      expect(progress.completedLevelIds, {1, 2, 3, 4, 5});
      expect(progress.totalScore, 500);
      expect(progress.lives, 5); // refilled
      expect(progress.livesRegenAnchor, isNull);
      expect(progress.soundEnabled, isFalse);
    });
```

- [ ] **Step 2: Run the model tests — verify they fail**

Run: `flutter test test/models/player_progress_test.dart`
Expected: FAIL (initial lives still 3, `livesRegenAnchor`/`copyWithLives` undefined, schema 2 rejected).

- [ ] **Step 3: Implement the model changes**

Edit `lib/models/player_progress.dart`:

Add `livesRegenAnchor` to the factory params, private constructor, fields, `initial`, `fromMap`, `fromPersistedMap`, `toMap`, equality, and hashCode. Change the schema stamp to 2, `initial` lives to 5, and add `copyWithLives`. Key changes:

```dart
  factory PlayerProgress({
    required int schemaVersion,
    required int highestUnlockedLevel,
    required Set<int> completedLevelIds,
    required int totalScore,
    required int lives,
    DateTime? livesRegenAnchor,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    return PlayerProgress._(
      schemaVersion: _schemaVersion(schemaVersion),
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: Set<int>.unmodifiable(completedLevelIds),
      totalScore: totalScore,
      lives: lives,
      livesRegenAnchor: livesRegenAnchor,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }

  const PlayerProgress._({
    required this.schemaVersion,
    required this.highestUnlockedLevel,
    required this.completedLevelIds,
    required this.totalScore,
    required this.lives,
    required this.livesRegenAnchor,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  const PlayerProgress.initial()
    : this._(
        schemaVersion: 2,
        highestUnlockedLevel: 1,
        completedLevelIds: const <int>{},
        totalScore: 0,
        lives: 5,
        livesRegenAnchor: null,
        soundEnabled: true,
        vibrationEnabled: true,
      );
```

`fromMap` (lenient) — add anchor parsing and clamp lives to 0..5:
```dart
    return PlayerProgress(
      schemaVersion: _schemaVersion(map['schemaVersion']),
      highestUnlockedLevel: _positiveInt(map['highestUnlockedLevel'], fallback: 1),
      completedLevelIds: Set<int>.unmodifiable(completedLevelIds),
      totalScore: _nonNegativeInt(map['totalScore'], fallback: 0),
      lives: _boundedLives(map['lives']),
      livesRegenAnchor: _anchorFromMillis(map['livesRegenAnchor']),
      soundEnabled: map['soundEnabled'] is bool ? map['soundEnabled']! as bool : true,
      vibrationEnabled: map['vibrationEnabled'] is bool ? map['vibrationEnabled']! as bool : true,
    );
```

`fromPersistedMap` — accept schema 1 or 2, validate lives 0..5, read/migrate anchor:
```dart
    final schemaVersion = _requiredInt(record, 'schemaVersion');
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const ProgressFormatException(
        field: 'schemaVersion',
        message: 'must be 1 or 2',
      );
    }
    // ... existing highestUnlockedLevel / completedLevelIds / totalScore checks ...

    final lives = _requiredInt(record, 'lives');
    if (lives < 0 || lives > 5) {
      throw const ProgressFormatException(
        field: 'lives',
        message: 'must be between 0 and 5',
      );
    }

    // v1 records predate lives regen: give a full tank and preserve progress.
    final migratedLives = schemaVersion == 1 ? 5 : lives;
    final anchor = schemaVersion == 1
        ? null
        : _persistedAnchor(record, migratedLives);

    return PlayerProgress(
      schemaVersion: 2,
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: completedLevelIds,
      totalScore: totalScore,
      lives: migratedLives,
      livesRegenAnchor: anchor,
      soundEnabled: _requiredBool(record, 'soundEnabled'),
      vibrationEnabled: _requiredBool(record, 'vibrationEnabled'),
    );
```

`toMap` — write schema 2 and the anchor only when present:
```dart
  Map<String, Object> toMap() {
    final sortedCompletedLevelIds = completedLevelIds.toList()..sort();
    final map = <String, Object>{
      'schemaVersion': 2,
      'highestUnlockedLevel': highestUnlockedLevel,
      'completedLevelIds': sortedCompletedLevelIds,
      'totalScore': totalScore,
      'lives': lives,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
    final anchor = livesRegenAnchor;
    if (anchor != null) {
      map['livesRegenAnchor'] = anchor.toUtc().millisecondsSinceEpoch;
    }
    return map;
  }
```

Add `copyWithLives` (near `copyWith`) — needed because the existing `copyWith` cannot set the anchor back to `null`:
```dart
  PlayerProgress copyWithLives({required int lives, required DateTime? anchor}) {
    return PlayerProgress(
      schemaVersion: schemaVersion,
      highestUnlockedLevel: highestUnlockedLevel,
      completedLevelIds: completedLevelIds,
      totalScore: totalScore,
      lives: lives,
      livesRegenAnchor: anchor,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }
```

Thread `livesRegenAnchor` through `copyWith`, `completeLevel`, `==`, and `hashCode` (preserve it in each — `completeLevel` and `copyWith` keep the current anchor). Update the schema-stamp helper and add the parsing helpers at the bottom (all top-level functions like the existing `_positiveInt`, not instance methods):
```dart
int _schemaVersion(Object? value) => 2; // current schema; always stamped

int _boundedLives(Object? value) => value is int ? value.clamp(0, 5) : 5;

DateTime? _anchorFromMillis(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : null;

DateTime? _persistedAnchor(Map<Object?, Object?> record, int lives) {
  final raw = record['livesRegenAnchor'];
  if (lives >= 5) return null; // full ⇒ no regen in progress
  if (raw == null) return null; // healed to `now` on first reconcile
  if (raw is! int) {
    throw const ProgressFormatException(
      field: 'livesRegenAnchor',
      message: 'must be an integer or absent',
    );
  }
  return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
}
```

- [ ] **Step 4: Run the model tests — verify they pass**

Run: `flutter test test/models/player_progress_test.dart`
Expected: PASS.

- [ ] **Step 5: Fix the two dependent test files broken by the new defaults**

`test/repositories/hive_progress_repository_test.dart`:
- Line ~98: change `_putRecord(box!, schemaVersion: 2)` to `_putRecord(box!, schemaVersion: 3)` (3 is unsupported; 2 is now valid). The assertion (`diagnostics.single.field == 'schemaVersion'`) stays.
- Add a migration test after it:
```dart
    test('migrates a persisted v1 record and refills lives to 5', () async {
      await box!.put('playerProgress', <String, Object>{
        'schemaVersion': 1,
        'highestUnlockedLevel': 3,
        'completedLevelIds': const <int>[1, 2],
        'totalScore': 200,
        'lives': 2,
        'soundEnabled': true,
        'vibrationEnabled': true,
      });

      final loaded = await repository!.load();

      expect(loaded.schemaVersion, 2);
      expect(loaded.highestUnlockedLevel, 3);
      expect(loaded.completedLevelIds, {1, 2});
      expect(loaded.lives, 5);
      expect(loaded.livesRegenAnchor, isNull);
      expect(diagnostics, isEmpty);
    });
```

`test/state/app_progress_controller_test.dart`:
- In `'resetProgress clears progress but keeps the sound/vibration settings'`, change `expect(progress.lives, 3);` (line ~93) to `expect(progress.lives, 5);`.

- [ ] **Step 6: Run the full suite — verify green**

Run: `flutter test`
Expected: PASS. If any other test asserts `schemaVersion == 1` or an initial/reset `lives == 3`, update it to `2` / `5` respectively (mechanical; new defaults). Then `flutter analyze` → no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/models/player_progress.dart test/models/player_progress_test.dart \
        test/repositories/hive_progress_repository_test.dart \
        test/state/app_progress_controller_test.dart
git commit -m "feat: add lives regen anchor and schema v2 migration to PlayerProgress"
```

---

### Task 2: `LivesRegen.reconcile` — pure regeneration calculator

**Files:**
- Create: `lib/game/domain/lives_state.dart`
- Test: `test/game/domain/lives_state_test.dart`

**Interfaces:**
- Produces:
  - `class ReconciledLives { final int lives; final DateTime? anchor; final Duration? untilNextLife; }` (const, with `==`/`hashCode`).
  - `abstract final class LivesRegen { static const int maxLives = 5; static const Duration interval = Duration(minutes: 10); static ReconciledLives reconcile({required int lives, required DateTime? anchor, required DateTime now}); }`
- Consumes: nothing (pure Dart; no Flutter/Flame imports).

- [ ] **Step 1: Write the failing tests**

`test/game/domain/lives_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/lives_state.dart';

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
  const tenMin = Duration(minutes: 10);

  group('LivesRegen.reconcile', () {
    test('full lives report no anchor and no countdown', () {
      final r = LivesRegen.reconcile(lives: 5, anchor: null, now: t0);
      expect(r.lives, 5);
      expect(r.anchor, isNull);
      expect(r.untilNextLife, isNull);
    });

    test('partial window grants nothing and keeps the anchor', () {
      final r = LivesRegen.reconcile(
        lives: 2,
        anchor: t0,
        now: t0.add(const Duration(minutes: 4)),
      );
      expect(r.lives, 2);
      expect(r.anchor, t0);
      expect(r.untilNextLife, const Duration(minutes: 6));
    });

    test('null anchor below max seeds the anchor at now', () {
      final r = LivesRegen.reconcile(lives: 1, anchor: null, now: t0);
      expect(r.lives, 1);
      expect(r.anchor, t0);
      expect(r.untilNextLife, tenMin);
    });

    test('exactly one elapsed window grants one life and advances the anchor', () {
      final r = LivesRegen.reconcile(lives: 2, anchor: t0, now: t0.add(tenMin));
      expect(r.lives, 3);
      expect(r.anchor, t0.add(tenMin));
      expect(r.untilNextLife, tenMin);
    });

    test('multiple windows grant multiple lives and carry the remainder', () {
      final r = LivesRegen.reconcile(
        lives: 1,
        anchor: t0,
        now: t0.add(const Duration(minutes: 25)),
      );
      expect(r.lives, 3);
      expect(r.anchor, t0.add(const Duration(minutes: 20)));
      expect(r.untilNextLife, const Duration(minutes: 5));
    });

    test('reaching the cap clears the anchor and countdown', () {
      final r = LivesRegen.reconcile(
        lives: 3,
        anchor: t0,
        now: t0.add(const Duration(minutes: 45)),
      );
      expect(r.lives, 5);
      expect(r.anchor, isNull);
      expect(r.untilNextLife, isNull);
    });

    test('is idempotent: reconciling a reconciled state is a no-op', () {
      final first = LivesRegen.reconcile(
        lives: 1,
        anchor: t0,
        now: t0.add(const Duration(minutes: 12)),
      );
      final second = LivesRegen.reconcile(
        lives: first.lives,
        anchor: first.anchor,
        now: t0.add(const Duration(minutes: 12)),
      );
      expect(second.lives, first.lives);
      expect(second.anchor, first.anchor);
      expect(second.untilNextLife, first.untilNextLife);
    });

    test('negative elapsed (clock skew) grants nothing', () {
      final r = LivesRegen.reconcile(
        lives: 2,
        anchor: t0,
        now: t0.subtract(const Duration(minutes: 5)),
      );
      expect(r.lives, 2);
      expect(r.anchor, t0);
      expect(r.untilNextLife, tenMin);
    });
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/game/domain/lives_state_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'lives_state.dart'".

- [ ] **Step 3: Implement**

`lib/game/domain/lives_state.dart`:
```dart
/// Projection of stored lives to a point in time.
final class ReconciledLives {
  const ReconciledLives({
    required this.lives,
    required this.anchor,
    required this.untilNextLife,
  });

  final int lives;
  final DateTime? anchor;
  final Duration? untilNextLife;

  @override
  bool operator ==(Object other) =>
      other is ReconciledLives &&
      other.lives == lives &&
      other.anchor == anchor &&
      other.untilNextLife == untilNextLife;

  @override
  int get hashCode => Object.hash(lives, anchor, untilNextLife);
}

/// Wall-clock life regeneration: one life every [interval], capped at [maxLives].
abstract final class LivesRegen {
  static const int maxLives = 5;
  static const Duration interval = Duration(minutes: 10);

  static ReconciledLives reconcile({
    required int lives,
    required DateTime? anchor,
    required DateTime now,
  }) {
    final clamped = lives.clamp(0, maxLives);
    if (clamped >= maxLives) {
      return const ReconciledLives(
        lives: maxLives,
        anchor: null,
        untilNextLife: null,
      );
    }

    final effectiveAnchor = anchor ?? now;
    var elapsed = now.difference(effectiveAnchor);
    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    final gained = elapsed.inMilliseconds ~/ interval.inMilliseconds;
    final newLives = (clamped + gained).clamp(0, maxLives);
    if (newLives >= maxLives) {
      return const ReconciledLives(
        lives: maxLives,
        anchor: null,
        untilNextLife: null,
      );
    }

    final advancedAnchor = effectiveAnchor.add(interval * gained);
    return ReconciledLives(
      lives: newLives,
      anchor: advancedAnchor,
      untilNextLife: interval - now.difference(advancedAnchor),
    );
  }
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/game/domain/lives_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/domain/lives_state.dart test/game/domain/lives_state_test.dart
git commit -m "feat: add pure lives regeneration calculator"
```

---

### Task 3: `PlayerProgress.spendLife` — life-spend transition

**Files:**
- Modify: `lib/models/player_progress.dart`
- Test: `test/models/player_progress_test.dart`

**Interfaces:**
- Consumes: `LivesRegen.maxLives` (Task 2), `PlayerProgress.copyWithLives` (Task 1).
- Produces: `PlayerProgress spendLife({required DateTime now})` — `lives - 1`; if lives were full, starts the regen clock (`anchor = now`); otherwise keeps the existing anchor; a no-op at 0 lives.

- [ ] **Step 1: Write the failing tests**

Add to `test/models/player_progress_test.dart` inside the `PlayerProgress` group:
```dart
    test('spendLife from full starts the regen clock', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      const full = PlayerProgress.initial(); // 5 lives, no anchor

      final after = full.spendLife(now: now);

      expect(after.lives, 4);
      expect(after.livesRegenAnchor, now);
    });

    test('spendLife below full keeps the running anchor', () {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final later = anchor.add(const Duration(minutes: 3));
      final partial = const PlayerProgress.initial().copyWithLives(lives: 3, anchor: anchor);

      final after = partial.spendLife(now: later);

      expect(after.lives, 2);
      expect(after.livesRegenAnchor, anchor); // unchanged
    });

    test('spendLife at zero lives is a no-op', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final empty = const PlayerProgress.initial().copyWithLives(lives: 0, anchor: now);

      expect(empty.spendLife(now: now.add(const Duration(minutes: 1))), empty);
    });
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/models/player_progress_test.dart --plain-name spendLife`
Expected: FAIL with "The method 'spendLife' isn't defined".

- [ ] **Step 3: Implement**

Add the import at the top of `lib/models/player_progress.dart`:
```dart
import 'package:mind_spark/game/domain/lives_state.dart';
```
Add the method (near `completeLevel`):
```dart
  PlayerProgress spendLife({required DateTime now}) {
    if (lives <= 0) {
      return this;
    }
    final startsClock = lives >= LivesRegen.maxLives;
    return copyWithLives(
      lives: lives - 1,
      anchor: startsClock ? now.toUtc() : livesRegenAnchor,
    );
  }
```

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/models/player_progress_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/player_progress.dart test/models/player_progress_test.dart
git commit -m "feat: add PlayerProgress.spendLife transition"
```

---

### Task 4: `levelTimeLimit` — per-level countdown duration

**Files:**
- Create: `lib/game/generation/level_timer.dart`
- Test: `test/game/generation/level_timer_test.dart`

**Interfaces:**
- Produces: `Duration levelTimeLimit(int boardSize)` — pure; `seconds = round(20 + boardSize*boardSize*1.6)`, floored to a **45 s** minimum; monotonic non-decreasing in `boardSize`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing tests**

`test/game/generation/level_timer_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/generation/level_timer.dart';

void main() {
  group('levelTimeLimit', () {
    test('reference board sizes', () {
      expect(levelTimeLimit(5), const Duration(seconds: 60));  // 20 + 25*1.6
      expect(levelTimeLimit(7), const Duration(seconds: 98));  // 20 + 49*1.6
      expect(levelTimeLimit(8), const Duration(seconds: 122)); // 20 + 64*1.6
    });

    test('never below the 45s floor', () {
      expect(levelTimeLimit(2).inSeconds, greaterThanOrEqualTo(45));
      expect(levelTimeLimit(3).inSeconds, greaterThanOrEqualTo(45));
    });

    test('is monotonic non-decreasing in board size', () {
      for (var size = 2; size < 12; size++) {
        expect(
          levelTimeLimit(size + 1).inSeconds,
          greaterThanOrEqualTo(levelTimeLimit(size).inSeconds),
          reason: 'size $size -> ${size + 1}',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/game/generation/level_timer_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'level_timer.dart'".

- [ ] **Step 3: Implement**

`lib/game/generation/level_timer.dart`:
```dart
/// Countdown budget for a level, derived from board size (the difficulty proxy;
/// full-board coverage is required to win, so time scales with cell count).
Duration levelTimeLimit(int boardSize) {
  final cells = boardSize * boardSize;
  final seconds = (20 + cells * 1.6).round();
  return Duration(seconds: seconds < 45 ? 45 : seconds);
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/game/generation/level_timer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/generation/level_timer.dart test/game/generation/level_timer_test.dart
git commit -m "feat: add per-level countdown duration function"
```

---

### Task 5: `AppProgressController` — clock, spendLife, reconcileLives

**Files:**
- Modify: `lib/state/app_progress_controller.dart`
- Test: `test/state/app_progress_controller_test.dart`

**Interfaces:**
- Consumes: `PlayerProgress.spendLife` (Task 3), `LivesRegen.reconcile` (Task 2), `PlayerProgress.copyWithLives` (Task 1).
- Produces:
  - `final clockProvider = Provider<DateTime Function()>(...)` — returns millisecond-precision UTC `DateTime.now()`.
  - `AppProgressController.spendLife({DateTime? now})` — decrements a life, persists.
  - `AppProgressController.reconcileLives({DateTime? now})` — applies regen; **persists only when lives or anchor changed**.
  - Both no-op when `state.value == null`; both go through `_enqueueMutation`.

- [ ] **Step 1: Write the failing tests**

Add to `test/state/app_progress_controller_test.dart` — a fixed-clock container helper and imports (`RecordingProgressRepository` already exists in this file):
```dart
import 'package:mind_spark/game/domain/lives_state.dart';

ProviderContainer _containerWithClock(
  ProgressRepository repository,
  DateTime Function() clock,
) {
  return ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(clock),
    ],
  );
}
```
Tests:
```dart
    test('spendLife decrements and starts the clock from full', () async {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final repository = RecordingProgressRepository(); // initial: 5 lives
      final container = _containerWithClock(repository, () => now);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.spendLife();

      final progress = container.read(appProgressControllerProvider).requireValue;
      expect(progress.lives, 4);
      expect(progress.livesRegenAnchor, now);
      expect(repository.saved.last, progress);
    });

    test('reconcileLives grants elapsed lives and persists once', () async {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final stored = const PlayerProgress.initial().copyWithLives(lives: 2, anchor: anchor);
      final repository = RecordingProgressRepository(stored);
      final now = anchor.add(const Duration(minutes: 21));
      final container = _containerWithClock(repository, () => now);
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.reconcileLives();

      final progress = container.read(appProgressControllerProvider).requireValue;
      expect(progress.lives, 4);
      expect(progress.livesRegenAnchor, anchor.add(const Duration(minutes: 20)));
      expect(repository.saved, hasLength(1));
    });

    test('reconcileLives is a no-op within the same window (no write)', () async {
      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final stored = const PlayerProgress.initial().copyWithLives(lives: 2, anchor: anchor);
      final repository = RecordingProgressRepository(stored);
      final container = _containerWithClock(
        repository,
        () => anchor.add(const Duration(minutes: 3)),
      );
      addTearDown(container.dispose);
      final controller = container.read(appProgressControllerProvider.notifier);
      await container.read(appProgressControllerProvider.future);

      await controller.reconcileLives();

      expect(repository.saved, isEmpty);
      expect(
        container.read(appProgressControllerProvider).requireValue.lives,
        2,
      );
    });
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/state/app_progress_controller_test.dart`
Expected: FAIL (`clockProvider`, `spendLife`, `reconcileLives` undefined).

- [ ] **Step 3: Implement**

Edit `lib/state/app_progress_controller.dart`. Add the import and provider:
```dart
import 'package:mind_spark/game/domain/lives_state.dart';

final clockProvider = Provider<DateTime Function()>(
  (ref) => () {
    final now = DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch,
      isUtc: true,
    );
  },
);
```
Add a `_now()` helper and the two mutations inside `AppProgressController`:
```dart
  DateTime _now() => ref.read(clockProvider)();

  Future<void> spendLife({DateTime? now}) {
    return _enqueueMutation(() => _spendLife(now ?? _now()));
  }

  Future<void> _spendLife(DateTime now) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final candidate = current.spendLife(now: now);
    if (candidate == current) {
      return;
    }
    state = AsyncData(candidate);
    await _save(candidate);
  }

  Future<void> reconcileLives({DateTime? now}) {
    return _enqueueMutation(() => _reconcileLives(now ?? _now()));
  }

  Future<void> _reconcileLives(DateTime now) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final result = LivesRegen.reconcile(
      lives: current.lives,
      anchor: current.livesRegenAnchor,
      now: now,
    );
    if (result.lives == current.lives &&
        result.anchor == current.livesRegenAnchor) {
      return;
    }
    final candidate = current.copyWithLives(
      lives: result.lives,
      anchor: result.anchor,
    );
    state = AsyncData(candidate);
    await _save(candidate);
  }
```

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/state/app_progress_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state/app_progress_controller.dart test/state/app_progress_controller_test.dart
git commit -m "feat: add spendLife and reconcileLives controller mutations"
```

---

### Task 6: `LivesBar` widget + Home menu refresh

**Files:**
- Create: `lib/core/widgets/lives_bar.dart`
- Modify: `lib/features/home/home_screen.dart`, `lib/app/routes.dart` (add the `outOfLives` route symbol + args, inert until Task 7)
- Test: `test/features/home_screen_lives_test.dart`

**Interfaces:**
- Consumes: `appProgressControllerProvider`, `clockProvider`, `LivesRegen.reconcile`, `AppProgressController.reconcileLives`.
- Produces:
  - `class LivesBar extends ConsumerStatefulWidget { const LivesBar({super.key}); }` — renders `LivesRegen.maxLives` hearts (`Icons.favorite` = current lives, `Icons.favorite_border` for the rest) and, when not full, a "Next life MM:SS" line; a 1 Hz ticker refreshes the countdown and persists via `reconcileLives` when a life is earned.
  - `AppRoutes.outOfLives` = `'/out-of-lives'` and `OutOfLivesRouteArgs(int levelId)`.
  - Home shows `LivesBar`; PLAY is disabled when reconciled `lives == 0` and an "OUT OF LIVES" button opens the Out-of-Lives screen.

- [ ] **Step 1: Write the failing widget tests**

`test/features/home_screen_lives_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/features/home/home_screen.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

LevelModel _level(int id) => LevelModel(
      id: id,
      size: 5,
      points: const [
        GridPoint(x: 0, y: 0, color: 'red'),
        GridPoint(x: 4, y: 4, color: 'red'),
      ],
    );

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider
          .overrideWithValue(InMemoryProgressRepository(stored)),
      clockProvider.overrideWithValue(() => now),
      levelByIdProvider(stored.highestUnlockedLevel)
          .overrideWith((ref) async => _level(stored.highestUnlockedLevel)),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders one filled heart per life', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 3, anchor: t0);
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 1))));
    await tester.pump(); // resolve level future

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
    expect(find.textContaining('Next life'), findsOneWidget);
  });

  testWidgets('shows five filled hearts and no countdown when full', (tester) async {
    await tester.pumpWidget(_harness(const PlayerProgress.initial(), t0));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsNWidgets(5));
    expect(find.textContaining('Next life'), findsNothing);
  });

  testWidgets('locks PLAY when out of lives', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 1))));
    await tester.pump();

    final playButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'PLAY'),
    );
    expect(playButton.onPressed, isNull); // disabled
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/features/home_screen_lives_test.dart`
Expected: FAIL (hearts not rendered; `LivesBar` undefined).

- [ ] **Step 3: Add the route symbols (inert until Task 7)**

In `lib/app/routes.dart`, add inside `AppRoutes`:
```dart
  static const outOfLives = '/out-of-lives';
```
and after `GameplayRouteArgs`:
```dart
final class OutOfLivesRouteArgs {
  const OutOfLivesRouteArgs(this.levelId);

  final int levelId;
}
```

- [ ] **Step 4: Implement `LivesBar`**

`lib/core/widgets/lives_bar.dart`:
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

/// Hearts row + "next life" countdown, kept live by a 1 Hz ticker. Persists a
/// regenerated life through [AppProgressController.reconcileLives].
final class LivesBar extends ConsumerStatefulWidget {
  const LivesBar({super.key});

  @override
  ConsumerState<LivesBar> createState() => _LivesBarState();
}

class _LivesBarState extends ConsumerState<LivesBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    final progress = ref.read(appProgressControllerProvider).value;
    if (progress == null) {
      return;
    }
    final now = ref.read(clockProvider)();
    final result = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    );
    if (result.lives != progress.lives ||
        result.anchor != progress.livesRegenAnchor) {
      ref.read(appProgressControllerProvider.notifier).reconcileLives(now: now);
    } else {
      setState(() {}); // refresh the countdown text
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(appProgressControllerProvider).value;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final now = ref.read(clockProvider)();
    final result = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < LivesRegen.maxLives; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i < result.lives ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.coralPulse,
                  size: 26,
                ),
              ),
          ],
        ),
        if (result.untilNextLife != null) ...[
          const SizedBox(height: 6),
          Text(
            'Next life ${formatCountdown(result.untilNextLife!)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.frost.withAlpha(180),
                ),
          ),
        ],
      ],
    );
  }
}

/// MM:SS for a non-negative countdown; shared by lives + gameplay timers.
String formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final minutes = clamped.inMinutes.toString().padLeft(2, '0');
  final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
```

- [ ] **Step 5: Wire `LivesBar` and the locked PLAY into Home**

In `lib/features/home/home_screen.dart`:
- Add imports:
```dart
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
```
- Add an `initState` to `_HomeScreenState` that reconciles on entry:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appProgressControllerProvider.notifier).reconcileLives();
      }
    });
  }
```
- In `build`, after reading `progress`, compute the reconciled life count for the PLAY gate:
```dart
    final now = ref.read(clockProvider)();
    final livesNow = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    ).lives;
```
- Insert `const SizedBox(height: 12), const LivesBar(),` immediately after the `Text('MindSpark', ...)` title.
- Replace the PLAY `FilledButton` block with a lives-aware version:
```dart
                      FilledButton(
                        onPressed: (_openingGame || livesNow <= 0)
                            ? null
                            : () => _openGame(currentLevel.id),
                        child: const Text('PLAY'),
                      ),
                      if (livesNow <= 0) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamed(
                            AppRoutes.outOfLives,
                            arguments: OutOfLivesRouteArgs(currentLevel.id),
                          ),
                          child: const Text('OUT OF LIVES'),
                        ),
                      ],
```

- [ ] **Step 6: Run — verify Home tests pass**

Run: `flutter test test/features/home_screen_lives_test.dart`
Expected: PASS. Then `flutter test test/features/app_flow_test.dart` to confirm the existing flow still passes (Home structure changed). If it asserts exact Home widgets that moved, update those finders to match; do not weaken behavioral assertions.

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/lives_bar.dart lib/features/home/home_screen.dart \
        lib/app/routes.dart test/features/home_screen_lives_test.dart
git commit -m "feat: show lives + regen countdown on Home and gate PLAY"
```

---

### Task 7: Out-of-Lives screen + route registration

**Files:**
- Create: `lib/features/out_of_lives/out_of_lives_screen.dart`
- Modify: `lib/app/app.dart` (register `AppRoutes.outOfLives`)
- Test: `test/features/out_of_lives_screen_test.dart`
- (`lib/app/routes.dart` already carries `outOfLives` + `OutOfLivesRouteArgs` from Task 6.)

**Interfaces:**
- Consumes: `appProgressControllerProvider`, `clockProvider`, `LivesRegen.reconcile`, `LivesBar`, `OutOfLivesRouteArgs`, `GameplayRouteArgs`.
- Produces: `class OutOfLivesScreen extends ConsumerStatefulWidget { const OutOfLivesScreen({super.key, required this.levelId}); final int levelId; }`. Shows the next-life countdown (via `LivesBar`), a disabled "WATCH AD (COMING SOON)" button, a "MAIN MENU" button (→ Home), and — once reconciled lives > 0 — an enabled "CONTINUE" button (→ Gameplay for `levelId`, `pushReplacement`). Reconciles on entry.

- [ ] **Step 1: Write the failing widget tests**

`test/features/out_of_lives_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/out_of_lives/out_of_lives_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider
          .overrideWithValue(InMemoryProgressRepository(stored)),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const MaterialApp(home: OutOfLivesScreen(levelId: 3)),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('shows countdown and a disabled ad button while empty', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 2))));
    await tester.pump();

    expect(find.textContaining('Next life'), findsOneWidget);
    final adButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'WATCH AD (COMING SOON)'),
    );
    expect(adButton.onPressed, isNull);
    expect(find.widgetWithText(FilledButton, 'CONTINUE'), findsNothing);
  });

  testWidgets('offers CONTINUE once a life has regenerated', (tester) async {
    // 10+ minutes elapsed on the stored anchor ⇒ one life back.
    final stored = const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(_harness(stored, t0.add(const Duration(minutes: 11))));
    await tester.pump(); // entry reconcile
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'CONTINUE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/features/out_of_lives_screen_test.dart`
Expected: FAIL ("Target of URI doesn't exist: 'out_of_lives_screen.dart'").

- [ ] **Step 3: Implement the screen**

`lib/features/out_of_lives/out_of_lives_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class OutOfLivesScreen extends ConsumerStatefulWidget {
  const OutOfLivesScreen({super.key, required this.levelId});

  final int levelId;

  @override
  ConsumerState<OutOfLivesScreen> createState() => _OutOfLivesScreenState();
}

class _OutOfLivesScreenState extends ConsumerState<OutOfLivesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appProgressControllerProvider.notifier).reconcileLives();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(appProgressControllerProvider).value;
    final now = ref.read(clockProvider)();
    final livesNow = progress == null
        ? 0
        : LivesRegen.reconcile(
            lives: progress.lives,
            anchor: progress.livesRegenAnchor,
            now: now,
          ).lives;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're out of lives",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 24),
                const LivesBar(),
                const SizedBox(height: 32),
                if (livesNow > 0)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed(
                      AppRoutes.gameplay,
                      arguments: GameplayRouteArgs(widget.levelId),
                    ),
                    child: const Text('CONTINUE'),
                  )
                else
                  const FilledButton(
                    onPressed: null,
                    child: Text('WATCH AD (COMING SOON)'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: const Text('MAIN MENU'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Register the route in `app.dart`**

In `lib/app/app.dart`, add the import and a `switch` arm in `_onGenerateRoute` (mirroring the `gameplay`/`result` arms):
```dart
import 'package:mind_spark/features/out_of_lives/out_of_lives_screen.dart';
```
```dart
    AppRoutes.outOfLives => switch (settings.arguments) {
      OutOfLivesRouteArgs(:final levelId) when levelId > 0 =>
        OutOfLivesScreen(levelId: levelId),
      _ => const _SafeRouteError(),
    },
```

- [ ] **Step 5: Run — verify it passes**

Run: `flutter test test/features/out_of_lives_screen_test.dart`
Expected: PASS. Then `flutter analyze` → no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/out_of_lives/out_of_lives_screen.dart lib/app/app.dart \
        test/features/out_of_lives_screen_test.dart
git commit -m "feat: add Out-of-Lives screen with regen countdown and continue"
```

---

### Task 8: Gameplay countdown timer — spend life, pause, guard, navigation

**Files:**
- Modify: `lib/features/gameplay/gameplay_screen.dart`
- Test: `test/features/gameplay_timer_test.dart`

**Interfaces:**
- Consumes: `levelTimeLimit` (Task 4), `AppProgressController.spendLife`/`reconcileLives` (Task 5), `LivesRegen.reconcile` (Task 2), `formatCountdown` (Task 6), `MindSparkGame.restart`, `OutOfLivesRouteArgs`/`AppRoutes.outOfLives` (Tasks 6/7).
- Produces:
  - `final levelTimerProvider = Provider<Duration Function(int size)>((_) => levelTimeLimit);` (test seam, in `gameplay_screen.dart` beside `mindSparkGameFactoryProvider`).
  - Gameplay header shows a countdown (MM:SS + linear bar) and a compact hearts row; on expiry a life is spent and either the board restarts (lives > 0) or it routes to Out-of-Lives (lives == 0); RESTART keeps remaining time; countdown pauses off-foreground; entry with 0 lives redirects.

- [ ] **Step 1: Write the failing widget tests**

`test/features/gameplay_timer_test.dart` (uses the existing `mindSparkGameFactoryProvider` seam plus a short `levelTimerProvider` override so expiry is reachable in-test):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/app.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/features/gameplay/gameplay_screen.dart';
import 'package:mind_spark/features/out_of_lives/out_of_lives_screen.dart';
import 'package:mind_spark/game/mind_spark_game.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

LevelModel _level(int id) => LevelModel(
      id: id,
      size: 5,
      points: const [
        GridPoint(x: 0, y: 0, color: 'red'),
        GridPoint(x: 4, y: 4, color: 'red'),
      ],
    );

class _FakeGame extends MindSparkGame {
  _FakeGame(LevelModel level, VoidCallback onCompleted)
      : super(level: level, onCompleted: onCompleted);
  int restarts = 0;
  @override
  void restart() => restarts++;
}

List<Override> _overrides(PlayerProgress stored, DateTime now, ProgressRepository repo,
    {int levelId = 3}) {
  return [
    progressRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => now),
    levelByIdProvider(levelId).overrideWith((ref) async => _level(levelId)),
    mindSparkGameFactoryProvider
        .overrideWithValue((level, onCompleted) => _FakeGame(level, onCompleted)),
    levelTimerProvider.overrideWithValue((_) => const Duration(seconds: 2)),
  ];
}

Widget _routedHarness(PlayerProgress stored, DateTime now, ProgressRepository repo) {
  return ProviderScope(
    overrides: _overrides(stored, now, repo),
    child: MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          AppRoutes.outOfLives => const OutOfLivesScreen(levelId: 3),
          _ => const GameplayScreen(levelId: 3),
        },
      ),
    ),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('expiry with lives left spends one and stays on the level',
      (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 3, anchor: t0);
    final repo = InMemoryProgressRepository(stored);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(stored, t0, repo),
        child: const MaterialApp(home: GameplayScreen(levelId: 3)),
      ),
    );
    await tester.pump(); // resolve providers, build game
    await tester.pump(const Duration(seconds: 3)); // elapse past the 2s limit
    await tester.pump();

    expect(repo.value.lives, 2);
    expect(find.byType(GameplayScreen), findsOneWidget); // still on the level
  });

  testWidgets('expiry on the last life routes to Out-of-Lives', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 1, anchor: t0);
    await tester.pumpWidget(_routedHarness(stored, t0, InMemoryProgressRepository(stored)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(OutOfLivesScreen), findsOneWidget);
  });

  testWidgets('entering with zero lives redirects to Out-of-Lives', (tester) async {
    final stored = const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(_routedHarness(
        stored, t0.add(const Duration(minutes: 1)), InMemoryProgressRepository(stored)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OutOfLivesScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/features/gameplay_timer_test.dart`
Expected: FAIL (`levelTimerProvider` undefined; no countdown/spend/redirect behavior).

- [ ] **Step 3: Implement the countdown in the gameplay screen**

In `lib/features/gameplay/gameplay_screen.dart`:

Add imports and the provider:
```dart
import 'dart:async';
import 'package:mind_spark/core/widgets/lives_bar.dart'; // formatCountdown
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/game/generation/level_timer.dart';

final levelTimerProvider = Provider<Duration Function(int size)>(
  (ref) => levelTimeLimit,
);
```

Make `_GameplayScreenState` a `WidgetsBindingObserver` and own the countdown. Add fields and lifecycle:
```dart
class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with WidgetsBindingObserver {
  // ... existing fields ...
  Timer? _countdown;
  Duration _timeLimit = Duration.zero;
  Duration _remaining = Duration.zero;
  bool _paused = false;
  bool _timerStarted = false;
  bool _redirectedOutOfLives = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appProgressControllerProvider.notifier).reconcileLives();
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      ref.read(appProgressControllerProvider.notifier).reconcileLives();
    }
  }

  void _startTimer(int boardSize) {
    if (_timerStarted) {
      return;
    }
    _timerStarted = true;
    _timeLimit = ref.read(levelTimerProvider)(boardSize);
    _remaining = _timeLimit;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _paused || _completionHandled || _navigated) {
      return;
    }
    setState(() {
      _remaining -= const Duration(seconds: 1);
    });
    if (_remaining <= Duration.zero) {
      _countdown?.cancel();
      unawaited(_handleTimeout());
    }
  }

  Future<void> _handleTimeout() async {
    await ref.read(appProgressControllerProvider.notifier).spendLife();
    if (!mounted) {
      return;
    }
    final livesLeft = ref.read(appProgressControllerProvider).value?.lives ?? 0;
    if (livesLeft > 0) {
      _game?.restart();
      setState(() {
        _remaining = _timeLimit;
      });
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Time's up!  -1 life")),
      );
    } else {
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.outOfLives,
        arguments: OutOfLivesRouteArgs(widget.levelId),
      );
    }
  }
```

In `build`, after resolving `level`/`progress` (keep the existing `_game != null` early return at the top of `build` so a live game is reused), add the zero-lives entry guard and start the timer once the game exists. Replace the game-creation tail:
```dart
    final now = ref.read(clockProvider)();
    final livesNow = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    ).lives;
    if (livesNow <= 0) {
      if (!_redirectedOutOfLives) {
        _redirectedOutOfLives = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.outOfLives,
              arguments: OutOfLivesRouteArgs(widget.levelId),
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = _game = ref.read(mindSparkGameFactoryProvider)(level, _handleCompletion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startTimer(level.size);
      }
    });
    return _buildGame(game);
```
Stop the timer on a win — add `_countdown?.cancel();` at the top of `_handleCompletion`.

Pass the countdown + hearts into `_GameplayView`. Extend its constructor with `required this.remaining, required this.timeLimit, required this.lives`, and in `_buildGame` pass:
```dart
      remaining: _remaining,
      timeLimit: _timeLimit,
      lives: ref.watch(appProgressControllerProvider).value?.lives ?? 0,
```
In `_GameplayView.build`, add a countdown + hearts strip above the board (below the existing header `Wrap`):
```dart
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    formatCountdown(remaining),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          color: remaining.inSeconds <= 10
                              ? AppColors.coralPulse
                              : AppColors.frost,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: timeLimit.inMilliseconds == 0
                          ? 0
                          : (remaining.inMilliseconds / timeLimit.inMilliseconds)
                              .clamp(0.0, 1.0),
                      backgroundColor: AppColors.deepCircuit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  for (var i = 0; i < 5; i++)
                    Icon(
                      i < lives ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.coralPulse,
                      size: 16,
                    ),
                ],
              ),
```
RESTART already calls `game.restart` only (board clear) and does **not** touch `_remaining`, satisfying "keeps remaining time".

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/features/gameplay_timer_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the whole suite + analyze**

Run: `flutter test && flutter analyze`
Expected: PASS, no analyzer issues. Fix any `app_flow_test.dart` finders that broke from the gameplay header change (update finders; keep behavioral assertions intact).

- [ ] **Step 6: Commit**

```bash
git add lib/features/gameplay/gameplay_screen.dart test/features/gameplay_timer_test.dart
git commit -m "feat: add per-level countdown that spends lives and gates play"
```

---

## Self-Review

**Spec coverage:**
- §1 Lives rules → Tasks 1 (cap/anchor/migration), 3 (spend only on timeout), 5 (controller), 8 (spent on expiry, not win/restart). ✓
- §1 Countdown rules (derive/expire/pause/restart-keeps-time) → Tasks 4 + 8. ✓
- §2.1 PlayerProgress schema v2 + migration → Task 1. ✓
- §2.2 LivesState.reconcile → Task 2. ✓
- §2.3 spendLife → Task 3. ✓
- §2.4 levelTimeLimit → Task 4. ✓
- §3 controller spendLife/reconcileLives + injected clock → Task 5. ✓
- §4.1 Home lives bar + locked PLAY + entry reconcile → Task 6. ✓
- §4.2 Gameplay header/timer/expiry/pause/guard → Task 8. ✓
- §4.3 Out-of-Lives screen + route → Task 7. ✓
- §5 Testing (pure, controller, widget) → each task's tests. ✓
- §6 YAGNI (ad deferred/disabled) → Task 7 disabled button. ✓

**Placeholder scan:** No TBD/TODO; every code and test step carries runnable content. ✓

**Type consistency:** `LivesRegen.reconcile`/`maxLives`/`interval`, `ReconciledLives.{lives,anchor,untilNextLife}`, `PlayerProgress.{livesRegenAnchor,copyWithLives,spendLife}`, `levelTimeLimit(int)`, `clockProvider`, `AppProgressController.{spendLife,reconcileLives}`, `levelTimerProvider`, `formatCountdown`, `OutOfLivesRouteArgs`/`AppRoutes.outOfLives`, `LivesBar`, `OutOfLivesScreen({required levelId})`, `GameplayRouteArgs` — names match across producer/consumer blocks. ✓

**Note for the implementer:** Tasks 6 and 7 are coupled by the `outOfLives` route symbols (added in Task 6 Step 3, registered in Task 7). Land them in order; the suite is green after each task.
