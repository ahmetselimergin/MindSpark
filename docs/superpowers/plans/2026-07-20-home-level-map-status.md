# Home Level Map & Status Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home screen's single big-number + Play-button layout with a horizontal, scrollable level map (completed / current / locked cards over the home background), and animate the Good/Great/Perfect status images on the win screen and on the returning map card.

**Architecture:** New presentation widgets under `lib/features/home/widgets/` (`LevelCard`, `LevelPathPainter`, `LevelMapView`) and a reusable `StatusBadge` under `lib/core/widgets/`. The map derives card state purely from the existing `PlayerProgress` (`highestUnlockedLevel`, `completedLevelIds`, `levelStars`). An ephemeral `celebrateLevelProvider` (StateProvider) carries "which level was just completed" from gameplay to the map. No persisted schema changes, no level-generation changes.

**Tech Stack:** Flutter, `flutter_riverpod` (AsyncNotifier + StateProvider), `flutter_test` widget tests with `ProviderScope` overrides and an `InMemoryProgressRepository`.

## Global Constraints

- Dart classes are declared `final class` / `abstract final class`, matching the codebase.
- Level numbers/statuses come only from `PlayerProgress`; never fetch `levelByIdProvider` on home.
- **The current-level card MUST expose `Semantics(button: true, label: 'Play')`** — many existing tests tap `find.bySemanticsLabel('Play')`. Only the current card uses `'Play'`; completed cards use `'Replay level $id'`; locked cards use `'Level $id locked'` and are not buttons.
- **No infinitely-repeating animations** anywhere added here. All animations are one-shot and must settle so `tester.pumpAndSettle()` returns. Current-card emphasis is a static glow, not a pulse.
- Colors: `AppColors.electricCyan` (completed), `AppColors.sparkYellow` (current), `AppColors.frost` (outline/text). Use `.withAlpha(n)` (codebase style), not `.withOpacity`.
- Status→stars mapping: 1→Good, 2→Great, 3→Perfect (clamp ≤1→Good, ≥3→Perfect).
- Assets are loaded with `Image.asset`; `assets/ui/Status/` must be declared in `pubspec.yaml` or the images fail to load (including in tests).
- Run the full suite with `flutter test` (or `fvm flutter test` if the repo uses fvm — check `.fvmrc`/`fvm` before running; otherwise `flutter test`).

## File Structure

**Create:**
- `lib/core/widgets/status_badge.dart` — `StatusBadge` animated Good/Great/Perfect widget.
- `lib/features/home/widgets/level_card.dart` — `LevelCardStatus` enum + `LevelCard` + layout consts.
- `lib/features/home/widgets/level_path_painter.dart` — `trailSegments()` pure fn + `LevelPathPainter`.
- `lib/features/home/widgets/level_map_view.dart` — `LevelMapView` (the scrollable map).
- Tests: `test/core/theme/app_images_test.dart`, `test/state/celebrate_level_provider_test.dart`, `test/core/widgets/status_badge_test.dart`, `test/features/home/level_card_test.dart`, `test/features/home/level_path_painter_test.dart`, `test/features/home/level_map_view_test.dart`.

**Modify:**
- `pubspec.yaml` — add `- assets/ui/Status/`.
- `lib/core/theme/app_images.dart` — add `background`, `star`, `statusGood/Great/Perfect`, `statusForStars`.
- `lib/state/app_progress_controller.dart` — add `celebrateLevelProvider`.
- `lib/features/home/home_screen.dart` — background + `LevelMapView`, remove big-number/Play/Best-Score block.
- `lib/features/result/result_screen.dart` — add `StatusBadge` overlay.
- `lib/features/gameplay/gameplay_screen.dart` — set `celebrateLevelProvider` on completion.
- Existing tests: `test/widget_test.dart`, `test/features/persistence_flow_test.dart`, `test/features/app_flow_test.dart`, `test/features/home_screen_lives_test.dart`.

---

### Task 1: Assets wiring + `AppImages` additions

**Files:**
- Modify: `pubspec.yaml` (flutter assets list)
- Modify: `lib/core/theme/app_images.dart`
- Test: `test/core/theme/app_images_test.dart`

**Interfaces:**
- Produces: `AppImages.background`, `AppImages.star`, `AppImages.statusGood`, `AppImages.statusGreat`, `AppImages.statusPerfect`, `String AppImages.statusForStars(int stars)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/app_images_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';

void main() {
  test('statusForStars maps stars to Good/Great/Perfect', () {
    expect(AppImages.statusForStars(0), AppImages.statusGood);
    expect(AppImages.statusForStars(1), AppImages.statusGood);
    expect(AppImages.statusForStars(2), AppImages.statusGreat);
    expect(AppImages.statusForStars(3), AppImages.statusPerfect);
    expect(AppImages.statusForStars(9), AppImages.statusPerfect);
  });

  test('new asset paths point under assets/ui', () {
    expect(AppImages.background, 'assets/ui/background.png');
    expect(AppImages.star, 'assets/ui/star.png');
    expect(AppImages.statusGood, 'assets/ui/Status/Good.png');
    expect(AppImages.statusGreat, 'assets/ui/Status/Great.png');
    expect(AppImages.statusPerfect, 'assets/ui/Status/Perfect.png');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_images_test.dart`
