import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/goals/data/goal_store.dart';
import 'package:nosmoke/features/goals/domain/savings_goal.dart';
import 'package:nosmoke/features/goals/presentation/goal_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final goal = SavingsGoal(
    title: 'Кроссовки',
    target: 50000,
    createdAt: DateTime(2026, 1, 1),
  );

  group('goalStatus', () {
    test('partial progress and days left', () {
      final s = goalStatus(goal, 12500, 2500);
      expect(s.fraction, 0.25);
      expect(s.remaining, 37500);
      expect(s.reached, isFalse);
      expect(s.daysLeft, 15);
    });

    test('days left rounds up', () {
      expect(goalStatus(goal, 0, 3000).daysLeft, 17); // 16.67
    });

    test('reached', () {
      final s = goalStatus(goal, 50000, 2500);
      expect(s.reached, isTrue);
      expect(s.fraction, 1);
      expect(s.remaining, 0);
      expect(s.daysLeft, isNull);
    });

    test('more than the target is capped at 100%', () {
      expect(goalStatus(goal, 90000, 100).fraction, 1);
    });

    test('no daily saving yet -> no forecast', () {
      expect(goalStatus(goal, 100, 0).daysLeft, isNull);
    });

    test('broken target does not divide by zero', () {
      final bad = SavingsGoal(title: 'x', target: 0, createdAt: DateTime(2026));
      expect(() => goalStatus(bad, 10, 1), returnsNormally);
    });
  });

  test('json roundtrip', () {
    final g = SavingsGoal.fromJson(goal.toJson());
    expect(g.title, 'Кроссовки');
    expect(g.target, 50000);
    expect(g.createdAt, DateTime(2026, 1, 1));
  });

  test('controller: set, replace, reload, clear', () async {
    final c = GoalController(goalStore());
    await c.load();
    expect(c.goal, isNull);

    await c.set(goal);
    await c.set(
      SavingsGoal(
        title: 'Отпуск',
        target: 200000,
        createdAt: DateTime(2026, 2, 1),
      ),
    );

    final c2 = GoalController(goalStore());
    await c2.load();
    expect(c2.goal!.title, 'Отпуск');

    await c.clear();
    final c3 = GoalController(goalStore());
    await c3.load();
    expect(c3.goal, isNull);
  });
}
