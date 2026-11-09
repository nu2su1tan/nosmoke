import '../../../core/utils/formatters.dart';
import '../../profile/domain/profile.dart';
import '../../relapse/domain/relapse.dart';
import '../../smoked/domain/smoked_entry.dart';

/// Минут жизни, «возвращаемых» за каждую не выкуренную сигарету (общепринятая оценка).
const minutesPerCigarette = 11;

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.started,
    required this.daysInProgram,
    required this.cigsAvoided,
    required this.moneySaved,
    required this.lifeRegained,
    required this.smokeFree,
    required this.bestStreak,
    required this.streakActive,
    required this.relapseCount,
  });

  /// Наступила ли дата старта.
  final bool started;

  /// Сколько дней прошло с даты старта. Срыв не обнуляет это число.
  final int daysInProgram;
  final int cigsAvoided;
  final double moneySaved;
  final Duration lifeRegained;

  /// Время без сигарет с последнего срыва (или с даты полного отказа).
  final Duration smokeFree;

  /// Лучшая серия без сигарет за всё время.
  final Duration bestStreak;

  /// Идёт ли серия: для «постепенно» — только после недели с лимитом 0.
  final bool streakActive;
  final int relapseCount;
}

/// [smoked] — записи «выкурил(а) по плану» (режим постепенного отказа).
/// Для дней, где они есть, берётся фактическое число, иначе считаем, что
/// человек уложился ровно в лимит.
ProgressSnapshot computeProgress(
  Profile p,
  List<Relapse> relapses,
  DateTime now, {
  List<SmokedEntry> smoked = const [],
}) {
  final start = dateOnly(p.quitDate);
  final started = !now.isBefore(start);
  if (!started) {
    return const ProgressSnapshot(
      started: false,
      daysInProgram: 0,
      cigsAvoided: 0,
      moneySaved: 0,
      lifeRegained: Duration.zero,
      smokeFree: Duration.zero,
      bestStreak: Duration.zero,
      streakActive: false,
      relapseCount: 0,
    );
  }

  final today = dateOnly(now);
  final fullDays = daysBetween(start, today);

  // Не выкуренные сигареты: полные дни + часть сегодняшнего.
  // Дни до полного отказа считаем по одному (их не больше ~5 недель),
  // остальные одной формулой: на каждый приходится вся дневная норма.
  var avoided = 0.0;
  final rampDays = daysBetween(start, p.fullQuitDate);
  final loopDays = fullDays < rampDays ? fullDays : rampDays;
  for (var i = 0; i < loopDays; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    final logged = p.quitMode == QuitMode.gradual ? smokedOn(smoked, day) : 0;
    avoided += logged > 0
        ? (p.cigsPerDay - logged).clamp(0, p.cigsPerDay)
        : p.cigsPerDay - p.dailyLimit(day);
  }
  if (fullDays > loopDays) avoided += (fullDays - loopDays) * p.cigsPerDay;
  final fractionOfToday =
      now.difference(today).inSeconds / Duration.secondsPerDay;
  avoided += (p.cigsPerDay - p.dailyLimit(today)) * fractionOfToday;

  final relapsed =
      relapses
          .where((r) => !r.at.isBefore(start) && !r.at.isAfter(now))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  final relapseCigs = relapsed.fold<int>(0, (s, r) => s + r.count);
  final cigsAvoided = (avoided - relapseCigs).floor().clamp(0, 1 << 30);

  // Серии считаем от даты полного отказа.
  final fullQuit = p.fullQuitDate;
  final streakActive = !now.isBefore(fullQuit);
  var streakStart = fullQuit;
  var best = Duration.zero;
  if (streakActive) {
    for (final r in relapsed) {
      if (r.at.isBefore(fullQuit)) continue;
      final gap = r.at.difference(streakStart);
      if (gap > best) best = gap;
      streakStart = r.at;
    }
    final current = now.difference(streakStart);
    if (current > best) best = current;
  }

  return ProgressSnapshot(
    started: true,
    daysInProgram: fullDays,
    cigsAvoided: cigsAvoided,
    moneySaved: cigsAvoided * p.pricePerCig,
    lifeRegained: Duration(minutes: cigsAvoided * minutesPerCigarette),
    smokeFree: streakActive ? now.difference(streakStart) : Duration.zero,
    bestStreak: best,
    streakActive: streakActive,
    relapseCount: relapsed.length,
  );
}
