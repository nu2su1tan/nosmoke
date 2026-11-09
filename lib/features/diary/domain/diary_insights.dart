import '../../profile/domain/profile.dart';
import 'craving_entry.dart';

class DiaryInsights {
  const DiaryInsights({
    this.topTrigger,
    this.peakHour,
    this.topHelper,
    required this.total,
  });

  final Trigger? topTrigger;

  /// Час суток (0..23), на который приходится больше всего тяги.
  final int? peakHour;

  /// Что чаще всего помогало справиться.
  final String? topHelper;
  final int total;
}

/// Минимум записей, после которых закономерности считаются осмысленными.
const minEntriesForInsights = 3;

T? _top<T>(Map<T, int> m) {
  T? best;
  var max = 0;
  m.forEach((k, v) {
    if (v > max) {
      best = k;
      max = v;
    }
  });
  return best;
}

DiaryInsights computeInsights(List<CravingEntry> entries) {
  if (entries.length < minEntriesForInsights) {
    return DiaryInsights(total: entries.length);
  }
  final byTrigger = <Trigger, int>{};
  final byHour = <int, int>{};
  for (final e in entries) {
    if (e.trigger != null) {
      byTrigger[e.trigger!] = (byTrigger[e.trigger!] ?? 0) + 1;
    }
    byHour[e.at.hour] = (byHour[e.at.hour] ?? 0) + 1;
  }
  return DiaryInsights(
    topTrigger: _top(byTrigger),
    peakHour: _top(byHour),
    topHelper: helperFor(entries, null),
    total: entries.length,
  );
}

/// Что чаще всего помогало при [trigger] (или в целом, если null или если для
/// этого триггера данных нет). Считаются только записи, где человек справился.
String? helperFor(List<CravingEntry> entries, Trigger? trigger) {
  Map<String, int> count(Iterable<CravingEntry> es) {
    final m = <String, int>{};
    for (final e in es) {
      if (e.overcame && e.helped.isNotEmpty) {
        m[e.helped] = (m[e.helped] ?? 0) + 1;
      }
    }
    return m;
  }

  if (trigger != null) {
    final forTrigger = _top(count(entries.where((e) => e.trigger == trigger)));
    if (forTrigger != null) return forTrigger;
  }
  return _top(count(entries));
}

/// Подсказка, которая показывается незадолго до опасного времени.
class RiskHint {
  const RiskHint({required this.title, required this.body});

  final String title;
  final String body;
}

/// За сколько минут до пика начинаем предупреждать.
const riskLeadMinutes = 30;

/// Подсказка активна за [riskLeadMinutes] минут до пикового часа и в течение
/// самого часа. Возвращает null, если пика нет или время неподходящее.
RiskHint? upcomingRisk(DiaryInsights insights, DateTime now) {
  final peak = insights.peakHour;
  if (peak == null) return null;
  final minutes = now.hour * 60 + now.minute;
  final start = peak * 60;
  final inWindow =
      (minutes >= start - riskLeadMinutes && minutes < start + 60) ||
      // окно, переходящее через полночь (пик в 0:xx)
      (start - riskLeadMinutes < 0 &&
          minutes >= start - riskLeadMinutes + 24 * 60);
  if (!inWindow) return null;
  return RiskHint(title: 'Скоро опасное время', body: riskBody(insights));
}

/// Текст подсказки: триггер и то, что помогало в прошлый раз.
String riskBody(DiaryInsights i) {
  final parts = <String>[
    i.topTrigger == null
        ? 'Обычно в это время тянет курить.'
        : 'Обычно в это время тянет курить (${i.topTrigger!.label.toLowerCase()}).',
    if (i.topHelper != null)
      'В прошлый раз помогло: ${i.topHelper!.toLowerCase()}.'
    else
      'Приготовь план.',
  ];
  return parts.join(' ');
}
