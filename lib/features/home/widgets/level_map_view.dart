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
