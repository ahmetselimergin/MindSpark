# MindSpark Playable Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Android-first Flutter + Flame vertical slice with three playable 5×5 Color Connect levels, tested puzzle rules, idempotent local progress, and a complete Home → Game → Result flow.

**Architecture:** Flutter owns app navigation and screens, pure Dart owns level validation and active puzzle state, and Flame adapts gestures/rendering to immutable domain snapshots. Riverpod supplies application dependencies and progress state; Hive is hidden behind a repository so tests use an in-memory implementation.

**Tech Stack:** Flutter 3.44.5, Dart 3.12.2, Flame, flutter_riverpod, Hive CE/hive_ce_flutter, flutter_test

## Global Constraints

- Android is the first target; the playable core must work offline.
- A level completes when all same-colour endpoint pairs are connected; full-grid coverage is not required.
- Paths move orthogonally and may not overlap, cross, or enter another colour's endpoint.
- First completion awards exactly 100 points and unlocks the next level; replay is idempotent.
- Restart does not consume lives; lives remain persisted but inactive.
- Domain files must not import Flutter, Flame, Hive, Riverpod, ads, or analytics.
- Do not add Firebase, AdMob, audio, hints, bulk generation, or speculative abstractions in this increment.
- Every behaviour change follows red → green → refactor and each task ends with its focused tests passing.

---

## File Map

- `pubspec.yaml`: Flutter dependencies and level asset registration.
- `lib/main.dart`: storage initialization and application entry point.
- `lib/app/app.dart`: `MaterialApp`, providers, theme, and route generation.
- `lib/app/routes.dart`: route names and typed route arguments.
- `lib/core/theme/app_theme.dart`: MindSpark colours and Material theme.
- `lib/models/level_model.dart`: immutable level/endpoint parsing and validation.
- `lib/models/player_progress.dart`: normalized, serializable progress record.
- `lib/repositories/level_repository.dart`: level source contract and typed failures.
- `lib/repositories/asset_level_repository.dart`: bundled JSON implementation.
- `lib/repositories/progress_repository.dart`: progress persistence contract and in-memory fake.
- `lib/repositories/hive_progress_repository.dart`: Hive implementation.
- `lib/state/app_progress_controller.dart`: Riverpod progress transitions.
- `lib/game/domain/grid_position.dart`: grid value object.
- `lib/game/domain/path_state.dart`: immutable colour path.
- `lib/game/domain/puzzle_snapshot.dart`: renderable immutable board state.
- `lib/game/domain/puzzle_session.dart`: gesture commands, occupancy rules, completion.
- `lib/game/mind_spark_game.dart`: Flame board rendering and pointer adapter.
- `lib/features/splash/splash_screen.dart`: initialization state and retry UI.
- `lib/features/home/home_screen.dart`: current level/score and Play navigation.
- `lib/features/gameplay/gameplay_screen.dart`: `GameWidget`, level header, restart.
- `lib/features/result/result_screen.dart`: award/total and next/home navigation.
- `assets/levels/levels.json`: three hand-authored, valid 5×5 levels.
- `test/**`: focused unit, widget, and integration tests matching each task.

---

### Task 1: Scaffold the Flutter project and dependencies

**Files:**
- Create: Flutter generated platform/project files using `flutter create`
- Modify: `pubspec.yaml`
- Preserve: `docs/`, `tasks/`, `.git/`

**Interfaces:**
- Produces: a compilable Flutter app with `flame`, `flutter_riverpod`, `hive_ce`, and `hive_ce_flutter` available.

- [ ] **Step 1: Generate only missing Flutter project files**

Run:

```bash
flutter create --platforms=android --org com.mindspark --project-name mind_spark .
```

Expected: exit 0; existing `docs/` and `tasks/` remain untouched.

- [ ] **Step 2: Add runtime dependencies**

Run:

```bash
flutter pub add flame flutter_riverpod hive_ce hive_ce_flutter
```

Expected: exit 0 and dependency entries added to `pubspec.yaml`.

- [ ] **Step 3: Register level assets**

