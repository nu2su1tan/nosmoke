import '../../diary/domain/diary_insights.dart';
import '../../profile/domain/profile.dart';

class Reminder {
  const Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    this.weekday,
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;

  /// День недели (1 = понедельник … 7 = воскресенье) для еженедельных
  /// напоминаний; null — каждый день.
  final int? weekday;
}

const morningReminderId = 1;
const eveningReminderId = 2;
const peakReminderId = 3;
const weeklyReminderId = 4;

/// Строит набор ежедневных напоминаний: утро, вечер и предупреждение
/// за 10 минут до часа, когда чаще всего тянет курить (по дневнику).
///
/// В режиме закрепления ([maintenance], 90+ дней без срывов) убираем
/// ежедневные утро и вечер: остаются предупреждение и итоги недели.
List<Reminder> planReminders(
  Profile p,
  DiaryInsights insights, {
  bool maintenance = false,
}) {
  final why = p.motivationText.isNotEmpty
      ? p.motivationText
      : p.motivations.isNotEmpty
      ? p.motivations.map((m) => m.label.toLowerCase()).join(', ')
      : null;

  final reminders = <Reminder>[
    if (!maintenance) ...[
      Reminder(
        id: morningReminderId,
        hour: 9,
        minute: 0,
        title: 'Доброе утро!',
        body: why == null
            ? 'Ещё один день без сигарет. У тебя получится.'
            : 'Твоя причина: $why. Сегодня ты справишься.',
      ),
      const Reminder(
        id: eveningReminderId,
        hour: 21,
        minute: 0,
        title: 'Как прошёл день?',
        body: 'Отметь, была ли тяга. Это занимает полминуты.',
      ),
    ],
  ];

  final peak = insights.peakHour;
  if (peak != null) {
    final total = peak * 60 - 10;
    final minutes = total < 0 ? total + 24 * 60 : total;
    reminders.add(
      Reminder(
        id: peakReminderId,
        hour: minutes ~/ 60,
        minute: minutes % 60,
        title: 'Скоро опасное время',
        body: riskBody(insights),
      ),
    );
  }
  reminders.add(
    const Reminder(
      id: weeklyReminderId,
      hour: 19,
      minute: 0,
      weekday: DateTime.sunday,
      title: 'Итоги недели готовы',
      body: 'Посмотри, как прошла твоя неделя: победы, триггеры и экономия.',
    ),
  );
  return reminders;
}
