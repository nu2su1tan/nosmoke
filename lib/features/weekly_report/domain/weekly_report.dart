import '../../../core/utils/formatters.dart';
import '../../diary/domain/craving_entry.dart';
import '../../diary/domain/diary_insights.dart';
import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';
import '../../progress/domain/week.dart';
import '../../relapse/domain/relapse.dart';
import '../../smoked/domain/smoked_entry.dart';

const _weekdayNames = [
  'понедельник',
  'вторник',
  'среду',
  'четверг',
  'пятницу',
  'субботу',
  'воскресенье',
];

class WeeklyReport {
  const WeeklyReport({
    required this.from,
    required this.to,
    required this.cravings,
    required this.overcame,
    required this.relapses,
    required this.cleanDays,
    required this.daysInWindow,
    required this.cigsAvoided,
    required this.moneySaved,
    required this.hardestWeekday,
    required this.topTrigger,
    required this.topHelper,
    required this.suggestion,
  });

  final DateTime from;
  final DateTime to;
  final int cravings;
  final int overcame;
  final int relapses;

  /// Дней без срывов среди дней, когда программа уже шла.
  final int cleanDays;
  final int daysInWindow;
  final int cigsAvoided;
  final double moneySaved;

  /// День недели (1 = понедельник) с наибольшим числом тяг.
  final int? hardestWeekday;
  final Trigger? topTrigger;
  final String? topHelper;
  final String suggestion;

  String? get hardestWeekdayName =>
      hardestWeekday == null ? null : _weekdayNames[hardestWeekday! - 1];

  /// Доля побед над тягой, 0..1 (null, если тяг не было).
  double? get winRate => cravings == 0 ? null : overcame / cravings;
}

/// Итоги последних 7 дней (включая сегодня).
WeeklyReport buildWeeklyReport(
  Profile p,
  List<Relapse> relapses,
  List<CravingEntry> diary,
  List<SmokedEntry> smoked,
  DateTime now,
) {
  final today = dateOnly(now);
  final from = DateTime(today.year, today.month, today.day - 6);
  bool inWindow(DateTime t) => !dateOnly(t).isBefore(from) && !t.isAfter(now);

  final entries = diary.where((e) => inWindow(e.at)).toList();
  final windowRelapses = relapses.where((r) => inWindow(r.at)).toList();

  final nowProgress = computeProgress(p, relapses, now, smoked: smoked);
  final fromProgress = computeProgress(p, relapses, from, smoked: smoked);
  final avoided = (nowProgress.cigsAvoided - fromProgress.cigsAvoided).clamp(
    0,
    1 << 30,
  );

  final days = computeWeek(p, relapses, now);
  final started = days.where((d) => d.state != DayState.notStarted).toList();
  final clean = started.where((d) => d.state == DayState.clean).length;

  final byWeekday = <int, int>{};
  for (final e in entries) {
    byWeekday[e.at.weekday] = (byWeekday[e.at.weekday] ?? 0) + 1;
  }
  int? hardest;
  var max = 0;
  for (var d = 1; d <= 7; d++) {
    final c = byWeekday[d] ?? 0;
    if (c > max) {
      max = c;
      hardest = d;
    }
  }

  final byTrigger = <Trigger, int>{};
  for (final e in entries) {
    if (e.trigger != null) {
      byTrigger[e.trigger!] = (byTrigger[e.trigger!] ?? 0) + 1;
    }
  }
  Trigger? topTrigger;
  var tmax = 0;
  byTrigger.forEach((k, v) {
    if (v > tmax) {
      tmax = v;
      topTrigger = k;
    }
  });
  final topHelper = helperFor(entries, null);

  final suggestion = _suggest(
    relapses: windowRelapses.length,
    cravings: entries.length,
    topTrigger: topTrigger,
    topHelper: topHelper,
  );

  return WeeklyReport(
    from: from,
    to: today,
    cravings: entries.length,
    overcame: entries.where((e) => e.overcame).length,
    relapses: windowRelapses.length,
    cleanDays: clean,
    daysInWindow: started.length,
    cigsAvoided: avoided,
    moneySaved: avoided * p.pricePerCig,
    hardestWeekday: hardest,
    topTrigger: topTrigger,
    topHelper: topHelper,
    suggestion: suggestion,
  );
}

String _suggest({
  required int relapses,
  required int cravings,
  required Trigger? topTrigger,
  required String? topHelper,
}) {
  if (relapses > 0) {
    return 'Срыв на этой неделе — не провал. Запиши, что его спровоцировало, '
        'и заранее подготовь замену на этот момент.';
  }
  if (topTrigger != null) {
    final helper = topHelper == null
        ? 'Придумай, чем заменить этот момент.'
        : 'В такие моменты помогало: ${topHelper.toLowerCase()}.';
    return 'Главный триггер недели — ${topTrigger.label.toLowerCase()}. $helper';
  }
  if (cravings == 0) {
    return 'Спокойная неделя. Так держать. Если тяга вернётся, '
        'отметь её в дневнике.';
  }
  return 'Отмечай, что вызывает тягу: через пару недель приложение '
      'покажет твои закономерности.';
}

/// Текст итогов для отправки друзьям.
String buildWeeklyShareText(Profile p, WeeklyReport r) {
  final lines = <String>[
    'Моя неделя без сигарет:',
    'Дней без срывов: ${r.cleanDays} из ${r.daysInWindow}',
    'Не выкурено: ${r.cigsAvoided}',
    'Сэкономлено: ${p.money(r.moneySaved)}',
    if (r.cravings > 0) 'Тяга пережита: ${r.overcame} из ${r.cravings}',
    '#NoSmoke',
  ];
  return lines.join('\n');
}
