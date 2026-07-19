import 'package:flutter_test/flutter_test.dart';
import 'package:mind_spark/game/domain/lives_state.dart';

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
  const tenMin = Duration(minutes: 10);

  group('LivesRegen.reconcile', () {
    test('full lives report no anchor and no countdown', () {
      final r = LivesRegen.reconcile(lives: 3, anchor: null, now: t0);
      expect(r.lives, 3);
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
      final r = LivesRegen.reconcile(lives: 1, anchor: t0, now: t0.add(tenMin));
      expect(r.lives, 2);
      expect(r.anchor, t0.add(tenMin));
      expect(r.untilNextLife, tenMin);
    });

    test('multiple windows grant multiple lives and carry the remainder', () {
      final r = LivesRegen.reconcile(
        lives: 0,
        anchor: t0,
        now: t0.add(const Duration(minutes: 25)),
      );
      expect(r.lives, 2);
      expect(r.anchor, t0.add(const Duration(minutes: 20)));
      expect(r.untilNextLife, const Duration(minutes: 5));
    });

    test('reaching the cap clears the anchor and countdown', () {
      final r = LivesRegen.reconcile(
        lives: 1,
        anchor: t0,
        now: t0.add(const Duration(minutes: 45)),
      );
      expect(r.lives, 3);
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
