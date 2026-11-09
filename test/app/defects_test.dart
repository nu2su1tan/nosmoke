// Регрессионные тесты по найденным дефектам (D1..D9), см. отчёт.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/app/app.dart';
import 'package:nosmoke/app/session.dart';
import 'package:nosmoke/core/storage/json_list_store.dart';
import 'package:nosmoke/core/utils/formatters.dart';
import 'package:nosmoke/core/utils/number_parsing.dart';
import 'package:nosmoke/core/widgets/tick_builder.dart';
import 'package:nosmoke/features/diary/domain/craving_entry.dart';
import 'package:nosmoke/features/profile/data/profile_store.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class _ThrowingStore extends ProfileStore {
  bool fail = true;

  @override
  Future<Profile?> load() async {
    if (fail) throw StateError('storage unavailable');
    return super.load();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('D1 reset must not leave reminders scheduled', () {
    test('last notification call after wipe is cancel', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled_v1': true,
      });
      final fake = FakeNotificationService();
      final session = await Session.start(
        makeProfile(),
        makeServices(notifications: fake),
      );
      await session.diary.add(
        CravingEntry(id: '1', at: DateTime(2026, 1, 1, 9)),
      );
      expect(fake.events, contains('schedule'));

      await session.wipe();
      expect(fake.events.last, 'cancel');
      expect(session.settings.notificationsEnabled, isFalse);
      session.dispose();
    });
  });

  group('D2 startup failures', () {
    testWidgets('error screen with retry instead of an endless spinner', (
      tester,
    ) async {
      final store = _ThrowingStore();
      await tester.pumpWidget(
        NoSmokeApp(store: store, services: makeServices()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);

      store.fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ты уже сделал первый шаг'), findsOneWidget);
    });

    test('failing notification service does not break session start', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled_v1': true,
      });
      final session = await Session.start(
        makeProfile(),
        makeServices(
          notifications: FakeNotificationService(throwOnSchedule: true),
        ),
      );
      expect(session.settings.notificationsEnabled, isTrue);
      session.dispose();
    });
  });

  group('D3 one corrupted record must not wipe the list', () {
    test('valid records are kept', () async {
      final good = CravingEntry(id: 'ok', at: DateTime(2026, 1, 1, 8)).toJson();
      SharedPreferences.setMockInitialValues({
        'diary_v1': jsonEncode([
          good,
          {'garbage': 1},
          'not a map',
        ]),
      });
      final store = JsonListStore<CravingEntry>(
        key: 'diary_v1',
        fromJson: CravingEntry.fromJson,
        toJson: (e) => e.toJson(),
      );
      final items = await store.load();
      expect(items.map((e) => e.id), ['ok']);
    });
  });

  group('D4 day counts must not depend on daylight saving time', () {
    test('daysBetween ignores time of day and DST', () {
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 10)), 3);
      expect(daysBetween(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), 3);
      expect(daysBetween(DateTime(2026, 3, 7, 23), DateTime(2026, 3, 8, 1)), 1);
      expect(daysBetween(DateTime(2026, 3, 10), DateTime(2026, 3, 7)), -3);
    });

    test('daysInProgram is exact across the spring DST change', () {
      // Запускать также с TZ=America/New_York (перевод часов 8 марта 2026).
      final p = makeProfile(quitDate: DateTime(2026, 3, 7));
      final s = computeProgress(p, [], DateTime(2026, 3, 10));
      expect(s.daysInProgram, 3);
      expect(s.cigsAvoided, 60);
    });

    test('gradual limit around DST', () {
      final p = makeProfile(
        mode: QuitMode.gradual,
        quitDate: DateTime(2026, 3, 1),
      );
      expect(
        p.dailyLimit(DateTime(2026, 3, 8)),
        12,
      ); // ровно 7 дней = 2-я неделя
      expect(p.dailyLimit(DateTime(2026, 3, 7)), 16);
    });
  });

  group('D5 russian localization', () {
    testWidgets('material strings are russian', (tester) async {
      await tester.pumpWidget(NoSmokeApp(services: makeServices()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(MaterialLocalizations.of(ctx).cancelButtonLabel, 'Отмена');
      expect(Localizations.localeOf(ctx).languageCode, 'ru');
    });
  });

  group('D6 numbers typed the way people write them', () {
    test('parseDecimal', () {
      expect(parseDecimal('2 000'), 2000);
      expect(parseDecimal('2 000'), 2000);
      expect(parseDecimal('1,5'), 1.5);
      expect(parseDecimal('1 500,50'), 1500.5);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal(''), isNull);
    });
  });

  group('D7 hidden tabs do not tick', () {
    testWidgets('TickBuilder is paused when TickerMode is disabled', (
      tester,
    ) async {
      var builds = 0;
      Widget app(bool enabled) => TickerMode(
        enabled: enabled,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TickBuilder(
            builder: (context, now) {
              builds++;
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(app(false));
      final initial = builds;
      await tester.pump(const Duration(seconds: 5));
      expect(builds, initial);

      await tester.pumpWidget(app(true));
      final resumed = builds;
      await tester.pump(const Duration(seconds: 3));
      expect(builds, greaterThan(resumed));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('D8 progress math matches brute force', () {
    int brute(Profile p, DateTime now) {
      var total = 0.0;
      final start = DateTime(p.quitDate.year, p.quitDate.month, p.quitDate.day);
      var day = start;
      while (!day.isAfter(now)) {
        final next = DateTime(day.year, day.month, day.day + 1);
        // Целый календарный день считается целым (даже если в нём 23 или
        // 25 часов из-за перевода часов), последний неполный — по времени.
        final frac = next.isAfter(now)
            ? now.difference(day).inSeconds / Duration.secondsPerDay
            : 1.0;
        total += (p.cigsPerDay - p.dailyLimit(day)) * frac;
        day = next;
      }
      return total.floor();
    }

    test('cold and gradual, short and long periods', () {
      for (final mode in QuitMode.values) {
        for (final cigs in [1, 7, 20, 40]) {
          final p = makeProfile(
            mode: mode,
            cigs: cigs,
            quitDate: DateTime(2025, 6, 1),
          );
          for (final now in [
            DateTime(2025, 6, 1, 12),
            DateTime(2025, 6, 20, 5),
            DateTime(2025, 7, 10),
            DateTime(2027, 1, 15, 18, 30),
          ]) {
            final s = computeProgress(p, [], now);
            expect(s.cigsAvoided, brute(p, now), reason: '$mode $cigs $now');
          }
        }
      }
    });
  });
}
