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
