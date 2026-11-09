import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/app/live_sync.dart';
import 'package:nosmoke/features/account/data/account_store.dart';
import 'package:nosmoke/features/account/presentation/account_controller.dart';
import 'package:nosmoke/features/home_widget/domain/widget_snapshot.dart';
import 'package:nosmoke/features/plan/presentation/plan_controller.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/relapse/data/relapse_store.dart';
import 'package:nosmoke/features/relapse/domain/relapse.dart';
import 'package:nosmoke/features/relapse/presentation/relapse_controller.dart';
import 'package:nosmoke/features/smoked/data/smoked_store.dart';
import 'package:nosmoke/features/smoked/presentation/smoked_controller.dart';
import 'package:nosmoke/features/supporters/data/supporters_repository.dart';
import 'package:nosmoke/features/supporters/presentation/supporters_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/in_process_server.dart';

void main() {
  group('buildWidgetSnapshot', () {
    test('streak: days, plural unit, money', () {
      final p = makeProfile(quitDate: DateTime(2026, 1, 1), currency: 'сом');
      final s = computeProgress(p, [], DateTime(2026, 1, 4, 10));
      final w = buildWidgetSnapshot(p, s, DateTime(2026, 1, 4, 10));
      expect(w.title, 'Без сигарет');
      expect(w.value, '3');
      expect(w.unit, 'дня');
      expect(w.subtitle, contains('сом'));
    });

    test('one day / many days', () {
      final p = makeProfile(quitDate: DateTime(2026, 1, 1));
      String unit(int d) => buildWidgetSnapshot(
        p,
        computeProgress(p, [], DateTime(2026, 1, 1 + d)),
        DateTime(2026, 1, 1 + d),
      ).unit;
      expect(unit(1), 'день');
      expect(unit(5), 'дней');
      expect(unit(21), 'день');
    });

    test('gradual ramp shows today\'s limit', () {
      final p = makeProfile(
        mode: QuitMode.gradual,
        quitDate: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 1, 8);
      final w = buildWidgetSnapshot(p, computeProgress(p, [], now), now);
      expect(w.title, 'Лимит на сегодня');
      expect(w.value, '12');
      expect(w.unit, 'сигарет');
    });

    test('before the start', () {
      final p = makeProfile(quitDate: DateTime(2026, 12, 1));
      final now = DateTime(2026, 11, 1);
      final w = buildWidgetSnapshot(p, computeProgress(p, [], now), now);
      expect(w.value, '—');
      expect(w.subtitle, 'Скоро старт');
    });

    test('after a relapse the counter restarts but the widget stays valid', () {
      final p = makeProfile(quitDate: DateTime(2026, 1, 1));
      final now = DateTime(2026, 1, 10, 12);
      final s = computeProgress(p, [
        Relapse(at: DateTime(2026, 1, 9, 12)),
      ], now);
      expect(buildWidgetSnapshot(p, s, now).value, '1');
    });

    test('equality and map for the native side', () {
      const a = WidgetSnapshot(
        title: 't',
        value: '1',
        unit: 'день',
        subtitle: 's',
      );
      const b = WidgetSnapshot(
        title: 't',
        value: '1',
        unit: 'день',
        subtitle: 's',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toMap(), {
        'title': 't',
        'value': '1',
        'unit': 'день',
        'subtitle': 's',
      });
    });
  });

  group('LiveSync', () {
    late FakeWidgetService widgets;
    late InProcessServer server;
    late AccountController account;
    late RelapseController relapses;
    late SmokedController smoked;
    late SupportersController supporters;

    LiveSync make({bool paywall = false, FakePurchaseService? store}) =>
        LiveSync(
          profile: makeProfile(
            quitDate: DateTime.now().subtract(const Duration(days: 5)),
          ),
          relapses: relapses,
          smoked: smoked,
          supporters: supporters,
          plan: PlanController(
            store ?? FakePurchaseService(),
            paywall: paywall,
          ),
          widgets: widgets,
          interval: const Duration(hours: 1),
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      widgets = FakeWidgetService();
      server = InProcessServer();
      account = AccountController(
        AccountStore(),
        clientFactory: server.clientFactory,
      );
      await account.connect(InProcessServer.baseUrl);
      relapses = RelapseController(relapseStore());
      smoked = SmokedController(smokedStore());
      supporters = SupportersController(() {
        final api = account.api;
        return api == null ? null : RemoteSupportersRepository(api);
      });
    });

    test('pushes the widget and the supporters summary', () async {
      final sync = make();
      await sync.sync();
      expect(widgets.updates, hasLength(1));
      expect(widgets.updates.single.value, '5');
      expect(server.db.progress[account.account!.userId]!['smokeFreeDays'], 5);
      sync.dispose();
    });

    test('the widget is updated only when its content changes', () async {
      final sync = make();
      await sync.sync();
      await sync.sync();
      expect(widgets.updates, hasLength(1));

      await relapses.add(Relapse(at: DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(widgets.updates.length, 2);
      expect(widgets.updates.last.value, '0');
      sync.dispose();
    });

    test('widgets are a premium feature when the paywall is on', () async {
      final store = FakePurchaseService();
      final sync = make(paywall: true, store: store);
      await sync.sync();
      expect(widgets.updates, isEmpty);
      // сводка для близких при этом всё равно уходит (это бесплатно)
      expect(server.db.progress, isNotEmpty);

      store.completePurchase();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sync.sync();
      expect(widgets.updates, hasLength(1));
      sync.dispose();
    });

    test('after dispose nothing is sent', () async {
      final sync = make();
      sync.dispose();
      await relapses.add(Relapse(at: DateTime.now()));
      await sync.sync();
      expect(widgets.updates, isEmpty);
    });

    test('works without a server', () async {
      final offline = SupportersController(() => null);
      final sync = LiveSync(
        profile: makeProfile(
          quitDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        relapses: relapses,
        smoked: smoked,
        supporters: offline,
        plan: PlanController(FakePurchaseService(), paywall: false),
        widgets: widgets,
        interval: const Duration(hours: 1),
      );
      await sync.sync();
      expect(widgets.updates, hasLength(1));
      sync.dispose();
    });
  });
}
