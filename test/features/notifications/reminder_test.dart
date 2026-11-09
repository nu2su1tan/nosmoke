import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/diary/domain/diary_insights.dart';
import 'package:nosmoke/features/notifications/domain/reminder.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

import '../../helpers/fakes.dart';

void main() {
  final p = makeProfile();

  test('without diary data: morning, evening and weekly summary', () {
    final r = planReminders(p, const DiaryInsights(total: 0));
    expect(r.map((e) => e.id), [
      morningReminderId,
      eveningReminderId,
      weeklyReminderId,
    ]);
  });

  test('morning reminder mentions the motivation', () {
    final r = planReminders(p, const DiaryInsights(total: 0));
    expect(r.first.body, contains('дочь'));
  });

  test('peak reminder comes 10 minutes before the peak hour', () {
    final r = planReminders(
      p,
      const DiaryInsights(peakHour: 14, topTrigger: Trigger.coffee, total: 5),
    );
    final peak = r.firstWhere((e) => e.id == peakReminderId);
    expect((peak.hour, peak.minute), (13, 50));
    expect(peak.body, contains('кофе'));
  });

  test('peak at midnight wraps to 23:50', () {
    final r = planReminders(p, const DiaryInsights(peakHour: 0, total: 5));
    final peak = r.firstWhere((e) => e.id == peakReminderId);
    expect((peak.hour, peak.minute), (23, 50));
  });

  test('ids are unique and times are valid', () {
    final r = planReminders(p, const DiaryInsights(peakHour: 9, total: 5));
    expect(r.map((e) => e.id).toSet(), hasLength(r.length));
    for (final e in r) {
      expect(e.hour, inInclusiveRange(0, 23));
      expect(e.minute, inInclusiveRange(0, 59));
    }
  });
}
