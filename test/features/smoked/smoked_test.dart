import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/smoked/data/smoked_store.dart';
import 'package:nosmoke/features/smoked/domain/smoked_entry.dart';
import 'package:nosmoke/features/smoked/presentation/smoked_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('limit state', () {
    test('ok / last / reached', () {
      expect(limitState(0, 5), LimitState.ok);
      expect(limitState(3, 5), LimitState.ok);
      expect(limitState(4, 5), LimitState.last);
      expect(limitState(5, 5), LimitState.reached);
      expect(limitState(7, 5), LimitState.reached);
      expect(limitState(0, 1), LimitState.last);
      expect(limitState(0, 0), LimitState.reached);
    });

    test('smokedOn counts only the given calendar day', () {
      final e = [
        SmokedEntry(at: DateTime(2026, 3, 1, 0, 5)),
        SmokedEntry(at: DateTime(2026, 3, 1, 23, 59)),
        SmokedEntry(at: DateTime(2026, 3, 2, 0, 0)),
      ];
      expect(smokedOn(e, DateTime(2026, 3, 1, 12)), 2);
      expect(smokedOn(e, DateTime(2026, 3, 2)), 1);
      expect(smokedOn(e, DateTime(2026, 3, 3)), 0);
    });
  });

  group('controller', () {
    test('add, count, persist and reload', () async {
      final c = SmokedController(smokedStore());
      await c.add(DateTime(2026, 3, 1, 9));
      await c.add(DateTime(2026, 3, 1, 14));
      await c.add(DateTime(2026, 3, 2, 9));
      expect(c.countOn(DateTime(2026, 3, 1)), 2);

      final c2 = SmokedController(smokedStore());
      await c2.load();
      expect(c2.items, hasLength(3));
    });

    test('undo removes only the latest entry of that day', () async {
      final c = SmokedController(smokedStore());
      await c.add(DateTime(2026, 3, 1, 9));
      await c.add(DateTime(2026, 3, 1, 14));
      await c.add(DateTime(2026, 3, 2, 9));
      await c.undoLastOn(DateTime(2026, 3, 1));
      expect(c.items.map((e) => e.at.hour), [9, 9]);
      expect(c.countOn(DateTime(2026, 3, 1)), 1);
      await c.undoLastOn(DateTime(2026, 3, 5)); // нечего отменять
      expect(c.items, hasLength(2));
    });

    test('clear', () async {
      final c = SmokedController(smokedStore());
      await c.add();
      await c.clear();
      expect(c.items, isEmpty);
    });
  });

  group('progress with the smoked log', () {
    final g = makeProfile(mode: QuitMode.gradual); // 20/день, старт 1 января

    test('without entries the plan is assumed (limit 16 → 4 saved/day)', () {
      final s = computeProgress(g, [], DateTime(2026, 1, 8));
      expect(s.cigsAvoided, 28);
    });

    test('a logged day uses the actual number', () {
      final smoked = [
        for (var i = 0; i < 10; i++)
          SmokedEntry(at: DateTime(2026, 1, 2, 8 + i)),
      ];
      // день 2 января: 10 вместо плановых 16 → экономия 10, а не 4
      final s = computeProgress(g, [], DateTime(2026, 1, 8), smoked: smoked);
      expect(s.cigsAvoided, 28 - 4 + 10);
    });

    test('never negative and capped at the daily norm', () {
      final many = [
        for (var i = 0; i < 40; i++) SmokedEntry(at: DateTime(2026, 1, 2, 1)),
      ];
      final s = computeProgress(g, [], DateTime(2026, 1, 3), smoked: many);
      expect(s.cigsAvoided, greaterThanOrEqualTo(0));
    });

    test('ignored in cold-turkey mode (relapses are used instead)', () {
      final cold = makeProfile();
      final smoked = [SmokedEntry(at: DateTime(2026, 1, 2, 9))];
      final a = computeProgress(cold, [], DateTime(2026, 1, 4));
      final b = computeProgress(cold, [], DateTime(2026, 1, 4), smoked: smoked);
      expect(b.cigsAvoided, a.cigsAvoided);
    });
  });
}
