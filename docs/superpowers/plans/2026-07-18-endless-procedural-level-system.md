<!--
Called by: no code — this is an implementation plan document, executed by a
human/agent via superpowers:executing-plans or subagent-driven-development.
No existing plan covers procedural generation (existing: mindspark-playable-core,
progression-ui-refresh). Reads/writes no data files. Only date is the header
date (2026-07-18). User instruction: "devam et".
-->

# Endless Procedural Level System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate deterministic, guaranteed-solvable puzzles from level 11 onward so play never ends, keeping hand-authored levels 1–10.

**Architecture:** A `LevelSource` abstraction returns a `LevelModel` for any id; a `CompositeLevelSource` serves ids ≤ 10 from the existing `AssetLevelRepository` and ids > 10 from a `ProceduralLevelGenerator`. The generator partitions the grid into non-crossing colour paths (a full-cover tiling that is itself a witness solution, so every puzzle is winnable). Screens are refactored from a materialized level list to fetch-by-id.

**Tech Stack:** Flutter, Dart, flutter_riverpod, flutter_test.

## Global Constraints

- Dart SDK floor `^3.12.2`; Flutter (per `pubspec.yaml`).
- Render palette is exactly these 6 colours, in this order: `red, blue, green, yellow, purple, orange`. Generated levels must use only these.
- `LevelModel` invariants (enforced by `LevelModel.fromJson`): `size >= 2`; every colour has exactly two endpoints; coordinates unique and inside the `size × size` grid.
- Curated levels 1–10 in `assets/levels/levels.json` are NOT modified by this plan.
- Deterministic: `ProceduralLevelGenerator.generate(id)` is a pure function of `id` — two calls return identical data.
- Every generated level is guaranteed solvable (its witness cover is a legal solution under the rules in `lib/game/domain/puzzle_session.dart`).
- Curated boundary constant: `curatedMax = 10`. Generation applies to `id > curatedMax`.
- After each task: run the task's tests, then `flutter analyze` (expect "No issues found!"), then commit.

---

### Task 1: Difficulty curve

**Files:**
- Create: `lib/game/generation/level_difficulty.dart`
- Test: `test/game/generation/level_difficulty_test.dart`

