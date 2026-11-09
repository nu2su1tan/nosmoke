import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/diary/domain/diary_insights.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';

CravingEntry _e(
  int hour, {
  Trigger? trigger,
  String helped = '',
  bool overcame = true,
}) => CravingEntry(
  id: '$hour${trigger?.name}$helped$overcame',
  at: DateTime(2026, 1, 5, hour),
  trigger: trigger,
  helped: helped,
  overcame: overcame,
);

void main() {
  group('CravingEntry', () {
    test('helped survives json; old records without it still load', () {
      final e = _e(9, helped: 'Прогулка');
      expect(CravingEntry.fromJson(e.toJson()).helped, 'Прогулка');
      final old = e.toJson()..remove('helped');
      expect(CravingEntry.fromJson(old).helped, '');
    });

    test('coping options are unique', () {
      expect(copingActions.toSet(), hasLength(copingActions.length));
    });
  });

  group('helperFor', () {
    final entries = [
      _e(9, trigger: Trigger.coffee, helped: 'Прогулка'),
      _e(10, trigger: Trigger.coffee, helped: 'Прогулка'),
      _e(11, trigger: Trigger.coffee, helped: 'Вода'),
      _e(15, trigger: Trigger.stress, helped: 'Дыхание'),
      _e(16, trigger: Trigger.stress, helped: 'Дыхание'),
      _e(17, trigger: Trigger.stress, helped: 'Дыхание'),
      _e(18, trigger: Trigger.stress, helped: 'Вода'),
      // срыв не считается как «помогло»
      _e(19, trigger: Trigger.stress, helped: 'Вода', overcame: false),
      _e(20, trigger: Trigger.stress, helped: 'Вода', overcame: false),
    ];

    test('overall most frequent (failed attempts do not count)', () {
      // Дыхание 3, Прогулка 2, Вода 2 (две неудачные попытки не в счёте)
      expect(helperFor(entries, null), 'Дыхание');
    });

    test('per trigger', () {
      expect(helperFor(entries, Trigger.coffee), 'Прогулка');
      expect(helperFor(entries, Trigger.stress), 'Дыхание');
    });

    test('falls back to overall when the trigger has no data', () {
      expect(helperFor(entries, Trigger.alcohol), 'Дыхание');
    });

    test('null when nothing was ever marked', () {
      expect(helperFor([_e(9), _e(10)], null), isNull);
      expect(helperFor([], Trigger.coffee), isNull);
    });
  });

  test('insights include the top helper', () {
    final i = computeInsights([
      _e(9, trigger: Trigger.coffee, helped: 'Прогулка'),
      _e(9, trigger: Trigger.coffee, helped: 'Прогулка'),
      _e(9, trigger: Trigger.coffee),
    ]);
    expect(i.topHelper, 'Прогулка');
    expect(i.peakHour, 9);
  });

  group('upcomingRisk', () {
    const insights = DiaryInsights(
      peakHour: 14,
      topTrigger: Trigger.coffee,
      topHelper: 'Прогулка',
      total: 8,
    );

    RiskHint? at(int h, int m) =>
        upcomingRisk(insights, DateTime(2026, 1, 5, h, m));

    test('active 30 minutes before and during the peak hour', () {
      expect(at(13, 29), isNull);
      expect(at(13, 30), isNotNull);
      expect(at(13, 59), isNotNull);
      expect(at(14, 0), isNotNull);
      expect(at(14, 59), isNotNull);
      expect(at(15, 0), isNull);
    });

    test('text names the trigger and what helped last time', () {
      final hint = at(13, 45)!;
      expect(hint.title, 'Скоро опасное время');
      expect(hint.body, contains('кофе'));
      expect(hint.body, contains('В прошлый раз помогло: прогулка'));
    });

    test('without a helper it suggests preparing a plan', () {
      const i = DiaryInsights(peakHour: 14, total: 5);
      final hint = upcomingRisk(i, DateTime(2026, 1, 5, 14, 10))!;
      expect(hint.body, contains('Приготовь план'));
    });

    test('no peak -> no hint', () {
      expect(
        upcomingRisk(const DiaryInsights(total: 1), DateTime(2026, 1, 5, 14)),
        isNull,
      );
    });

    test('window across midnight for a 00:xx peak', () {
      const i = DiaryInsights(peakHour: 0, total: 5);
      expect(upcomingRisk(i, DateTime(2026, 1, 5, 23, 40)), isNotNull);
      expect(upcomingRisk(i, DateTime(2026, 1, 5, 0, 20)), isNotNull);
      expect(upcomingRisk(i, DateTime(2026, 1, 5, 12)), isNull);
    });
  });
}
