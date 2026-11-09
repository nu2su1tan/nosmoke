import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';

import '../../helpers/fakes.dart';

void main() {
  final cold = makeProfile(); // старт 2026-01-01, 20 сиг/день, 100 за сигарету

  test('before the start date everything is zero', () {
    final s = computeProgress(cold, [], DateTime(2025, 12, 31, 12));
    expect(s.started, isFalse);
    expect(s.cigsAvoided, 0);
    expect(s.moneySaved, 0);
  });

  test('cold turkey: full days', () {
    final s = computeProgress(cold, [], DateTime(2026, 1, 3));
    expect(s.started, isTrue);
    expect(s.daysInProgram, 2);
    expect(s.cigsAvoided, 40);
    expect(s.moneySaved, 4000);
    expect(s.lifeRegained, const Duration(minutes: 40 * minutesPerCigarette));
    expect(s.smokeFree, const Duration(days: 2));
    expect(s.streakActive, isTrue);
  });

  test('cold turkey: part of today counts', () {
    final s = computeProgress(cold, [], DateTime(2026, 1, 3, 12));
    expect(s.cigsAvoided, 50);
  });

  test('relapse resets the streak but not the program progress', () {
    final r = Relapse(at: DateTime(2026, 1, 2, 10), count: 2);
    final s = computeProgress(cold, [r], DateTime(2026, 1, 3));
    expect(s.daysInProgram, 2);
    expect(s.cigsAvoided, 38);
    expect(s.relapseCount, 1);
    expect(s.smokeFree, const Duration(hours: 14));
    // Лучшая серия: с 1 января до срыва 2 января 10:00.
    expect(s.bestStreak, const Duration(hours: 34));
  });

  test('best streak survives a later relapse', () {
    final r = Relapse(at: DateTime(2026, 1, 11));
    final s = computeProgress(cold, [r], DateTime(2026, 1, 12));
    expect(s.smokeFree, const Duration(days: 1));
    expect(s.bestStreak, const Duration(days: 10));
  });

  test('relapses never push cigsAvoided below zero', () {
    final r = Relapse(at: DateTime(2026, 1, 1, 1), count: 500);
    final s = computeProgress(cold, [r], DateTime(2026, 1, 2));
    expect(s.cigsAvoided, 0);
  });

  test('relapse before the start is ignored', () {
    final r = Relapse(at: DateTime(2025, 12, 1), count: 5);
    final s = computeProgress(cold, [r], DateTime(2026, 1, 2));
    expect(s.relapseCount, 0);
    expect(s.cigsAvoided, 20);
  });

  group('gradual', () {
    final g = makeProfile(mode: QuitMode.gradual);

    test('counts only the reduction and has no streak yet', () {
      final s = computeProgress(g, [], DateTime(2026, 1, 8));
      expect(s.cigsAvoided, 28); // 7 дней * (20 - 16)
      expect(s.streakActive, isFalse);
      expect(s.smokeFree, Duration.zero);
    });

    test('streak starts at full quit date', () {
      final s = computeProgress(g, [], DateTime(2026, 2, 1));
      expect(s.streakActive, isTrue);
      expect(s.smokeFree, const Duration(days: 3));
    });
  });
}