Expected: FAIL — `background`/`star`/`statusForStars` not defined.

- [ ] **Step 3: Add the constants**

In `lib/core/theme/app_images.dart`, add inside `AppImages` (after `star3`):

```dart
  static const String background = 'assets/ui/background.png';
  static const String star = 'assets/ui/star.png';
  static const String statusGood = 'assets/ui/Status/Good.png';
  static const String statusGreat = 'assets/ui/Status/Great.png';
  static const String statusPerfect = 'assets/ui/Status/Perfect.png';

  static String statusForStars(int stars) => switch (stars) {
    <= 1 => statusGood,
    2 => statusGreat,
    _ => statusPerfect,
  };
```

- [ ] **Step 4: Declare the Status subfolder in pubspec**

In `pubspec.yaml`, under `flutter:` → `assets:`, the current lines are:

```yaml
    - assets/levels/levels.json
    - assets/ui/
```

Add a line so it reads:

```yaml
    - assets/levels/levels.json
    - assets/ui/
    - assets/ui/Status/
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/theme/app_images_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/core/theme/app_images.dart test/core/theme/app_images_test.dart
git commit -m "feat: add background/star/status image paths and Status asset folder"
```

---

### Task 2: `celebrateLevelProvider`

**Files:**
- Modify: `lib/state/app_progress_controller.dart`
- Test: `test/state/celebrate_level_provider_test.dart`

**Interfaces:**
- Produces: `final celebrateLevelProvider = StateProvider<int?>((ref) => null);`

- [ ] **Step 1: Write the failing test**

Create `test/state/celebrate_level_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  test('defaults to null and holds a level id, then clears', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(celebrateLevelProvider), isNull);

    container.read(celebrateLevelProvider.notifier).state = 7;
    expect(container.read(celebrateLevelProvider), 7);

    container.read(celebrateLevelProvider.notifier).state = null;
    expect(container.read(celebrateLevelProvider), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/state/celebrate_level_provider_test.dart`
Expected: FAIL — `celebrateLevelProvider` not defined.

- [ ] **Step 3: Add the provider**

In `lib/state/app_progress_controller.dart`, after the `appProgressControllerProvider` declaration (around line 26), add:

```dart
/// Ephemeral, in-memory flag: the id of a level whose completion should be
/// celebrated with a status-badge burst on the level map. Not persisted.
/// Set by the gameplay flow on completion, cleared by [LevelMapView] after the
/// badge animation plays.
final celebrateLevelProvider = StateProvider<int?>((ref) => null);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/state/celebrate_level_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state/app_progress_controller.dart test/state/celebrate_level_provider_test.dart
git commit -m "feat: add ephemeral celebrateLevelProvider"
```

---

### Task 3: `StatusBadge` widget

**Files:**
- Create: `lib/core/widgets/status_badge.dart`
- Test: `test/core/widgets/status_badge_test.dart`

**Interfaces:**
- Consumes: `AppImages.statusForStars(int)`.
- Produces: `StatusBadge({required int stars, double width = 220, bool autoPlay = true, VoidCallback? onCompleted})`. One-shot scale-in + fade on mount; calls `onCompleted` when the entrance animation finishes.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/status_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';