**Interfaces:**
- Produces: `class LevelDifficulty { final int size; final int colors; final int minLen; }` and `LevelDifficulty difficultyForLevel(int id)` (defined for `id >= 11`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/generation/level_difficulty.dart';

void main() {
  test('matches the approved ramp-then-plateau bands', () {
    expect(difficultyForLevel(11), const LevelDifficulty(size: 5, colors: 4, minLen: 3));
    expect(difficultyForLevel(19), const LevelDifficulty(size: 6, colors: 5, minLen: 3));
    expect(difficultyForLevel(23), const LevelDifficulty(size: 6, colors: 5, minLen: 4));
    expect(difficultyForLevel(27), const LevelDifficulty(size: 7, colors: 6, minLen: 4));
    expect(difficultyForLevel(35), const LevelDifficulty(size: 8, colors: 6, minLen: 5));
    expect(difficultyForLevel(47), const LevelDifficulty(size: 8, colors: 6, minLen: 6));
  });

  test('is monotonic and plateaus at 8/6/6', () {
    var prev = difficultyForLevel(11);
    for (var id = 12; id <= 400; id++) {
      final d = difficultyForLevel(id);
      expect(d.size, greaterThanOrEqualTo(prev.size));
      expect(d.colors, greaterThanOrEqualTo(prev.colors));
      expect(d.minLen, greaterThanOrEqualTo(prev.minLen));
      expect(d.size, lessThanOrEqualTo(8));
      expect(d.colors, lessThanOrEqualTo(6));
      expect(d.minLen, lessThanOrEqualTo(6));
      prev = d;
    }
    expect(difficultyForLevel(400), const LevelDifficulty(size: 8, colors: 6, minLen: 6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/generation/level_difficulty_test.dart`
Expected: FAIL — `level_difficulty.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
/// Difficulty parameters for a procedurally generated level.
class LevelDifficulty {
  const LevelDifficulty({
    required this.size,
    required this.colors,
    required this.minLen,
  });

  final int size;
  final int colors;
  final int minLen;

  @override
  bool operator ==(Object other) =>
      other is LevelDifficulty &&
      other.size == size &&
      other.colors == colors &&
      other.minLen == minLen;

  @override
  int get hashCode => Object.hash(size, colors, minLen);

  @override
  String toString() => 'LevelDifficulty(size: $size, colors: $colors, minLen: $minLen)';
}

/// First procedurally generated level id (ids <= 10 are hand-authored).
const int kFirstGeneratedLevel = 11;

/// Monotone, capped difficulty curve. Defined for [id] >= [kFirstGeneratedLevel].
LevelDifficulty difficultyForLevel(int id) {
  final t = id - kFirstGeneratedLevel; // id 11 -> 0
  final size = (5 + t ~/ 8).clamp(5, 8);
  final colors = (4 + t ~/ 8).clamp(4, 6);
  final minLen = (3 + t ~/ 12).clamp(3, 6);
  return LevelDifficulty(size: size, colors: colors, minLen: minLen);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game/generation/level_difficulty_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/game/generation/level_difficulty.dart test/game/generation/level_difficulty_test.dart
git commit -m "feat: add procedural level difficulty curve"
```

---

### Task 2: Procedural level generator

**Files:**
- Create: `lib/game/generation/procedural_level_generator.dart`
- Test: `test/game/generation/procedural_level_generator_test.dart`

**Interfaces:**
- Consumes: `difficultyForLevel(int)`, `kFirstGeneratedLevel` (Task 1); `LevelModel`, `GridPoint` (`lib/models/level_model.dart`); `PuzzleSession`, `GridPosition` (`lib/game/domain/`).
- Produces:
  - `class GeneratedLevel { final LevelModel level; final List<List<Point<int>>> solution; }`
  - `class ProceduralLevelGenerator { const ProceduralLevelGenerator({int seedSalt}); GeneratedLevel generate(int id); }`
  - Path order in `solution` matches colour order in `level.points` (palette order).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/grid_position.dart';
import 'package:mind_spark/game/domain/puzzle_session.dart';
import 'package:mind_spark/game/generation/level_difficulty.dart';
import 'package:mind_spark/game/generation/procedural_level_generator.dart';

const _palette = {'red', 'blue', 'green', 'yellow', 'purple', 'orange'};

void main() {
  const generator = ProceduralLevelGenerator();

  test('is deterministic for a given id', () {
    final a = generator.generate(42).level;
    final b = generator.generate(42).level;
    expect(a.size, b.size);
    expect(a.points.map((p) => '${p.x},${p.y},${p.color}'),
        b.points.map((p) => '${p.x},${p.y},${p.color}'));
  });

  test('produces structurally valid levels for ids 11..200', () {
    for (var id = kFirstGeneratedLevel; id <= 200; id++) {
      final level = generator.generate(id).level;
      final want = difficultyForLevel(id);
      expect(level.id, id);
      expect(level.size, want.size);

      final coords = <String>{};
      final counts = <String, int>{};
      for (final p in level.points) {
        expect(p.x, inInclusiveRange(0, level.size - 1));
        expect(p.y, inInclusiveRange(0, level.size - 1));
        expect(_palette, contains(p.color));
        expect(coords.add('${p.x},${p.y}'), isTrue, reason: 'dup coord at id $id');
        counts.update(p.color, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final entry in counts.entries) {
        expect(entry.value, 2, reason: 'colour ${entry.key} not a pair at id $id');
      }
    }
  });

  test('every generated level is solvable via its witness (real engine)', () {
    for (final id in [11, 19, 27, 35, 47, 88, 150]) {
      final generated = generator.generate(id);
      final session = PuzzleSession(level: generated.level);
      for (final path in generated.solution) {
        expect(session.startPath(GridPosition(path.first.x, path.first.y)), isTrue);
        for (final cell in path.skip(1)) {
          expect(session.extendPath(GridPosition(cell.x, cell.y)), isTrue,
              reason: 'blocked extend at id $id');
        }
        session.endPath();
      }
      expect(session.isComplete, isTrue, reason: 'id $id not complete');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/generation/procedural_level_generator_test.dart`
Expected: FAIL — `procedural_level_generator.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:math';

import 'package:mind_spark/game/generation/level_difficulty.dart';
import 'package:mind_spark/models/level_model.dart';

/// A generated level plus its witness solution (one path per colour, in
/// palette order). The witness is a legal solution, so the level is solvable.
class GeneratedLevel {
  const GeneratedLevel({required this.level, required this.solution});

  final LevelModel level;
  final List<List<Point<int>>> solution;
}

/// Deterministically generates solvable levels by partitioning the board into
/// non-crossing colour paths that cover every cell.
class ProceduralLevelGenerator {
  const ProceduralLevelGenerator({this.seedSalt = 0x9E3779B9});

  final int seedSalt;

  static const List<String> _palette = [
    'red', 'blue', 'green', 'yellow', 'purple', 'orange',
  ];

  static const List<Point<int>> _deltas = [
    Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1),
  ];

  GeneratedLevel generate(int id) {
    final base = difficultyForLevel(id);
    final rng = Random(id ^ seedSalt);
    // Deterministic relaxation: hold the seed, relax minLen fully, then colours,
    // until a cover is found. Guarantees termination with a reproducible result.
    for (var colors = base.colors; colors >= 2; colors--) {
      for (var minLen = base.minLen; minLen >= 2; minLen--) {
        final cover = _tryCover(base.size, colors, minLen, rng);
        if (cover != null) {
          return _toGeneratedLevel(id, base.size, cover);
        }
      }
    }
    throw StateError('failed to generate level $id');
  }

  List<List<Point<int>>>? _tryCover(int size, int k, int minLen, Random rng) {
    final avg = size * size / k;
    final maxLen = max(minLen + 1, (avg * 1.6).round());
    for (var attempt = 0; attempt < 4000; attempt++) {
      final cover = _oneCover(size, k, minLen, maxLen, rng);
      if (cover != null) {
        return cover;
      }
    }
    return null;
  }

  List<List<Point<int>>>? _oneCover(
      int size, int k, int minLen, int maxLen, Random rng) {
    final uncovered = <Point<int>>{
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++) Point(x, y),
    };
    final paths = <List<Point<int>>>[];
    while (uncovered.isNotEmpty) {
      if (paths.length >= k) {
        return null;
      }
      final start = uncovered.elementAt(rng.nextInt(uncovered.length));
      final path = <Point<int>>[start];
      uncovered.remove(start);
      var cur = start;
      final target = minLen + rng.nextInt(maxLen - minLen + 1);
      while (path.length < target) {
        final opts = _neighbors(cur, size).where(uncovered.contains).toList();
        if (opts.isEmpty) {
          break;
        }
        final next = opts[rng.nextInt(opts.length)];
        path.add(next);
        uncovered.remove(next);
        cur = next;
      }
      if (path.length < minLen) {
        return null;
      }
      paths.add(path);
    }
    if (paths.length != k) {
      return null;
    }
    var longest = 0;
    for (final p in paths) {
      longest = max(longest, p.length);
    }
    if (longest > maxLen + 1) {
      return null;
    }
    return paths;
  }

  Iterable<Point<int>> _neighbors(Point<int> c, int size) sync* {
    for (final d in _deltas) {
      final nx = c.x + d.x;
      final ny = c.y + d.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        yield Point(nx, ny);
      }
    }
  }

  GeneratedLevel _toGeneratedLevel(
      int id, int size, List<List<Point<int>>> cover) {
    final points = <GridPoint>[];
    for (var i = 0; i < cover.length; i++) {
      final color = _palette[i];
      final path = cover[i];
      final a = path.first;
      final b = path.last;
      points.add(GridPoint(x: a.x, y: a.y, color: color));
      points.add(GridPoint(x: b.x, y: b.y, color: color));
    }
    final level = LevelModel(
      id: id,
      size: size,
      points: List<GridPoint>.unmodifiable(points),
    );
    return GeneratedLevel(level: level, solution: cover);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game/generation/procedural_level_generator_test.dart`
Expected: PASS (3 tests). If the solvability test ever blocks, it is a real defect — do not weaken the assertion.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/game/generation/procedural_level_generator.dart test/game/generation/procedural_level_generator_test.dart
git commit -m "feat: add deterministic procedural level generator"
```

---

### Task 3: LevelSource + CompositeLevelSource

**Files:**
- Create: `lib/repositories/level_source.dart`
- Create: `lib/repositories/composite_level_source.dart`
- Test: `test/repositories/composite_level_source_test.dart`

**Interfaces:**
- Consumes: `LevelRepository` (`lib/repositories/level_repository.dart`), `ProceduralLevelGenerator` (Task 2), `LevelModel`.
- Produces:
  - `abstract interface class LevelSource { Future<LevelModel> levelById(int id); }`
  - `class CompositeLevelSource implements LevelSource { CompositeLevelSource({required LevelRepository repository, ProceduralLevelGenerator generator, int curatedMax}); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/composite_level_source.dart';
import 'package:mind_spark/repositories/level_repository.dart';

class _FakeRepo implements LevelRepository {
  int? requestedId;
  @override
  Future<LevelModel> levelById(int id) async {
    requestedId = id;
    return LevelModel(id: id, size: 5, points: const [
      GridPoint(x: 0, y: 0, color: 'red'),
      GridPoint(x: 4, y: 4, color: 'red'),
    ]);
  }

  @override
  Future<List<LevelModel>> loadLevels() async => const [];
}

void main() {
  test('serves ids <= curatedMax from the repository', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(3);
    expect(level.id, 3);
    expect(repo.requestedId, 3);
  });

  test('serves ids > curatedMax from the generator', () async {
    final repo = _FakeRepo();
    final source = CompositeLevelSource(repository: repo, curatedMax: 10);
    final level = await source.levelById(25);
    expect(level.id, 25);
    expect(repo.requestedId, isNull); // repository not touched
    expect(level.size, 6); // difficulty band for id 25
  });

  test('rejects non-positive ids', () async {
    final source = CompositeLevelSource(repository: _FakeRepo());
    expect(() => source.levelById(0), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/composite_level_source_test.dart`
Expected: FAIL — sources do not exist.

- [ ] **Step 3: Write minimal implementation**

`lib/repositories/level_source.dart`:

```dart
import 'package:mind_spark/models/level_model.dart';

/// Supplies a single [LevelModel] for any positive level id.
abstract interface class LevelSource {
  Future<LevelModel> levelById(int id);
}
```

`lib/repositories/composite_level_source.dart`:

```dart
import 'package:mind_spark/game/generation/procedural_level_generator.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/repositories/level_repository.dart';
import 'package:mind_spark/repositories/level_source.dart';

/// Serves curated levels from [repository] and generates the rest.
class CompositeLevelSource implements LevelSource {
  CompositeLevelSource({
    required this.repository,
    this.generator = const ProceduralLevelGenerator(),
    this.curatedMax = 10,
  });

  final LevelRepository repository;
  final ProceduralLevelGenerator generator;
  final int curatedMax;

  @override
  Future<LevelModel> levelById(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be positive');
    }
    if (id <= curatedMax) {
      return repository.levelById(id);
    }
    return generator.generate(id).level;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/composite_level_source_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/repositories/level_source.dart lib/repositories/composite_level_source.dart test/repositories/composite_level_source_test.dart
git commit -m "feat: route curated and generated levels through a LevelSource"
```

---

### Task 4: Swap providers to fetch-by-id

Removes the finite `levelsProvider` and introduces per-id fetching. Several screens and three test files import `levelsProvider`, so this change and the four screen migrations (Tasks 5–8) form ONE red→green cycle with a single commit at the end of Task 8.

**Files:**
- Modify: `lib/app/app.dart:17-25`
- Modify tests: `test/widget_test.dart`, `test/features/app_flow_test.dart`, `test/features/persistence_flow_test.dart`

> Execution note: run Tasks 4→8 as one continuous unit. The steps are split for clarity, but the build only returns green after all screens are migrated. If dispatched to subagents, hand Tasks 4–8 to a single subagent.

- [ ] **Step 1: Replace the provider block in `lib/app/app.dart`**

Replace the `levelsProvider` definition (lines 17–25) with:

```dart
import 'package:mind_spark/repositories/composite_level_source.dart';
import 'package:mind_spark/repositories/level_source.dart';
// keep existing imports; drop the now-unused LevelLoadException import if the
// analyzer flags it.

final levelSourceProvider = Provider<LevelSource>(
  (ref) => CompositeLevelSource(
    repository: ref.read(levelRepositoryProvider),
  ),
);

final levelByIdProvider = FutureProvider.family<LevelModel, int>(
  (ref, id) => ref.read(levelSourceProvider).levelById(id),
);
```

Keep `levelRepositoryProvider` unchanged. Delete `levelsProvider` entirely.

- [ ] **Step 2: Migrate the three test files**

Open each test file and update its provider usage:
- Replace any `levelsProvider.overrideWith(...)` with an override of `levelRepositoryProvider` returning a fake `LevelRepository` whose `levelById(id)` serves the ids the flow exercises (levels 1–3 here). If a test already overrides `levelRepositoryProvider`, just remove the now-invalid `levelsProvider` import/usage.
- Replace any `ref.read(levelsProvider)` / `ref.watch(levelsProvider)` with the specific `levelByIdProvider(id)` the assertion needs.
- Remove the `levelsProvider` import.

- [ ] **Step 3–5:** implemented in Tasks 5–8; run/commit at the end of Task 8.

---

### Task 5: Home fetches the current level by id

**Files:**
- Modify: `lib/features/home/home_screen.dart:20-34`

**Interfaces:**
- Consumes: `levelByIdProvider` (Task 4), `appProgressControllerProvider`.

- [ ] **Step 1: Replace the list lookup with a single fetch**

Replace lines 20–34 (`final levels = ref.watch(levelsProvider)...` through `final currentLevel = levels[currentLevelIndex];`) with:

```dart
final progress = ref.watch(appProgressControllerProvider).requireValue;
final levelState = ref.watch(levelByIdProvider(progress.highestUnlockedLevel));
final currentLevel = levelState.valueOrNull;
if (levelState.hasError) {
  return _HomeContentError(
    onRetry: () {
      ref.invalidate(levelByIdProvider(progress.highestUnlockedLevel));
      ref.invalidate(appProgressControllerProvider);
    },
  );
}
if (currentLevel == null) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

The file already imports `app.dart` (which now exports `levelByIdProvider`), so no import change is needed. The rest of the widget (`currentLevel.id`, `progress.totalScore`) is unchanged.

- [ ] **Step 2:** Covered by the Task 8 build/test run.

---

### Task 6: Gameplay fetches by id and computes the next id arithmetically

**Files:**
- Modify: `lib/features/gameplay/gameplay_screen.dart:40-70`
- Modify: the `_nextLevelId(levels, id)` helper and its call site in `_handleCompletion` (around line 101).

**Interfaces:**
- Consumes: `levelByIdProvider`, `appProgressControllerProvider`.

- [ ] **Step 1: Replace the list-based build body (lines 40–70)**

```dart
final progressState = ref.watch(appProgressControllerProvider);
final levelState = ref.watch(levelByIdProvider(widget.levelId));
final existingGame = _game;
if (existingGame != null) {
  return _buildGame(existingGame);
}
if (levelState.hasError || progressState.hasError) {
  return const _GameplayLoadError();
}
final level = levelState.value;
final progress = progressState.value;
if (level == null || progress == null) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
if (widget.levelId < 1 || widget.levelId > progress.highestUnlockedLevel) {
  return const _GameplayLoadError();
}
final game = _game = ref.read(mindSparkGameFactoryProvider)(
  level,
  _handleCompletion,
);
return _buildGame(game);
```

- [ ] **Step 2: Replace next-level computation in `_handleCompletion`**

Find `final levels = ref.read(levelsProvider).requireValue;` and `final nextLevelId = _nextLevelId(levels, widget.levelId);` (around lines 90–101) and replace those two lines with:

```dart
final nextLevelId = widget.levelId + 1; // endless: always a next level
```

Delete the now-unused `_nextLevelId(...)` helper method.

- [ ] **Step 3: Covered by the Task 8 build/test run.**

---

### Task 7: Result always advances, plus a HOME exit

**Files:**
- Modify: `lib/features/result/result_screen.dart:27-37` and `:97-104`

**Interfaces:**
- Consumes: `appProgressControllerProvider`.

- [ ] **Step 1: Replace the list-based next-level lookup (lines 27–37)**

```dart
final totalScore = ref
    .watch(appProgressControllerProvider)
    .requireValue
    .totalScore;
final nextLevelId = widget.levelId + 1; // endless
```

Remove the `levels`/`index` reads and the `if (index < 0) return const _ResultLoadError();` guard. Delete the `_ResultLoadError` class if it is no longer referenced.

- [ ] **Step 2: Add a secondary HOME button (replace the single FilledButton, lines 97–104)**

```dart
FilledButton(
  onPressed: _navigating ? null : () => _navigate(nextLevelId),
  child: const Text('NEXT LEVEL'),
),
const SizedBox(height: 12),
TextButton(
  onPressed: _navigating
      ? null
      : () => Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
  child: const Text('HOME'),
),
```

`AppRoutes` is already imported in this file.

- [ ] **Step 3: Covered by the Task 8 build/test run.**

---

### Task 8: Splash gates on the current level; gameplay exit control; run & commit

**Files:**
- Modify: `lib/features/splash/splash_screen.dart:20-40, 81-85`
- Modify: `lib/features/gameplay/gameplay_screen.dart` — the `_GameplayView` header near the `RESTART` button (around lines 235–245).

- [ ] **Step 1: Splash — watch the current level instead of the list**

Replace lines 21–22:

```dart
final progress = ref.watch(appProgressControllerProvider);
final currentId = progress.valueOrNull?.highestUnlockedLevel ?? 1;
final levels = ref.watch(levelByIdProvider(currentId));
```

In the post-frame callback replace `ref.read(levelsProvider)` (line 30) with `ref.read(levelByIdProvider(currentId))`. In `_retry` (line 83), read the id locally and invalidate the family member:

```dart
void _retry() {
  _navigationScheduled = false;
  final id = ref.read(appProgressControllerProvider).valueOrNull?.highestUnlockedLevel ?? 1;
  ref.invalidate(levelByIdProvider(id));
  ref.invalidate(appProgressControllerProvider);
}
```

- [ ] **Step 2: Gameplay — add a HOME icon to the `_GameplayView` header**

In the header `Row` containing the level title and `RESTART` button, add:

```dart
IconButton(
  icon: const Icon(Icons.home_rounded),
  color: AppColors.frost,
  onPressed: () => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
),
```

Ensure the file imports `package:mind_spark/app/routes.dart` and the theme (`AppColors`); add whichever import is missing.

- [ ] **Step 3: Run the full suite**

Run: `flutter analyze`
Expected: No issues found!

Run: `flutter test`
Expected: All tests pass (existing 105 + the new generation/source tests).

- [ ] **Step 4: Commit Tasks 4–8 together**

```bash
git add lib/app/app.dart lib/features test/widget_test.dart test/features/app_flow_test.dart test/features/persistence_flow_test.dart
git commit -m "refactor: fetch levels by id for endless progression"
```

---

### Task 9: End-to-end endless-progression test

**Files:**
- Create: `test/features/endless_progression_test.dart`

**Interfaces:**
- Consumes: `CompositeLevelSource` (Task 3), `PlayerProgress` (`lib/models/player_progress.dart`), a fake `LevelRepository` for ids 1–10.

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/models/level_model.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/composite_level_source.dart';
import 'package:mind_spark/repositories/level_repository.dart';

class _CuratedRepo implements LevelRepository {
  @override
  Future<LevelModel> levelById(int id) async => LevelModel(
        id: id,
        size: 5,
        points: const [
          GridPoint(x: 0, y: 0, color: 'red'),
          GridPoint(x: 4, y: 4, color: 'red'),
        ],
      );
  @override
  Future<List<LevelModel>> loadLevels() async => const [];
}

void main() {
  test('a player advances past the curated set to level 60', () async {
    final source = CompositeLevelSource(repository: _CuratedRepo());
    var progress = const PlayerProgress.initial();

    for (var id = 1; id <= 60; id++) {
      final level = await source.levelById(id); // must not throw for any id
      expect(level.id, id);
      progress = progress.completeLevel(levelId: id, nextLevelId: id + 1);
    }

    expect(progress.highestUnlockedLevel, 61);
    expect(progress.completedLevelIds.length, 60);
    expect(progress.totalScore, 6000);
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/features/endless_progression_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze
git add test/features/endless_progression_test.dart
git commit -m "test: verify endless progression past the curated set"
```

---

## Self-Review

**Spec coverage:**
- §2 architecture (LevelSource/CompositeLevelSource, provider refactor) → Tasks 3, 4.
- §3 generation algorithm + solvability + deterministic relaxation → Task 2.
- §4 difficulty curve → Task 1.
- §5 UI (result always NEXT LEVEL + HOME, gameplay exit, home/splash by id) → Tasks 5–8.
- §6 testing (determinism, validity, engine solvability, monotonicity, routing, progression) → Tasks 1, 2, 3, 9.
- §7 future phases → intentionally out of scope for this plan.

**Placeholder scan:** No TBD/TODO; every code step shows full code. The only deferred item (timer stopwatch-vs-countdown) is a future phase, not part of any task here.

**Type consistency:** `LevelDifficulty{size,colors,minLen}`, `difficultyForLevel`, `kFirstGeneratedLevel`, `GeneratedLevel{level,solution}`, `ProceduralLevelGenerator.generate`, `LevelSource.levelById`, `CompositeLevelSource(repository,generator,curatedMax)`, `levelSourceProvider`, `levelByIdProvider` are used consistently across tasks. `GridPoint`/`LevelModel`/`GridPosition`/`PuzzleSession` match existing signatures.

**Known risk:** Tasks 4–8 leave the build red mid-flight; they are executed and committed as one unit (noted in Task 4).
