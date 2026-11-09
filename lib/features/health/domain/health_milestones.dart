class HealthMilestone {
  const HealthMilestone(this.after, this.title, this.description);

  final Duration after;
  final String title;
  final String description;
}

const healthMilestones = <HealthMilestone>[
  HealthMilestone(
    Duration(minutes: 20),
    '20 минут',
    'Пульс и давление приходят в норму.',
  ),
  HealthMilestone(
    Duration(hours: 8),
    '8 часов',
    'Уровень угарного газа в крови снижается, кислорода становится больше.',
  ),
  HealthMilestone(
    Duration(hours: 24),
    '24 часа',
    'Риск сердечного приступа начинает снижаться.',
  ),
  HealthMilestone(
    Duration(hours: 48),
    '48 часов',
    'Обоняние и вкус заметно улучшаются, никотин выводится из организма.',
  ),
  HealthMilestone(
    Duration(hours: 72),
    '72 часа',
    'Дышать становится легче, бронхи расслабляются.',
  ),
  HealthMilestone(
    Duration(days: 14),
    '2 недели',
    'Улучшается кровообращение, легче ходить и заниматься спортом.',
  ),
  HealthMilestone(
    Duration(days: 30),
    '1 месяц',
    'Кашель и одышка уменьшаются, легкие начинают очищаться.',
  ),
  HealthMilestone(
    Duration(days: 90),
    '3 месяца',
    'Функция лёгких заметно улучшается.',
  ),
  HealthMilestone(
    Duration(days: 365),
    '1 год',
    'Риск ишемической болезни сердца вдвое ниже, чем у курильщика.',
  ),
];

/// Ближайшая ещё не достигнутая веха или null, если все пройдены.
HealthMilestone? nextMilestone(Duration smokeFree) {
  for (final m in healthMilestones) {
    if (smokeFree < m.after) return m;
  }
  return null;
}

/// Доля пути до ближайшей вехи, 0..1.
double milestoneProgress(Duration smokeFree) {
  final next = nextMilestone(smokeFree);
  if (next == null) return 1;
  final idx = healthMilestones.indexOf(next);
  final prev = idx == 0 ? Duration.zero : healthMilestones[idx - 1].after;
  final span = (next.after - prev).inSeconds;
  return ((smokeFree - prev).inSeconds / span).clamp(0.0, 1.0);
}
