import '../../diary/domain/diary_insights.dart';
import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';

enum CoachRole { user, assistant }

/// Откуда пришёл ответ.
enum CoachSource { local, remote }

class CoachMessage {
  const CoachMessage({
    required this.role,
    required this.text,
    this.source = CoachSource.local,
  });

  final CoachRole role;
  final String text;
  final CoachSource source;
}

/// Что коуч знает о пользователе. Только то, что человек сам ввёл в
/// приложении; в запрос к серверу уходит текстовая сводка [toPrompt].
class CoachContext {
  const CoachContext({
    required this.smokeFreeDays,
    required this.daysInProgram,
    required this.relapseCount,
    required this.cigsPerDay,
    required this.yearsSmoking,
    required this.gradual,
    this.limitToday,
    this.motivation,
    this.topTrigger,
    this.peakHour,
    this.topHelper,
  });

  final int smokeFreeDays;
  final int daysInProgram;
  final int relapseCount;
  final int cigsPerDay;
  final int yearsSmoking;
  final bool gradual;
  final int? limitToday;
  final String? motivation;
  final Trigger? topTrigger;
  final int? peakHour;
  final String? topHelper;

  factory CoachContext.from(
    Profile p,
    ProgressSnapshot s,
    DiaryInsights insights,
    DateTime now,
  ) {
    final why = p.motivationText.isNotEmpty
        ? p.motivationText
        : p.motivations.isEmpty
        ? null
        : p.motivations.map((m) => m.label.toLowerCase()).join(', ');
    return CoachContext(
      smokeFreeDays: s.streakActive ? s.smokeFree.inDays : 0,
      daysInProgram: s.daysInProgram,
      relapseCount: s.relapseCount,
      cigsPerDay: p.cigsPerDay,
      yearsSmoking: p.yearsSmoking,
      gradual: p.quitMode == QuitMode.gradual,
      limitToday: p.quitMode == QuitMode.gradual ? p.dailyLimit(now) : null,
      motivation: why,
      topTrigger: insights.topTrigger,
      peakHour: insights.peakHour,
      topHelper: insights.topHelper,
    );
  }

  /// Сводка для модели. Без имён, контактов и точных дат.
  String toPrompt() => [
    'Дней без сигарет: $smokeFreeDays (всего в программе: $daysInProgram)',
    'Срывов: $relapseCount',
    'Раньше курил(а): $cigsPerDay сигарет в день, $yearsSmoking лет',
    if (gradual)
      'Режим: постепенное снижение, лимит сегодня: $limitToday'
    else
      'Режим: резкий отказ',
    if (motivation != null) 'Причина бросить: $motivation',
    if (topTrigger != null)
      'Главный триггер: ${topTrigger!.label.toLowerCase()}',
    if (peakHour != null) 'Пик тяги около $peakHour:00',
    if (topHelper != null) 'Чаще всего помогало: ${topHelper!.toLowerCase()}',
  ].join('\n');
}

/// Быстрые фразы под полем ввода.
const coachQuickPrompts = [
  'Тянет курить прямо сейчас',
  'Я сорвался(ась)',
  'Сильный стресс',
  'Не могу уснуть',
  'Боюсь поправиться',
];
