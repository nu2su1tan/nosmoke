import '../../../core/utils/formatters.dart';

class DailyHealth {
  const DailyHealth({required this.day, this.restingHr, this.steps});

  final DateTime day;

  /// Пульс покоя, уд/мин.
  final double? restingHr;
  final int? steps;
}

class HealthTrend {
  const HealthTrend({
    this.restingHrBefore,
    this.restingHrAfter,
    this.stepsBefore,
    this.stepsAfter,
  });

  final double? restingHrBefore;
  final double? restingHrAfter;
  final double? stepsBefore;
  final double? stepsAfter;

  bool get hasHeartRate => restingHrAfter != null;
  bool get hasSteps => stepsAfter != null;
  bool get isEmpty => !hasHeartRate && !hasSteps;

  /// Изменение пульса покоя (отрицательное — пульс снизился, это хорошо).
  double? get heartRateDelta =>
      restingHrBefore == null || restingHrAfter == null
      ? null
      : restingHrAfter! - restingHrBefore!;

  double? get stepsDelta => stepsBefore == null || stepsAfter == null
      ? null
      : stepsAfter! - stepsBefore!;
}

double? _avg(Iterable<num> v) =>
    v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

/// Сравнивает [windowDays] дней до отказа с последними [windowDays] днями.
/// Среднее считается, только если есть хотя бы [minDays] дней с данными.
HealthTrend computeHealthTrend(
  List<DailyHealth> days,
  DateTime quitDate,
  DateTime now, {
  int windowDays = 14,
  int minDays = 3,
}) {
  final quit = dateOnly(quitDate);
  final today = dateOnly(now);
  final beforeFrom = DateTime(quit.year, quit.month, quit.day - windowDays);
  final afterFrom = DateTime(
    today.year,
    today.month,
    today.day - windowDays + 1,
  );

  bool inBefore(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(beforeFrom) && x.isBefore(quit);
  }

  bool inAfter(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(afterFrom) && !x.isBefore(quit) && !x.isAfter(today);
  }

  double? mean(bool Function(DateTime) where, num? Function(DailyHealth) pick) {
    final values = <num>[
      for (final d in days)
        if (where(d.day)) ?pick(d),
    ];
    return values.length < minDays ? null : _avg(values);
  }

  return HealthTrend(
    restingHrBefore: mean(inBefore, (d) => d.restingHr),
    restingHrAfter: mean(inAfter, (d) => d.restingHr),
    stepsBefore: mean(inBefore, (d) => d.steps),
    stepsAfter: mean(inAfter, (d) => d.steps),
  );
}
