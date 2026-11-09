import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/diary/domain/diary_insights.dart';
import 'package:nosmoke/features/notifications/domain/reminder.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

import '../../helpers/fakes.dart';

void main() {
  final p = makeProfile();
  const none = DiaryInsights(total: 0);

  test('weekly summary is on Sunday evening', () {
    final w = planReminders(
      p,
      none,
    ).firstWhere((r) => r.id == weeklyReminderId);
    expect(w.weekday, DateTime.sunday);
    expect((w.hour, w.minute), (19, 0));
  });

  test('daily reminders have no weekday', () {
    final r = planReminders(p, none);
    expect(r.firstWhere((e) => e.id == morningReminderId).weekday, isNull);
    expect(r.firstWhere((e) => e.id == eveningReminderId).weekday, isNull);
  });

  test('maintenance mode drops the daily morning and evening reminders', () {
    final r = planReminders(p, none, maintenance: true);
    expect(r.map((e) => e.id), [weeklyReminderId]);
  });

  test('maintenance keeps the danger-time warning', () {
    const insights = DiaryInsights(peakHour: 10, total: 5);
    final r = planReminders(p, insights, maintenance: true);
    expect(r.map((e) => e.id).toSet(), {peakReminderId, weeklyReminderId});
  });

  test('the warning mentions what helped last time', () {
    const insights = DiaryInsights(
      peakHour: 10,
      topTrigger: Trigger.workBreak,
      topHelper: 'Вода',
      total: 6,
    );
    final peak = planReminders(
      p,
      insights,
    ).firstWhere((r) => r.id == peakReminderId);
    expect(peak.body, contains('перерыв на работе'));
    expect(peak.body, contains('помогло: вода'));
  });

  test('all ids stay unique with every reminder enabled', () {
    const insights = DiaryInsights(peakHour: 10, total: 6);
    final ids = planReminders(p, insights).map((r) => r.id);
    expect(ids.toSet(), hasLength(ids.length));
  });
}
