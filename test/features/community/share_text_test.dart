import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/community/domain/share_text.dart';
import 'package:nosmoke/features/community/domain/tips.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';

import '../../helpers/fakes.dart';

void main() {
  final p = makeProfile();

  test('share text with a streak', () {
    final s = computeProgress(p, [], DateTime(2026, 1, 4));
    final t = buildShareText(p, s);
    expect(t, contains('Я не курю уже 3 дня'));
    expect(t, contains('60 ₸'.replaceAll('60', '6000')));
    expect(t, endsWith('#NoSmoke'));
  });

  test('plural forms', () {
    String forDays(int d) =>
        buildShareText(p, computeProgress(p, [], DateTime(2026, 1, 1 + d)));
    expect(forDays(1), contains('1 день'));
    expect(forDays(2), contains('2 дня'));
    expect(forDays(5), contains('5 дней'));
    expect(forDays(11), contains('11 дней'));
    expect(forDays(21), contains('21 день'));
  });

  test('right after a relapse we talk about the journey, not a streak', () {
    final r = [Relapse(at: DateTime(2026, 1, 4, 10))];
    final s = computeProgress(p, r, DateTime(2026, 1, 4, 12));
    expect(buildShareText(p, s), contains('уже 3 дня в пути'));
  });

  test('before the start', () {
    final s = computeProgress(p, [], DateTime(2025, 12, 1));
    expect(buildShareText(p, s), contains('начинаю скоро'));
  });

  test('tips are not empty', () {
    expect(supportTips, isNotEmpty);
    for (final t in supportTips) {
      expect(t.title, isNotEmpty);
      expect(t.body, isNotEmpty);
    }
  });
}
