import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/achievements/domain/achievements.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';

ProgressSnapshot _snap({Duration best = Duration.zero, int cigs = 0}) =>
    ProgressSnapshot(
      started: true,
      daysInProgram: 0,
      cigsAvoided: cigs,
      moneySaved: 0,
      lifeRegained: Duration.zero,
      smokeFree: Duration.zero,
      bestStreak: best,
      streakActive: true,
      relapseCount: 0,
    );

Set<String> _unlocked(ProgressSnapshot s) => {
  for (final a in computeAchievements(s))
    if (a.unlocked) a.id,
};

void main() {
  test('nothing unlocked at the start', () {
    expect(_unlocked(_snap()), isEmpty);
  });

  test('streak achievements follow the best streak', () {
    expect(_unlocked(_snap(best: const Duration(days: 8))), {
      'streak_1',
      'streak_3',
      'streak_7',
    });
  });

  test('cigarette achievements', () {
    expect(_unlocked(_snap(cigs: 500)), {'cigs_100', 'cigs_500'});
  });

  test('russian plural forms', () {
    final titles = computeAchievements(_snap()).map((a) => a.title).toList();
    expect(titles, contains('1 день без сигарет'));
    expect(titles, contains('3 дня без сигарет'));
    expect(titles, contains('7 дней без сигарет'));
  });
}
