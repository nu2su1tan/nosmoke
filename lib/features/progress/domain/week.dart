import '../../../core/utils/formatters.dart';
import '../../profile/domain/profile.dart';
import '../../relapse/domain/relapse.dart';

enum DayState {
  /// День до старта программы.
  notStarted,

  /// День без срывов.
  clean,

  /// В этот день был срыв.
  relapse,
}

class WeekDay {
  const WeekDay({
    required this.date,
    required this.state,
    required this.isToday,
  });

  final DateTime date;
  final DayState state;
  final bool isToday;

  /// Первая буква дня недели: П В С Ч П С В.
  String get letter => 'ПВСЧПСВ'[date.weekday - 1];
}

/// Последние 7 дней (включая сегодня), от старых к новым.
List<WeekDay> computeWeek(Profile p, List<Relapse> relapses, DateTime now) {
  final today = dateOnly(now);
  final start = dateOnly(p.quitDate);
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        final DayState state;
        if (d.isBefore(start)) {
          state = DayState.notStarted;
        } else if (relapses.any((r) => dateOnly(r.at) == d)) {
          state = DayState.relapse;
        } else {
          state = DayState.clean;
        }
        return WeekDay(date: d, state: state, isToday: i == 0);
      }(),
  ];
}
