import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/health_data/data/health_source.dart';
import 'package:nosmoke/features/health_data/domain/health_metrics.dart';
import 'package:nosmoke/features/health_data/presentation/health_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

List<DailyHealth> run(DateTime from, int n, {double? hr, int? steps}) => [
  for (var i = 0; i < n; i++)
    DailyHealth(
      day: DateTime(from.year, from.month, from.day + i),
      restingHr: hr,
      steps: steps,
    ),
];

void main() {
  // отказ 1 ноября; «сейчас» 20 ноября
  final quit = DateTime(2026, 11, 1);
  final now = DateTime(2026, 11, 20, 18);

  group('computeHealthTrend', () {
    test('compares 14 days before with the last 14 days', () {
      final days = [
        ...run(DateTime(2026, 10, 18), 14, hr: 78, steps: 4000),
        ...run(DateTime(2026, 11, 7), 14, hr: 72, steps: 6500),
      ];
      final t = computeHealthTrend(days, quit, now);
      expect(t.restingHrBefore, 78);
      expect(t.restingHrAfter, 72);
      expect(t.heartRateDelta, -6);
      expect(t.stepsDelta, 2500);
      expect(t.isEmpty, isFalse);
    });

    test('needs at least 3 days with data on each side', () {
      final days = [
        ...run(DateTime(2026, 10, 30), 2, hr: 78), // всего 2 дня до
        ...run(DateTime(2026, 11, 10), 10, hr: 72),
      ];
      final t = computeHealthTrend(days, quit, now);
      expect(t.restingHrBefore, isNull);
      expect(t.restingHrAfter, 72);
      expect(t.heartRateDelta, isNull); // нет базы: дельты нет, но текущее есть
      expect(t.hasHeartRate, isTrue);
    });

    test('days without a value do not count', () {
      final days = [
        ...run(DateTime(2026, 11, 7), 14), // пустые дни
      ];
      expect(computeHealthTrend(days, quit, now).isEmpty, isTrue);
    });

    test('days before quitting never leak into the "after" window', () {
      final days = run(DateTime(2026, 10, 18), 14, hr: 80);
      final t = computeHealthTrend(days, quit, DateTime(2026, 11, 5));
      expect(t.restingHrAfter, isNull);
      expect(t.restingHrBefore, 80);
    });

    test('a quit date inside the last window shortens "after"', () {
      final days = run(DateTime(2026, 11, 17), 4, hr: 70);
      final t = computeHealthTrend(days, DateTime(2026, 11, 17), now);
      expect(t.restingHrAfter, 70);
    });

    test('empty input', () {
      expect(computeHealthTrend([], quit, now).isEmpty, isTrue);
    });
  });

  group('HealthController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'connect → granted → loads the trend and remembers the choice',
      () async {
        final source = FakeHealthSource(
          days: [
            ...run(DateTime(2026, 10, 18), 14, hr: 78, steps: 4000),
            ...run(DateTime(2026, 11, 7), 14, hr: 72, steps: 6500),
          ],
        );
        final c = HealthController(source);
        expect(await c.connect(quit, now), HealthAccess.granted);
        expect(c.connected, isTrue);
        expect(c.trend.heartRateDelta, -6);

        final again = HealthController(source);
        await again.load();
        expect(again.connected, isTrue);
      },
    );

    test('denied and unavailable stay disconnected', () async {
      for (final a in [HealthAccess.denied, HealthAccess.unavailable]) {
        final c = HealthController(FakeHealthSource(access: a));
        expect(await c.connect(quit, now), a);
        expect(c.connected, isFalse);
        expect(c.trend.isEmpty, isTrue);
      }
    });

    test('refresh does nothing while disconnected', () async {
      final source = FakeHealthSource();
      final c = HealthController(source);
      await c.refresh(quit, now);
      expect(c.trend.isEmpty, isTrue);
    });

    test('clear forgets everything', () async {
      final c = HealthController(FakeHealthSource());
      await c.connect(quit, now);
      await c.clear();
      expect(c.connected, isFalse);
      final again = HealthController(FakeHealthSource());
      await again.load();
      expect(again.connected, isFalse);
    });
  });
}
