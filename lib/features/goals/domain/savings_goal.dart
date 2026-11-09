class SavingsGoal {
  const SavingsGoal({
    required this.title,
    required this.target,
    required this.createdAt,
  });

  final String title;
  final double target;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'target': target,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
    title: j['title'] as String,
    target: (j['target'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class GoalStatus {
  const GoalStatus({
    required this.fraction,
    required this.remaining,
    required this.reached,
    required this.daysLeft,
  });

  /// Доля пути, 0..1.
  final double fraction;

  /// Сколько осталось накопить (не меньше нуля).
  final double remaining;
  final bool reached;

  /// Через сколько дней цель будет достигнута при текущей экономии
  /// (null — если экономии нет или цель уже достигнута).
  final int? daysLeft;
}

/// [saved] — накоплено с начала программы, [perDay] — экономия в день
/// (0, если сейчас человек ещё курит по плану и экономия нестабильна).
GoalStatus goalStatus(SavingsGoal goal, double saved, double perDay) {
  final target = goal.target <= 0 ? 1.0 : goal.target;
  final reached = saved >= target;
  final remaining = reached ? 0.0 : target - saved;
  return GoalStatus(
    fraction: (saved / target).clamp(0.0, 1.0),
    remaining: remaining,
    reached: reached,
    daysLeft: reached || perDay <= 0 ? null : (remaining / perDay).ceil(),
  );
}
