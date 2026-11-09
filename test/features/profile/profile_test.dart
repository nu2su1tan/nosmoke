import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

import '../../helpers/fakes.dart';

void main() {
  test('gradual schedule 20 -> 16,12,8,4,0', () {
    expect(buildGradualSchedule(20), [16, 12, 8, 4, 0]);
  });

  test('gradual schedule is strictly decreasing and ends with 0', () {
    for (final n in [1, 2, 3, 5, 10, 33, 60]) {
      final s = buildGradualSchedule(n);
      expect(s.last, 0, reason: 'n=$n');
      for (var i = 1; i < s.length; i++) {
        expect(s[i], lessThan(s[i - 1]), reason: 'n=$n');
      }
    }
  });

  test('savings', () {
    final p = makeProfile();
    expect(p.dailyCost, 2000);
    expect(p.monthlySavings, 60000);
    expect(p.yearlySavings, 730000);
  });

  test('daily limit for gradual and cold modes', () {
    final g = makeProfile(mode: QuitMode.gradual);
    expect(g.dailyLimit(DateTime(2025, 12, 31)), 20);
    expect(g.dailyLimit(DateTime(2026, 1, 1)), 16);
    expect(g.dailyLimit(DateTime(2026, 1, 8)), 12);
    expect(g.dailyLimit(DateTime(2026, 3, 1)), 0);
    expect(makeProfile().dailyLimit(DateTime(2026, 1, 1)), 0);
  });

  test('fullQuitDate', () {
    expect(makeProfile().fullQuitDate, DateTime(2026, 1, 1));
    expect(
      makeProfile(mode: QuitMode.gradual).fullQuitDate,
      DateTime(2026, 1, 29),
    );
  });

  test('doctor suggestion', () {
    expect(makeProfile(cigs: 21).suggestDoctor, isTrue);
    expect(makeProfile(years: 11).suggestDoctor, isTrue);
    expect(makeProfile().suggestDoctor, isFalse);
  });

  test('json roundtrip', () {
    final p = Profile.decode(makeProfile().encode());
    expect(p.motivationText, 'дочь');
    expect(p.triggers, {Trigger.coffee});
    expect(p.quitMode, QuitMode.cold);
  });
}