void main() {
  Finder badgeImage() => find.descendant(
    of: find.byType(StatusBadge),
    matching: find.byType(Image),
  );

  testWidgets('renders the asset for the star tier', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBadge(stars: 3))),
    );
    await tester.pump();
    final image = tester.widget<Image>(badgeImage());
    expect((image.image as AssetImage).assetName, AppImages.statusPerfect);
  });

  testWidgets('entrance animation settles and fires onCompleted', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StatusBadge(stars: 1, onCompleted: () => done = true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/status_badge_test.dart`
Expected: FAIL — `status_badge.dart` does not exist.

- [ ] **Step 3: Implement `StatusBadge`**

Create `lib/core/widgets/status_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_images.dart';

/// Animated Good/Great/Perfect badge. Scales in with a slight overshoot and
/// fades in once on mount, then holds. Non-interactive; driven purely by
/// [stars] (1..3). Calls [onCompleted] when the entrance animation finishes.
final class StatusBadge extends StatefulWidget {
  const StatusBadge({
    super.key,
    required this.stars,
    this.width = 220,
    this.autoPlay = true,
    this.onCompleted,
  });

  final int stars;
  final double width;
  final bool autoPlay;
  final VoidCallback? onCompleted;

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _controller.forward().whenComplete(() {
        if (mounted) {
          widget.onCompleted?.call();
        }
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Image.asset(
            AppImages.statusForStars(widget.stars),
            width: widget.width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/status_badge_test.dart`
Expected: PASS (both tests; `pumpAndSettle` returns because the animation is one-shot).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/status_badge.dart test/core/widgets/status_badge_test.dart
git commit -m "feat: add one-shot StatusBadge (Good/Great/Perfect)"
```

---

### Task 4: `LevelCard` + `LevelCardStatus`

**Files:**
- Create: `lib/features/home/widgets/level_card.dart`
- Test: `test/features/home/level_card_test.dart`

**Interfaces:**
- Consumes: `AppImages.star`, `AppColors`.
- Produces:
  - `enum LevelCardStatus { completed, current, locked }`
  - `const double kLevelCardWidth = 92;` and `const double kLevelCardHeight = 108;`
  - `LevelCard({required int levelId, required LevelCardStatus status, required int stars, required VoidCallback? onTap})`
  - Semantics: current → `'Play'` (button, enabled); completed → `'Replay level $levelId'` (button); locked → `'Level $levelId locked'` (not a button).

- [ ] **Step 1: Write the failing test**

Create `test/features/home/level_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('current card shows number, is labelled Play, and taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(LevelCard(
        levelId: 3,
        status: LevelCardStatus.current,
        stars: 0,
        onTap: () => taps++,
      )),
    );
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Play'));
    expect(taps, 1);
  });

  testWidgets('completed card shows number and three star images', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(LevelCard(
        levelId: 8,
        status: LevelCardStatus.completed,
        stars: 2,
        onTap: () {},
      )),
    );
    expect(find.text('8'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LevelCard),
        matching: find.byType(Image),
      ),
      findsNWidgets(3),
    );
    expect(find.bySemanticsLabel('Replay level 8'), findsOneWidget);
  });

  testWidgets('locked card is not a Play button and ignores taps', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const LevelCard(
        levelId: 5,
        status: LevelCardStatus.locked,
        stars: 0,
        onTap: null,
      )),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsNothing);
    expect(find.bySemanticsLabel('Level 5 locked'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/level_card_test.dart`
Expected: FAIL — `level_card.dart` does not exist.

- [ ] **Step 3: Implement `LevelCard`**

Create `lib/features/home/widgets/level_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';

enum LevelCardStatus { completed, current, locked }

const double kLevelCardWidth = 92;
const double kLevelCardHeight = 108;

const Color _currentOrange = Color(0xFFFF8A00);
const Color _completedDeep = Color(0xFF2A78B8);

/// A single level node on the home map. Presentation only — all state is
/// passed in. Current cards use a static glow (no looping animation).
final class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.levelId,
    required this.status,
    required this.stars,
    required this.onTap,
  });

  final int levelId;
  final LevelCardStatus status;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      LevelCardStatus.current => 'Play',
      LevelCardStatus.completed => 'Replay level $levelId',
      LevelCardStatus.locked => 'Level $levelId locked',
    };
    return Semantics(
      button: status != LevelCardStatus.locked,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: kLevelCardWidth,
          height: kLevelCardHeight,
          child: _face(),
        ),
      ),
    );
  }

  Widget _face() {
    switch (status) {
      case LevelCardStatus.current:
        return _CardBox(
          gradient: const [AppColors.sparkYellow, _currentOrange],
          glow: AppColors.sparkYellow,
          child: _number(),
        );
      case LevelCardStatus.completed:
        return _CardBox(
          gradient: const [AppColors.electricCyan, _completedDeep],
          glow: AppColors.electricCyan.withAlpha(120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_number(), const SizedBox(height: 8), _stars()],
          ),
        );
      case LevelCardStatus.locked:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.frost.withAlpha(120), width: 2),
          ),
          child: Center(child: _number(dim: true)),
        );
    }
  }

  Widget _number({bool dim = false}) => Text(
    '$levelId',
    style: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: dim ? AppColors.frost.withAlpha(150) : AppColors.frost,
    ),
  );

  Widget _stars() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Opacity(
          opacity: i < stars ? 1 : 0.28,
          child: Image.asset(AppImages.star, width: 16, height: 16),
        ),
    ],
  );
}

class _CardBox extends StatelessWidget {
  const _CardBox({
    required this.gradient,
    required this.glow,
    required this.child,
  });

  final List<Color> gradient;
  final Color glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Center(child: child),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/level_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/widgets/level_card.dart test/features/home/level_card_test.dart
git commit -m "feat: add LevelCard with completed/current/locked states"
```

---

### Task 5: `LevelPathPainter` + `trailSegments`

**Files:**
- Create: `lib/features/home/widgets/level_path_painter.dart`
- Test: `test/features/home/level_path_painter_test.dart`

**Interfaces:**
- Consumes: `LevelCardStatus` (from `level_card.dart`), `AppColors`.
- Produces:
  - `List<(Offset, Offset)> trailSegments(List<Offset> centers, List<LevelCardStatus> statuses)` — a connector between card *i* and *i+1* iff neither is `locked`.
  - `class LevelPathPainter extends CustomPainter` drawing dashed quadratic-bezier connectors for those segments.

- [ ] **Step 1: Write the failing test**

Create `test/features/home/level_path_painter_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';
import 'package:mind_spark/features/home/widgets/level_path_painter.dart';

void main() {
  test('trailSegments connects only consecutive non-locked cards', () {
    final centers = [
      const Offset(0, 0),
      const Offset(1, 0),
      const Offset(2, 0),
      const Offset(3, 0),
    ];
    const statuses = [
      LevelCardStatus.completed,
      LevelCardStatus.completed,
      LevelCardStatus.current,
      LevelCardStatus.locked,
    ];
    final segments = trailSegments(centers, statuses);
    expect(segments, hasLength(2)); // 0-1 and 1-2; 2-3 stops at locked
    expect(segments.first.$1, const Offset(0, 0));
    expect(segments.last.$2, const Offset(2, 0));
  });

  test('trailSegments with a single card yields nothing', () {
    final segments =
        trailSegments(const [Offset.zero], const [LevelCardStatus.current]);
    expect(segments, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/level_path_painter_test.dart`
Expected: FAIL — `level_path_painter.dart` does not exist.

- [ ] **Step 3: Implement painter + pure function**

Create `lib/features/home/widgets/level_path_painter.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';

/// Segments to connect on the map: a dash between card i and i+1 iff neither
/// endpoint is locked (i.e. only along the played trail).
List<(Offset, Offset)> trailSegments(
  List<Offset> centers,
  List<LevelCardStatus> statuses,
) {
  final segments = <(Offset, Offset)>[];
  for (var i = 0; i + 1 < centers.length; i++) {
    if (statuses[i] != LevelCardStatus.locked &&
        statuses[i + 1] != LevelCardStatus.locked) {
      segments.add((centers[i], centers[i + 1]));
    }
  }
  return segments;
}

/// Draws dashed, gently-arched connectors between consecutive card centers on
/// the played trail.
class LevelPathPainter extends CustomPainter {
  const LevelPathPainter({required this.centers, required this.statuses});

  final List<Offset> centers;
  final List<LevelCardStatus> statuses;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.frost.withAlpha(179)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final (from, to) in trailSegments(centers, statuses)) {
      final control = Offset(
        (from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2 - 24,
      );
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
      _drawDashed(canvas, path, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0;
    const gap = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(LevelPathPainter old) =>
      !listEquals(old.centers, centers) || !listEquals(old.statuses, statuses);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/level_path_painter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/widgets/level_path_painter.dart test/features/home/level_path_painter_test.dart
git commit -m "feat: add LevelPathPainter with played-trail dashed connectors"
```

---

### Task 6: `LevelMapView`

**Files:**
- Create: `lib/features/home/widgets/level_map_view.dart`
- Test: `test/features/home/level_map_view_test.dart`

**Interfaces:**
- Consumes: `appProgressControllerProvider`, `celebrateLevelProvider`, `clockProvider`, `progressRepositoryProvider` (for test overrides), `LivesRegen.reconcile`, `LevelCard`, `LevelCardStatus`, `LevelPathPainter`, `StatusBadge`, `AppRoutes`, `GameplayRouteArgs`, `OutOfLivesRouteArgs`.
- Produces: `final class LevelMapView extends ConsumerStatefulWidget { const LevelMapView({super.key}); }` — a horizontally scrollable map derived from progress. Shows ids `1 .. highestUnlockedLevel + kLockedTeaser` (`kLockedTeaser = 5`), auto-centers the current level, taps route to gameplay/out-of-lives, and plays a one-shot celebration badge for `celebrateLevelProvider` then clears it.

- [ ] **Step 1: Write the failing test**

Create `test/features/home/level_map_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';
import 'package:mind_spark/features/home/widgets/level_map_view.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

PlayerProgress _progress({
  required int highest,
  Set<int> completed = const {},
  Map<int, int> stars = const {},
  int lives = 3,
  DateTime? anchor,
}) {
  return PlayerProgress(
    schemaVersion: 3,
    highestUnlockedLevel: highest,
    completedLevelIds: completed,
    totalScore: completed.length * 100,
    lives: lives,
    livesRegenAnchor: anchor,
    levelStars: stars,
    soundEnabled: true,
    vibrationEnabled: true,
  );
}

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider
          .overrideWithValue(InMemoryProgressRepository(stored)),
      clockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          AppRoutes.gameplay => Scaffold(
              body: Text('GAMEPLAY ${(settings.arguments as GameplayRouteArgs).levelId}'),
            ),
          AppRoutes.outOfLives => Scaffold(
              body: Text('OUT OF LIVES ${(settings.arguments as OutOfLivesRouteArgs).levelId}'),
            ),
          _ => Consumer(
              builder: (context, ref, _) {
                final ready = ref.watch(appProgressControllerProvider).hasValue;
                return Scaffold(
                  body: ready
                      ? const SizedBox(height: 240, child: LevelMapView())
                      : const SizedBox.shrink(),
                );
              },
            ),
        },
      ),
    ),
  );
}

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders completed, current and locked cards from progress', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(
        highest: 10,
        completed: {for (var i = 1; i <= 9; i++) i},
        stars: {for (var i = 1; i <= 9; i++) i: 3},
      ),
      t0,
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Play'), findsOneWidget); // level 10
    expect(find.bySemanticsLabel('Replay level 9'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 11 locked'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 15 locked'), findsOneWidget);
  });

  testWidgets('tapping the current card opens gameplay for that level', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_progress(highest: 1), t0));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('GAMEPLAY 1'), findsOneWidget);
  });

  testWidgets('tapping a completed card replays it', (tester) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 3, completed: {1, 2}, stars: {1: 3, 2: 2}),
      t0,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Replay level 2'));
    await tester.pumpAndSettle();

    expect(find.text('GAMEPLAY 2'), findsOneWidget);
  });

  testWidgets('locked cards are not tappable', (tester) async {
    await tester.pumpWidget(_harness(_progress(highest: 2, completed: {1}), t0));
    await tester.pumpAndSettle();

    final locked = tester
        .widgetList<LevelCard>(find.byType(LevelCard))
        .where((c) => c.status == LevelCardStatus.locked);
    expect(locked, isNotEmpty);
    expect(locked.every((c) => c.onTap == null), isTrue);
  });

  testWidgets('current tap with zero lives routes to out-of-lives', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 1, lives: 0, anchor: t0),
      t0.add(const Duration(minutes: 1)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('OUT OF LIVES 1'), findsOneWidget);
  });

  testWidgets('celebration badge plays for the flagged level then clears', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(
      _progress(highest: 4, completed: {1, 2, 3}, stars: {1: 3, 2: 3, 3: 3}),
      t0,
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LevelMapView)),
    );
    container.read(celebrateLevelProvider.notifier).state = 3;
    await tester.pump(); // map consumes the flag
    await tester.pump();

    expect(find.byType(StatusBadge), findsOneWidget);

    await tester.pumpAndSettle();
    expect(container.read(celebrateLevelProvider), isNull);
    expect(find.byType(StatusBadge), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/level_map_view_test.dart`
Expected: FAIL — `level_map_view.dart` does not exist.

- [ ] **Step 3: Implement `LevelMapView`**

Create `lib/features/home/widgets/level_map_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/features/home/widgets/level_card.dart';
import 'package:mind_spark/features/home/widgets/level_path_painter.dart';
import 'package:mind_spark/game/domain/lives_state.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

const int kLockedTeaser = 5;
const double _step = kLevelCardWidth + 34;
const double _amplitude = 26;
const double _edgePad = 24;
const double _contentHeight = kLevelCardHeight + 2 * _amplitude + 12;

/// Horizontal, scrollable level map derived entirely from [PlayerProgress].
final class LevelMapView extends ConsumerStatefulWidget {
  const LevelMapView({super.key});

  @override
  ConsumerState<LevelMapView> createState() => _LevelMapViewState();
}

class _LevelMapViewState extends ConsumerState<LevelMapView> {
  final ScrollController _controller = ScrollController();
  bool _opening = false;
  bool _didCenter = false;
  int? _celebratingId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LevelCardStatus _statusFor(int id, int highest) {
    if (id > highest) {
      return LevelCardStatus.locked;
    }
    if (id == highest) {
      return LevelCardStatus.current;
    }
    return LevelCardStatus.completed;
  }

  double _left(int index) => _edgePad + index * _step;

  double _top(int index) =>
      _contentHeight / 2 -
      kLevelCardHeight / 2 +
      (index.isEven ? -_amplitude : _amplitude);

  Offset _center(int index) =>
      Offset(_left(index) + kLevelCardWidth / 2, _top(index) + kLevelCardHeight / 2);

  Future<void> _play(int id) async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    await Navigator.of(context)
        .pushNamed(AppRoutes.gameplay, arguments: GameplayRouteArgs(id));
    if (mounted) {
      setState(() => _opening = false);
    }
  }

  void _onTap(int id, LevelCardStatus status, int livesNow) {
    if (status == LevelCardStatus.locked) {
      return;
    }
    if (livesNow <= 0) {
      Navigator.of(context)
          .pushNamed(AppRoutes.outOfLives, arguments: OutOfLivesRouteArgs(id));
      return;
    }
    _play(id);
  }

  void _centerCurrent(int currentIndex, double viewportWidth) {
    if (_didCenter || !_controller.hasClients) {
      return;
    }
    _didCenter = true;
    final target = (_center(currentIndex).dx - viewportWidth / 2)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(appProgressControllerProvider).requireValue;
    final now = ref.read(clockProvider)();
    final livesNow = LivesRegen.reconcile(
      lives: progress.lives,
      anchor: progress.livesRegenAnchor,
      now: now,
    ).lives;
    final highest = progress.highestUnlockedLevel;
    final count = highest + kLockedTeaser;
    final currentIndex = highest - 1;

    // Consume the celebration flag exactly once.
    final celebrate = ref.watch(celebrateLevelProvider);
    if (celebrate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(celebrateLevelProvider.notifier).state = null;
        if (celebrate >= 1 && celebrate <= count) {
          setState(() => _celebratingId = celebrate);
        }
      });
    }

    final statuses = <LevelCardStatus>[];
    final centers = <Offset>[];
    for (var i = 0; i < count; i++) {
      statuses.add(_statusFor(i + 1, highest));
      centers.add(_center(i));
    }

    final contentWidth = _left(count - 1) + kLevelCardWidth + _edgePad;

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _centerCurrent(currentIndex, constraints.maxWidth),
        );
        return SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: _contentHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: LevelPathPainter(centers: centers, statuses: statuses),
                  ),
                ),
                for (var i = 0; i < count; i++)
                  Positioned(
                    left: _left(i),
                    top: _top(i),
                    child: LevelCard(
                      levelId: i + 1,
                      status: statuses[i],
                      stars: progress.levelStars[i + 1] ?? 0,
                      onTap: statuses[i] == LevelCardStatus.locked
                          ? null
                          : () => _onTap(i + 1, statuses[i], livesNow),
                    ),
                  ),
                if (_celebratingId != null)
                  Positioned(
                    left: _left(_celebratingId! - 1) +
                        kLevelCardWidth / 2 -
                        45,
                    top: _top(_celebratingId! - 1) - 30,
                    child: StatusBadge(
                      stars: progress.levelStars[_celebratingId!] ?? 3,
                      width: 90,
                      onCompleted: () {
                        if (mounted) {
                          setState(() => _celebratingId = null);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/level_map_view_test.dart`
Expected: PASS (all six tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/widgets/level_map_view.dart test/features/home/level_map_view_test.dart
git commit -m "feat: add LevelMapView with tap-to-play, auto-center, and celebration badge"
```

---

### Task 7: Home screen integration + existing-test migration

This task removes the old Play block and wires in the map + background. Because the home Play `ImageButton` and `Best Score`/`Level N` text disappear, four existing test files are migrated in the SAME task so the suite stays green.

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/features/persistence_flow_test.dart`
- Modify: `test/features/app_flow_test.dart`
- Modify: `test/features/home_screen_lives_test.dart`

**Interfaces:**
- Consumes: `LevelMapView`, `AppImages.background`, `LevelCard`, `LevelCardStatus`.

- [ ] **Step 1: Rewrite the home screen body**

Replace the entire contents of `lib/features/home/home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/theme/app_theme.dart';
import 'package:mind_spark/core/widgets/lives_bar.dart';
import 'package:mind_spark/core/widgets/spark_trail.dart';
import 'package:mind_spark/features/home/widgets/level_map_view.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    final progressAsync = ref.watch(appProgressControllerProvider);
    return progressAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _HomeContentError(
        onRetry: () => ref.invalidate(appProgressControllerProvider),
      ),
      data: (progress) => _buildHome(context, progress),
    );
  }

  Widget _buildHome(BuildContext context, PlayerProgress progress) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(AppImages.background, fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 700;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SparkTrail(),
                          SizedBox(height: compact ? 8 : 16),
                          Text(
                            'MindSpark',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontSize: 30, letterSpacing: -.4),
                          ),
                          const SizedBox(height: 12),
                          const LivesBar(),
                          SizedBox(height: compact ? 16 : 32),
                          const SizedBox(height: 220, child: LevelMapView()),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              color: AppColors.frost,
              tooltip: 'Settings',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
          ),
        ],
      ),
    );
  }
}

final class _HomeContentError extends StatelessWidget {
  const _HomeContentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.coralPulse,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Saved progress could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run the home smoke check (expect existing tests to break)**

Run: `flutter test test/widget_test.dart test/features/app_flow_test.dart`
Expected: FAIL on `find.text('Level 1')`, `find.text('Best Score: …')`, and `find.byType(ImageButton)` on home. This confirms exactly which assertions to migrate below.

- [ ] **Step 3: Migrate `test/widget_test.dart`**

In the `'home shows the current level and score'` test (currently lines ~174-186), replace the body assertions:

```dart
    expect(find.text('MindSpark'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Best Score: 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
```

with:

```dart
    expect(find.text('MindSpark'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // current-level card number
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
```

(The other `find.bySemanticsLabel('Play')` / `find.text('Best Score: 0') findsNothing` assertions in this file are on error/loading screens and remain correct — leave them unchanged.)

- [ ] **Step 4: Migrate `test/features/persistence_flow_test.dart`**

Replace lines ~50-51:

```dart
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Best Score: 100'), findsOneWidget);
```

with:

```dart
    expect(find.text('2'), findsOneWidget); // current-level card is level 2
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
```

- [ ] **Step 5: Migrate `test/features/app_flow_test.dart` — Best Score assertion**

Replace line ~258:

```dart
      expect(find.text('Best Score: 200'), findsOneWidget);
```

with:

```dart
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
```

- [ ] **Step 6: Migrate `test/features/app_flow_test.dart` — rapid Play test**

Add this import near the other imports:

```dart
import 'package:mind_spark/features/home/widgets/level_card.dart';
```

Replace the body of `'rapid Play callback creates one gameplay route'` (currently lines ~421-432):

```dart
  testWidgets('rapid Play callback creates one gameplay route', (tester) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();

    final play = tester.widget<ImageButton>(find.byType(ImageButton));
    play.onPressed!();
    play.onPressed!();
    await _pumpRoute(tester);

    expect(harness.games, hasLength(1));
  });
```

with:

```dart
  testWidgets('rapid Play callback creates one gameplay route', (tester) async {
    final harness = _GameHarness();
    await tester.pumpWidget(_testApp(harness: harness));
    await tester.pumpAndSettle();

    final current = tester.widget<LevelCard>(
      find.byWidgetPredicate(
        (w) => w is LevelCard && w.status == LevelCardStatus.current,
      ),
    );
    current.onTap!();
    current.onTap!();
    await _pumpRoute(tester);

    expect(harness.games, hasLength(1));
  });
```

(The `ImageButton` import stays — it is still used on the result screen at lines ~66 and ~445.)

- [ ] **Step 7: Migrate `test/features/home_screen_lives_test.dart` — route-aware harness + out-of-lives**

Replace the whole file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/app/routes.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/features/home/home_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

Widget _harness(PlayerProgress stored, DateTime now) {
  return ProviderScope(
    overrides: [
      progressRepositoryProvider.overrideWithValue(
        InMemoryProgressRepository(stored),
      ),
      clockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => switch (settings.name) {
          AppRoutes.gameplay => const Scaffold(body: Text('GAMEPLAY')),
          AppRoutes.outOfLives => const Scaffold(body: Text('OUT OF LIVES')),
          _ => Consumer(
              builder: (context, ref, _) {
                final ready =
                    ref.watch(appProgressControllerProvider).hasValue;
                return ready ? const HomeScreen() : const SizedBox.shrink();
              },
            ),
        },
      ),
    ),
  );
}

int _fullHearts(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .where((o) {
      final child = o.child;
      return o.opacity == 1.0 &&
          child is Image &&
          child.image is AssetImage &&
          (child.image as AssetImage).assetName == AppImages.heart;
    })
    .length;

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

  testWidgets('renders one filled heart per life', (tester) async {
    final stored =
        const PlayerProgress.initial().copyWithLives(lives: 1, anchor: t0);
    await tester.pumpWidget(
      _harness(stored, t0.add(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();

    expect(_fullHearts(tester), 1);
    expect(find.textContaining('Next life'), findsOneWidget);
  });

  testWidgets('shows three filled hearts and no countdown when full', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlayerProgress.initial(), t0));
    await tester.pumpAndSettle();

    expect(_fullHearts(tester), 3);
    expect(find.textContaining('Next life'), findsNothing);
  });

  testWidgets('tapping the current level with no lives opens out-of-lives', (
    tester,
  ) async {
    final stored =
        const PlayerProgress.initial().copyWithLives(lives: 0, anchor: t0);
    await tester.pumpWidget(
      _harness(stored, t0.add(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pumpAndSettle();

    expect(find.text('OUT OF LIVES'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: PASS (all tests green). If a level-number `find.text('1')`/`find.text('2')` assertion is ambiguous because a locked card shares the digit, adjust that single assertion to `findsWidgets` — but with the ranges used here each digit is unique.

- [ ] **Step 9: Commit**

```bash
git add lib/features/home/home_screen.dart test/widget_test.dart test/features/persistence_flow_test.dart test/features/app_flow_test.dart test/features/home_screen_lives_test.dart
git commit -m "feat: home shows scrollable level map over background; migrate home tests"
```

---

### Task 8: Win-screen badge + gameplay celebration wiring

**Files:**
- Modify: `lib/features/result/result_screen.dart`
- Modify: `lib/features/gameplay/gameplay_screen.dart`
- Test: `test/features/result_status_badge_test.dart` (create)
- Modify: `test/features/app_flow_test.dart` (assert the flag is set on completion)

**Interfaces:**
- Consumes: `StatusBadge`, `celebrateLevelProvider`.

- [ ] **Step 1: Write the failing result-screen test**

Create `test/features/result_status_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/core/theme/app_images.dart';
import 'package:mind_spark/core/widgets/status_badge.dart';
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/models/player_progress.dart';
import 'package:mind_spark/repositories/progress_repository.dart';
import 'package:mind_spark/state/app_progress_controller.dart';

void main() {
  testWidgets('result screen shows a StatusBadge for the awarded stars', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            InMemoryProgressRepository(const PlayerProgress.initial()),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final ready =
                  ref.watch(appProgressControllerProvider).hasValue;
              return ready
                  ? const ResultScreen(
                      levelId: 1,
                      awardedScore: 100,
                      stars: 2,
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StatusBadge), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName, AppImages.statusGreat);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/result_status_badge_test.dart`
Expected: FAIL — no `StatusBadge` on the result screen.

- [ ] **Step 3: Add the badge to the result screen**

In `lib/features/result/result_screen.dart`, add the import:

```dart
import 'package:mind_spark/core/widgets/status_badge.dart';
```

Then, inside the `Stack`'s `children` (after the `Positioned.fill` won-board image, so it layers above), add:

```dart
                      Align(
                        alignment: const Alignment(0, -0.78),
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: StatusBadge(stars: widget.stars),
                        ),
                      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/result_status_badge_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the celebration flag on completion**

In `lib/features/gameplay/gameplay_screen.dart`, immediately after the `await ref.read(appProgressControllerProvider.notifier).completeLevel(...)` call (the block ending at line ~260) and its `if (!mounted) return;` guard, set the flag:

```dart
    ref.read(celebrateLevelProvider.notifier).state = widget.levelId;
```

`celebrateLevelProvider` lives in `app_progress_controller.dart`, which this file already imports (it reads `appProgressControllerProvider` from there). If the import is somehow missing, add:

```dart
import 'package:mind_spark/state/app_progress_controller.dart';
```

- [ ] **Step 6: Assert the flag is set (extend an existing app-flow test)**

In `test/features/app_flow_test.dart`, add imports if absent:

```dart
import 'package:mind_spark/features/result/result_screen.dart';
import 'package:mind_spark/state/app_progress_controller.dart';
```

In the `'first completion awards 100 and next opens the following level id'` test, after the `await _pumpRoute(tester);` that follows `harness.completeLatest();` (i.e. once the result screen is shown, ~line 58), add:

```dart
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ResultScreen)),
      );
      expect(container.read(celebrateLevelProvider), 1);
```

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/result/result_screen.dart lib/features/gameplay/gameplay_screen.dart test/features/result_status_badge_test.dart test/features/app_flow_test.dart
git commit -m "feat: animate Good/Great/Perfect on win screen and flag map celebration"
```

---

## Self-Review

**Spec coverage:**
- Home horizontal scrollable map, staggered + dashed path, auto-center → Tasks 5, 6, 7. ✓
- Three card states from `PlayerProgress` → Task 4 (`LevelCard`), Task 6 (status mapping). ✓
- StatusBadge on win screen → Task 8. ✓
- StatusBadge on returning map card (celebration) → Task 2 (provider), Task 6 (display), Task 8 (set on completion). ✓
- Home background `background.png` → Task 1 (path), Task 7 (render). ✓
- `assets/ui/Status/` pubspec + `AppImages` → Task 1. ✓
- Tap-to-play (current), replay (completed), locked no-op, 0-lives → out-of-lives → Task 6. ✓
- Preserve `'Play'` semantics + migrate existing tests → Global Constraints + Task 7. ✓
- Error/loading guards on home → Task 7 (`progressAsync.when`). ✓
- Testing section (LevelCard, LevelMapView, painter, StatusBadge, result, celebration) → Tasks 3-8. ✓

**Placeholder scan:** No `TBD`/`TODO`/"add error handling"/"similar to Task N"; every code step shows complete code. ✓

**Type consistency:**
- `LevelCardStatus { completed, current, locked }` used identically in Tasks 4, 5, 6, 7. ✓
- `LevelCard({levelId, status, stars, onTap})` — same call shape in Task 6 and the Task 7 rapid-Play test. ✓
- `StatusBadge({stars, width, autoPlay, onCompleted})` — Task 3 defines; Tasks 6 and 8 use `stars`/`width`/`onCompleted`. ✓
- `trailSegments(List<Offset>, List<LevelCardStatus>)` + `LevelPathPainter({centers, statuses})` — defined Task 5, used Task 6. ✓
- `celebrateLevelProvider` `StateProvider<int?>` — defined Task 2; read/cleared Task 6; set Task 8; asserted Tasks 2, 6, 8. ✓
- Layout consts `kLevelCardWidth`/`kLevelCardHeight` (Task 4) consumed by `_step`/`_left`/`_center` (Task 6). ✓

No gaps found.
