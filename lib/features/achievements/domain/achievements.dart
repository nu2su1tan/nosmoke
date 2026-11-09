import '../../progress/domain/progress.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final bool unlocked;
}

const _streakDays = [1, 3, 7, 14, 30, 100, 365];
const _cigsMilestones = [100, 500, 1000];

String _daysWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

/// Достижения считаются по лучшей серии, поэтому срыв их не отнимает.
List<Achievement> computeAchievements(ProgressSnapshot s) => [
  for (final d in _streakDays)
    Achievement(
      id: 'streak_$d',
      title: '$d ${_daysWord(d)} без сигарет',
      description: 'Серия без сигарет $d ${_daysWord(d)}',
      unlocked: s.bestStreak >= Duration(days: d),
    ),
  for (final c in _cigsMilestones)
    Achievement(
      id: 'cigs_$c',
      title: '$c сигарет не выкурено',
      description: 'Ты не выкурил(а) $c сигарет',
      unlocked: s.cigsAvoided >= c,
    ),
];