Modify the Flutter section of `pubspec.yaml` to contain:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/levels/levels.json
```

- [ ] **Step 4: Verify the generated baseline**

Run:

```bash
flutter analyze
flutter test
```

Expected: both commands exit 0 before feature code begins.

- [ ] **Step 5: Commit**

```bash
git add android lib test pubspec.yaml pubspec.lock analysis_options.yaml .gitignore .metadata README.md
git commit -m "build: scaffold MindSpark Flutter app"
```

---

### Task 2: Level model and bundled repository

**Files:**
- Create: `lib/models/level_model.dart`
- Create: `lib/repositories/level_repository.dart`
- Create: `lib/repositories/asset_level_repository.dart`
- Create: `assets/levels/levels.json`
- Create: `test/models/level_model_test.dart`
- Create: `test/repositories/asset_level_repository_test.dart`

**Interfaces:**
- Produces: `GridPoint`, `LevelModel.fromJson(Map<String, Object?>)`, `LevelRepository.loadLevels()`, `LevelRepository.levelById(int)`.
- Produces errors: `LevelFormatException(message)` and `LevelLoadException(message, cause)`.

- [ ] **Step 1: Write failing model validation tests**

Create tests that parse one valid model and independently reject out-of-bounds points, duplicate coordinates, duplicate/non-positive IDs at repository level, empty points, and colours without exactly two endpoints. Core expectation:

```dart
test('parses a valid 5x5 level', () {
  final level = LevelModel.fromJson({
    'id': 1,
    'size': 5,
    'points': [
      {'x': 0, 'y': 0, 'color': 'red'},
      {'x': 4, 'y': 4, 'color': 'red'},
    ],
  });
  expect(level.id, 1);
  expect(level.points.singleWhere((point) => point.x == 4).color, 'red');
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/models/level_model_test.dart`

Expected: FAIL because `LevelModel` does not exist.

- [ ] **Step 3: Implement immutable parsing and validation**

Implement these public shapes:

```dart
final class GridPoint {
  const GridPoint({required this.x, required this.y, required this.color});
  final int x;
  final int y;
  final String color;
}

final class LevelModel {
  const LevelModel({required this.id, required this.size, required this.points});
  factory LevelModel.fromJson(Map<String, Object?> json);
  final int id;
  final int size;
  final List<GridPoint> points;
}

final class LevelFormatException implements FormatException {
  const LevelFormatException(this.message);
  @override final String message;
  @override Object? get source => null;
  @override int? get offset => null;
}
```

Return unmodifiable point lists and descriptive failures naming the invalid field.

- [ ] **Step 4: Verify model GREEN**

Run: `flutter test test/models/level_model_test.dart`

Expected: PASS.

- [ ] **Step 5: Write failing repository tests**

Use a `FakeAssetBundle`/`TestAssetBundle` to cover successful list loading, duplicate IDs, malformed JSON, and missing level lookup:

```dart
final repository = AssetLevelRepository(bundle: bundle, assetPath: 'levels.json');
final levels = await repository.loadLevels();
expect(levels.map((level) => level.id), [1, 2, 3]);
expect(await repository.levelById(2), isA<LevelModel>());
```

- [ ] **Step 6: Verify repository RED**

Run: `flutter test test/repositories/asset_level_repository_test.dart`

Expected: FAIL because repository types do not exist.

- [ ] **Step 7: Implement the repository and three assets**

Use these contracts:

```dart
abstract interface class LevelRepository {
  Future<List<LevelModel>> loadLevels();
  Future<LevelModel> levelById(int id);
}

final class LevelLoadException implements Exception {
  const LevelLoadException(this.message, [this.cause]);
  final String message;
  final Object? cause;
}
```

`AssetLevelRepository` caches a validated, ID-sorted unmodifiable list after the first load. Add three solvable 5×5 levels to `assets/levels/levels.json`.

- [ ] **Step 8: Verify and commit**

Run:

```bash
flutter test test/models/level_model_test.dart test/repositories/asset_level_repository_test.dart
flutter analyze
git add lib/models lib/repositories/level_repository.dart lib/repositories/asset_level_repository.dart assets test/models test/repositories/asset_level_repository_test.dart
git commit -m "feat: add validated bundled levels"
```

Expected: tests and analyzer exit 0; commit succeeds.

---

### Task 3: Pure Dart puzzle session

**Files:**
- Create: `lib/game/domain/grid_position.dart`
- Create: `lib/game/domain/path_state.dart`
- Create: `lib/game/domain/puzzle_snapshot.dart`
- Create: `lib/game/domain/puzzle_session.dart`
- Create: `test/game/domain/puzzle_session_test.dart`

**Interfaces:**
- Consumes: `LevelModel` and `GridPoint`.
- Produces: `PuzzleSession.startPath`, `extendPath`, `endPath`, `restart`, `snapshot`, `isComplete`.
- Produces: one-shot `onCompleted` callback.

- [ ] **Step 1: Write RED tests for starting and extending**

Cover endpoint-only starts, orthogonal adjacency, bounds, occupied cells, foreign endpoints, matching endpoint connection, and immutable snapshots. Example:

```dart
final session = PuzzleSession(level: level);
expect(session.startPath(const GridPosition(0, 0)), isTrue);
expect(session.extendPath(const GridPosition(1, 0)), isTrue);
expect(session.extendPath(const GridPosition(1, 1)), isTrue);
expect(session.snapshot.paths['red']!.cells,
    const [GridPosition(0, 0), GridPosition(1, 0), GridPosition(1, 1)]);
```

- [ ] **Step 2: Verify first RED**

Run: `flutter test test/game/domain/puzzle_session_test.dart`

Expected: FAIL because domain session files do not exist.

- [ ] **Step 3: Implement value objects and minimal path extension**

Use these public APIs:

```dart
final class GridPosition {
  const GridPosition(this.x, this.y);
  final int x;
  final int y;
  int manhattanDistanceTo(GridPosition other) =>
      (x - other.x).abs() + (y - other.y).abs();
}

final class PathState {
  const PathState({required this.color, required this.cells, required this.connected});
  final String color;
  final List<GridPosition> cells;
  final bool connected;
}

final class PuzzleSnapshot {
  const PuzzleSnapshot({required this.size, required this.paths, required this.isComplete});
  final int size;
  final Map<String, PathState> paths;
  final bool isComplete;
}
```

Snapshot lists/maps must be unmodifiable copies.

- [ ] **Step 4: Verify first GREEN**

Run: `flutter test test/game/domain/puzzle_session_test.dart`

Expected: starting/extension tests PASS.

- [ ] **Step 5: Add RED tests for editing semantics**

Add independent tests for immediate backtracking, replacing an existing same-colour path from either endpoint, release-before-connection cancellation, restart, and rejected non-adjacent skipped cells.

- [ ] **Step 6: Implement editing semantics and verify GREEN**

Required public session shape:

```dart
final class PuzzleSession {
  PuzzleSession({required LevelModel level, void Function()? onCompleted});
  PuzzleSnapshot get snapshot;
  bool get isComplete;
  bool startPath(GridPosition position);
  bool extendPath(GridPosition position);
  void endPath();
  void restart();
}
```

Run: `flutter test test/game/domain/puzzle_session_test.dart`

Expected: all editing tests PASS.

- [ ] **Step 7: Add RED tests for completion semantics**

Connect all colour pairs and assert that input locks and `onCompleted` fires exactly once. Restart must unlock input and allow one new completion emission.

- [ ] **Step 8: Implement completion and verify all domain tests**

Run:

```bash
flutter test test/game/domain/puzzle_session_test.dart
flutter analyze
git add lib/game/domain test/game/domain
git commit -m "feat: implement Color Connect puzzle rules"
```

Expected: tests and analyzer exit 0; commit succeeds.

---

### Task 4: Player progress and persistence

**Files:**
- Create: `lib/models/player_progress.dart`
- Create: `lib/repositories/progress_repository.dart`
- Create: `lib/repositories/hive_progress_repository.dart`
- Create: `lib/state/app_progress_controller.dart`
- Create: `test/models/player_progress_test.dart`
- Create: `test/state/app_progress_controller_test.dart`
- Create: `test/repositories/hive_progress_repository_test.dart`

**Interfaces:**
- Produces: normalized `PlayerProgress`, `ProgressRepository`, Riverpod `AppProgressController`.
- Consumes: Hive box opened by `main.dart` in Task 6.

- [ ] **Step 1: Write failing progress model tests**

Cover defaults, JSON/map round-trip, corrupt/negative value normalization, monotonic unlocks, and idempotent completion:

```dart
const initial = PlayerProgress.initial();
final first = initial.completeLevel(levelId: 1);
final replay = first.completeLevel(levelId: 1);
expect(first.totalScore, 100);
expect(first.highestUnlockedLevel, 2);
expect(replay, first);
```

- [ ] **Step 2: Verify RED and implement model**

Run: `flutter test test/models/player_progress_test.dart`

Expected: FAIL because `PlayerProgress` does not exist.

Implement:

```dart
final class PlayerProgress {
  const PlayerProgress({
    required this.schemaVersion,
    required this.highestUnlockedLevel,
    required this.completedLevelIds,
    required this.totalScore,
    required this.lives,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });
  const PlayerProgress.initial();
  factory PlayerProgress.fromMap(Map<Object?, Object?> map);
  Map<String, Object> toMap();
  PlayerProgress completeLevel({required int levelId, int? nextLevelId});
}
```

`completeLevel` adds 100 only once and unlocks only the supplied existing `nextLevelId`.

- [ ] **Step 3: Verify model GREEN**

Run: `flutter test test/models/player_progress_test.dart`

Expected: PASS.

- [ ] **Step 4: Write failing repository/controller tests**

Use an in-memory repository and ProviderContainer to prove initial loading, first completion save, replay idempotency, save failure state, and retry.

Contract:

```dart
abstract interface class ProgressRepository {
  Future<PlayerProgress> load();
  Future<void> save(PlayerProgress progress);
}

final class InMemoryProgressRepository implements ProgressRepository {
  InMemoryProgressRepository([PlayerProgress progress = const PlayerProgress.initial()]);
  PlayerProgress value;
}
```

- [ ] **Step 5: Verify RED and implement repository/controller**

Run: `flutter test test/state/app_progress_controller_test.dart`

Expected: FAIL because repository/controller types do not exist.

Implement a Riverpod `AsyncNotifier<PlayerProgress>` with:

```dart
Future<void> completeLevel({required int levelId, int? nextLevelId});
Future<void> retryLastSave();
```

Expose `progressRepositoryProvider` and `appProgressControllerProvider`. Keep the last unsaved value for retry and preserve idempotency.

- [ ] **Step 6: Verify controller GREEN**

Run: `flutter test test/state/app_progress_controller_test.dart`

Expected: PASS.

- [ ] **Step 7: Write RED Hive adapter tests and implement**

Use a temporary Hive directory and box. The adapter stores the record under the single key `playerProgress` and returns defaults when absent or corrupt.

```dart
final class HiveProgressRepository implements ProgressRepository {
  HiveProgressRepository(this.box);
  final Box<Object?> box;
}
```

Run: `flutter test test/repositories/hive_progress_repository_test.dart`

Expected after implementation: PASS.

- [ ] **Step 8: Verify and commit**

Run:

```bash
flutter test test/models/player_progress_test.dart test/state/app_progress_controller_test.dart test/repositories/hive_progress_repository_test.dart
flutter analyze
git add lib/models/player_progress.dart lib/repositories/progress_repository.dart lib/repositories/hive_progress_repository.dart lib/state test/models/player_progress_test.dart test/state test/repositories/hive_progress_repository_test.dart
git commit -m "feat: persist idempotent player progress"
```

Expected: tests and analyzer exit 0; commit succeeds.

---

### Task 5: Flame renderer and gesture adapter

**Files:**
- Create: `lib/game/mind_spark_game.dart`
- Create: `test/game/mind_spark_game_test.dart`

**Interfaces:**
- Consumes: `LevelModel`, `PuzzleSession`, `PuzzleSnapshot`.
- Produces: `MindSparkGame.restart()` and deterministic `cellAtLocalPosition(Vector2)` mapping.

- [ ] **Step 1: Write failing coordinate and gesture tests**

Instantiate the game with a 5×5 level, set a known canvas size, and verify corner/centre mapping, letterboxing, out-of-board input, drag start/update/end, restart, and completion callback forwarding.

```dart
expect(game.cellAtLocalPosition(Vector2(boardLeft + 1, boardTop + 1)),
    const GridPosition(0, 0));
expect(game.cellAtLocalPosition(Vector2(boardRight + 1, boardTop)), isNull);
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/game/mind_spark_game_test.dart`

Expected: FAIL because `MindSparkGame` does not exist.

- [ ] **Step 3: Implement the smallest Flame game adapter**

Create:

```dart
final class MindSparkGame extends FlameGame {
  MindSparkGame({required LevelModel level, required VoidCallback onCompleted});
  PuzzleSnapshot get snapshot;
  GridPosition? cellAtLocalPosition(Vector2 position);
  void restart();
}
```

Use Flame drag callbacks to call `PuzzleSession`. Render directly in one focused component/game canvas: background grid, endpoint circles, and rounded path segments. Use a fixed colour-name palette with a visible fallback; add endpoint symbols so colour is not the only signal.

- [ ] **Step 4: Verify GREEN and resize behaviour**

Run: `flutter test test/game/mind_spark_game_test.dart`

Expected: PASS, including square-board resize mapping.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/game/mind_spark_game.dart test/game/mind_spark_game_test.dart
git commit -m "feat: render and control puzzle board with Flame"
```

Expected: analyzer exits 0; commit succeeds.

---

### Task 6: Flutter application flow

**Files:**
- Replace: `lib/main.dart`
- Create: `lib/app/app.dart`
- Create: `lib/app/routes.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/features/splash/splash_screen.dart`
- Create: `lib/features/home/home_screen.dart`
- Create: `lib/features/gameplay/gameplay_screen.dart`
- Create: `lib/features/result/result_screen.dart`
- Replace/Create: `test/widget_test.dart`
- Create: `test/features/app_flow_test.dart`

**Interfaces:**
- Consumes: level/progress providers and `MindSparkGame`.
- Produces: typed route flow and retryable initialization/save UI.

- [ ] **Step 1: Write failing widget tests for splash and home**

Override repositories in `ProviderScope`. Assert loading indicator, retry on level-load error, and loaded Home copy/values:

```dart
expect(find.text('MindSpark'), findsOneWidget);
expect(find.text('Level 1'), findsOneWidget);
expect(find.text('Best Score: 0'), findsOneWidget);
expect(find.text('PLAY'), findsOneWidget);
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the new app/screens do not exist.

- [ ] **Step 3: Implement app bootstrap, routes, theme, splash, and home**

Define:

```dart
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const gameplay = '/gameplay';
  static const result = '/result';
}

final class GameplayRouteArgs {
  const GameplayRouteArgs(this.levelId);
  final int levelId;
}

final class ResultRouteArgs {
  const ResultRouteArgs({required this.levelId, required this.awardedScore});
  final int levelId;
  final int awardedScore;
}
```

`main()` initializes Flutter binding, Hive CE Flutter, opens `mindSparkProgress`, and overrides `progressRepositoryProvider` with `HiveProgressRepository`.

- [ ] **Step 4: Verify splash/home GREEN**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Write failing gameplay/result flow tests**

Use a test seam/factory for `MindSparkGame` so the widget test can invoke completion without drawing gestures. Verify Play navigation, level title, Restart forwarding, first completion award, replay award `0`, Next Level, and final-level Home behaviour.

- [ ] **Step 6: Implement gameplay and result screens**

Gameplay loads the route level, creates one game instance, and handles completion once. It awaits `completeLevel`, calculates award from before/after progress, then routes to Result. Save errors show a retry action and do not claim persistence.

Result uses repository level order to decide between `Next Level` and `Home`.

- [ ] **Step 7: Verify the full widget flow and commit**

Run:

```bash
flutter test test/widget_test.dart test/features/app_flow_test.dart
flutter analyze
git add lib/main.dart lib/app lib/core lib/features test/widget_test.dart test/features/app_flow_test.dart
git commit -m "feat: add playable app navigation flow"
```

Expected: widget tests and analyzer exit 0; commit succeeds.

---

### Task 7: Full acceptance verification and documentation

**Files:**
- Modify: `README.md`
- Modify: `tasks/todo.md`
- Modify only if verification exposes a defect: affected implementation/test files

**Interfaces:**
- Verifies every earlier task together; introduces no new production API.

- [ ] **Step 1: Add one integration-style persistence flow test**

The test uses in-memory repositories and app recreation:

```dart
testWidgets('completion survives app recreation without duplicate score', (tester) async {
  // Start from fresh progress, complete level 1, rebuild ProviderScope with
  // the same repository, then assert Level 2 and Best Score: 100.
  // Replay level 1 and assert the score remains 100.
});
```

Run: `flutter test test/features/persistence_flow_test.dart`

Expected before adding any missing wiring: FAIL for the precise uncovered behaviour; after the minimal correction: PASS.

- [ ] **Step 2: Document developer commands and architecture**

README must state the product slice, Flutter prerequisite, `flutter pub get`, `flutter test`, `flutter run`, `flutter build apk --debug`, and the domain/Flame/Flutter ownership boundary.

- [ ] **Step 3: Run formatter and verify no diff noise**

Run:

```bash
dart format lib test
git diff --check
```

Expected: formatter exits 0 and diff check reports no whitespace errors.

- [ ] **Step 4: Run complete quality gates**

Run fresh:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Expected: every command exits 0; tests report zero failures; APK exists at `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 5: Review requirements line-by-line**

Confirm against the approved spec:

- Three 5×5 levels load and are solvable.
- Every endpoint pair can be connected without full-grid coverage.
- Crossings/overlap/foreign endpoints are rejected.
- Restart, completion lock, and one-shot callback are tested.
- Completion awards 100 only once and persists.
- Home → Game → Result → next/home works offline.
- Lives are persisted but inactive; excluded systems were not added.

- [ ] **Step 6: Update task review and commit**

Record exact analyzer/test/build results and any remaining non-MVP limitations in `tasks/todo.md`, then run:

```bash
git add README.md tasks/todo.md test/features/persistence_flow_test.dart lib test
git commit -m "test: verify MindSpark playable core"
```

Expected: clean working tree after commit.

