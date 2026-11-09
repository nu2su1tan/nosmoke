import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/progress/domain/week.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';

import '../../helpers/fakes.dart';

void main() {
  // 9 ноября 2026 — понедельник.
  final now = DateTime(2026, 11, 9, 15);

  test('always seven days ending today, oldest first', () {
    final w = computeWeek(makeProfile(quitDate: DateTime(2026, 1, 1)), [], now);
    expect(w, hasLength(7));
    expect(w.first.date, DateTime(2026, 11, 3));
    expect(w.last.date, DateTime(2026, 11, 9));
    expect(w.where((d) => d.isToday), hasLength(1));
    expect(w.last.isToday, isTrue);
  });

  test('letters follow the weekdays (П В С Ч П С В)', () {
    final w = computeWeek(makeProfile(quitDate: DateTime(2026, 1, 1)), [], now);
    // 3 ноября — вторник … 9 ноября — понедельник
    expect(w.map((d) => d.letter).join(), 'ВСЧПСВП');
  });

  test('days before the start are not started', () {
    final w = computeWeek(
      makeProfile(quitDate: DateTime(2026, 11, 7)),
      [],
      now,
    );
    expect(w.map((d) => d.state), [
      DayState.notStarted,
      DayState.notStarted,
      DayState.notStarted,
      DayState.notStarted,
      DayState.clean,
      DayState.clean,
      DayState.clean,
    ]);
  });

  test('a relapse marks only its own day', () {
    final w = computeWeek(makeProfile(quitDate: DateTime(2026, 1, 1)), [
      Relapse(at: DateTime(2026, 11, 6, 23, 30)),
    ], now);
    expect(w.where((d) => d.state == DayState.relapse).map((d) => d.date.day), [
      6,
    ]);
    expect(w.where((d) => d.state == DayState.clean), hasLength(6));
  });

  test('works across month and year boundaries', () {
    final w = computeWeek(
      makeProfile(quitDate: DateTime(2025, 1, 1)),
      [],
      DateTime(2026, 1, 2),
    );
    expect(w.first.date, DateTime(2025, 12, 27));
    expect(w.last.date, DateTime(2026, 1, 2));
  });
}
