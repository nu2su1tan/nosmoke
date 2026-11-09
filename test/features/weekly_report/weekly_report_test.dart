import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';
import 'package:nosmoke/features/weekly_report/domain/weekly_report.dart';

import '../../helpers/fakes.dart';

void main() {
  // 9 ноября 2026 — понедельник. Окно: 3–9 ноября.
  final now = DateTime(2026, 11, 9, 20);
  final p = makeProfile(quitDate: DateTime(2026, 10, 1));

  CravingEntry e(
    DateTime at, {
    Trigger? t,
    bool ok = true,
    String helped = '',
  }) => CravingEntry(
    id: at.toString() + (t?.name ?? ''),
    at: at,
    trigger: t,
    overcame: ok,
    helped: helped,
  );

  test('empty week with a running program', () {
    final r = buildWeeklyReport(p, [], [], [], now);
    expect(r.cleanDays, 7);
    expect(r.daysInWindow, 7);
    expect(r.cravings, 0);
    expect(r.relapses, 0);
    expect(r.cigsAvoided, greaterThan(0));
    expect(r.moneySaved, closeTo(r.cigsAvoided * 100, 0.01));
    expect(r.hardestWeekday, isNull);
    expect(r.winRate, isNull);
    expect(r.suggestion, contains('Спокойная неделя'));
  });

  test('week-over-week saving is about 7 days of the daily norm', () {
    final r = buildWeeklyReport(p, [], [], [], now);
    // 20 сигарет в день, 7 полных дней (окно включает сегодняшнюю часть дня)
    expect(r.cigsAvoided, inInclusiveRange(7 * 20 - 20, 7 * 20));
  });

  test('cravings, win rate, hardest day, top trigger and helper', () {
    final diary = [
      e(DateTime(2026, 11, 5, 9), t: Trigger.coffee, helped: 'Прогулка'),
      e(DateTime(2026, 11, 5, 15), t: Trigger.coffee, helped: 'Прогулка'),
      e(DateTime(2026, 11, 5, 18), t: Trigger.stress, ok: false),
      e(DateTime(2026, 11, 7, 12), t: Trigger.coffee),
      e(DateTime(2026, 10, 20, 9), t: Trigger.alcohol), // вне окна
    ];
    final r = buildWeeklyReport(p, [], diary, [], now);
    expect(r.cravings, 4);
    expect(r.overcame, 3);
    expect(r.winRate, 0.75);
    expect(r.hardestWeekday, DateTime.thursday); // 5 ноября — четверг
    expect(r.hardestWeekdayName, 'четверг');
    expect(r.topTrigger, Trigger.coffee);
    expect(r.topHelper, 'Прогулка');
    expect(r.suggestion, contains('Главный триггер недели — кофе'));
    expect(r.suggestion, contains('помогало: прогулка'));
  });

  test('a relapse lowers clean days and changes the advice', () {
    final r = buildWeeklyReport(
      p,
      [Relapse(at: DateTime(2026, 11, 6, 22), count: 2)],
      [],
      [],
      now,
    );
    expect(r.relapses, 1);
    expect(r.cleanDays, 6);
    expect(r.suggestion, contains('Срыв на этой неделе — не провал'));
  });

  test('a program that started mid-week counts only its own days', () {
    final fresh = makeProfile(quitDate: DateTime(2026, 11, 7));
    final r = buildWeeklyReport(fresh, [], [], [], now);
    expect(r.daysInWindow, 3);
    expect(r.cleanDays, 3);
  });

  test('before the program starts everything is zero', () {
    final future = makeProfile(quitDate: DateTime(2026, 12, 1));
    final r = buildWeeklyReport(future, [], [], [], now);
    expect(r.daysInWindow, 0);
    expect(r.cigsAvoided, 0);
    expect(r.moneySaved, 0);
  });

  test('share text', () {
    final r = buildWeeklyReport(p, [], [e(DateTime(2026, 11, 5, 9))], [], now);
    final text = buildWeeklyShareText(p, r);
    expect(text, contains('Дней без срывов: 7 из 7'));
    expect(text, contains('Тяга пережита: 1 из 1'));
    expect(text, contains('₸'));
    expect(text, endsWith('#NoSmoke'));
  });
}
