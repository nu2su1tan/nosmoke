import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/app/app.dart';
import 'package:nosmoke/core/ui/app_button.dart';
import 'package:nosmoke/core/ui/app_chip.dart';
import 'package:nosmoke/features/sos/presentation/sos_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Высокий экран, чтобы все элементы помещались без прокрутки.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Env {
  _Env(this.notifications, this.dialer, this.sharer);

  final FakeNotificationService notifications;
  final FakeDialer dialer;
  final FakeSharer sharer;
}

Future<_Env> _pumpHome(
  WidgetTester tester, {
  bool grant = true,
  bool dialSucceeds = true,
  Map<String, Object> extraPrefs = const {},
}) async {
  _tallScreen(tester);
  final today = DateTime.now();
  final profile = makeProfile(
    quitDate: DateTime(today.year, today.month, today.day - 3),
  );
  SharedPreferences.setMockInitialValues({
    'profile_v1': profile.encode(),
    ...extraPrefs,
  });
  final env = _Env(
    FakeNotificationService(grant: grant),
    FakeDialer(succeed: dialSucceeds),
    FakeSharer(),
  );
  await tester.pumpWidget(
    NoSmokeApp(
      services: makeServices(
        notifications: env.notifications,
        dialer: env.dialer,
        sharer: env.sharer,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return env;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text(label),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Два кадра: первый запускает анимацию, второй её завершает.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('onboarding: currency is required, then home shows it', (
    tester,
  ) async {
    _tallScreen(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(NoSmokeApp(services: makeServices()));
    await tester.pumpAndSettle();

    expect(find.text('Ты уже сделал первый шаг'), findsOneWidget);
    await tester.tap(find.byType(AppButton)); // начать
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton)); // сигареты
    await tester.pumpAndSettle();

    // Шаг «цена»: без валюты дальше нельзя.
    expect(find.text('Сколько стоит пачка?'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.tap(find.widgetWithText(AppChip, '₽'));
    await tester.pump();
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
    }
    expect(find.text('Твой план готов'), findsOneWidget);
    expect(find.textContaining('₽'), findsWidgets);

    await tester.tap(find.byType(AppButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('БЕЗ СИГАРЕТ'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('onboarding: custom currency', (tester) async {
    _tallScreen(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(NoSmokeApp(services: makeServices()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppChip, 'Другая'));
    await tester.pump();
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('custom-currency')), 'тг');
    await tester.pump();
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    await _dispose(tester);
  });

  testWidgets('home shows progress stats', (tester) async {
    await _pumpHome(tester);
    expect(find.text('БЕЗ СИГАРЕТ'), findsOneWidget);
    expect(find.text('СЭКОНОМЛЕНО'), findsOneWidget);
    expect(find.textContaining('₸'), findsWidgets); // валюта пользователя
    expect(find.text('НЕ ВЫКУРЕНО'), findsOneWidget);
    expect(find.textContaining('Дней в программе: 3'), findsOneWidget);
    expect(find.textContaining('СЛЕДУЮЩАЯ ВЕХА'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('SOS: timer counts down and overcame is logged to the diary', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Хочу курить'));
    await _settle(tester);

    expect(find.text('Тяга пройдёт'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SosScreen),
        matching: find.text('«дочь»'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sos-timer')), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    final timer = tester.widget<Text>(find.byKey(const Key('sos-timer')));
    expect(timer.data, anyOf('04:57', '04:56'));

    await tester.tap(find.widgetWithText(AppChip, 'Кофе'));
    await tester.pump();
    await tester.ensureVisible(find.text('Справился(ась)'));
    await tester.tap(find.text('Справился(ась)'));
    await _settle(tester);
    expect(find.text('Молодец! Ещё одна тяга позади.'), findsOneWidget);

    await _openTab(tester, 'Дневник');
    expect(find.text('Кофе'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('SOS: relapse path opens the relapse sheet', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Хочу курить'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Всё же закурил(а)'));
    await tester.tap(find.text('Всё же закурил(а)'));
    await _settle(tester);
    expect(find.text('Бывает. Это не конец'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('relapse keeps the program progress and shows support', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Я сорвался(ась)'));
    await _settle(tester);
    expect(find.text('Бывает. Это не конец'), findsOneWidget);

    await tester.tap(find.text('Записать и продолжить'));
    await _settle(tester);

    expect(find.textContaining('Это часть пути'), findsOneWidget);
    expect(find.textContaining('Дней в программе: 3'), findsOneWidget);
    expect(find.textContaining('срывов: 1'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('diary: add an entry manually', (tester) async {
    await _pumpHome(tester);
    await _openTab(tester, 'Дневник');
    expect(find.textContaining('Записей пока нет'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить запись'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(AppChip, 'Стресс'));
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await _settle(tester);

    expect(find.text('Стресс'), findsOneWidget);
    expect(find.textContaining('Записей пока нет'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('health: timeline and achievements', (tester) async {
    await _pumpHome(tester);
    await _openTab(tester, 'Здоровье');
    expect(find.text('20 минут'), findsOneWidget);
    expect(find.text('24 часа'), findsOneWidget);

    await tester.tap(find.text('Достижения'));
    await _settle(tester);
    expect(
      find.byKey(const Key('achievement-streak_3-unlocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('achievement-streak_7-locked')),
      findsOneWidget,
    );
    await _dispose(tester);
  });

  testWidgets(
    'settings: enabling reminders requests permission and schedules',
    (tester) async {
      final env = await _pumpHome(tester);
      final fake = env.notifications;
      await _openTab(tester, 'Настройки');
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(fake.permissionRequests, 1);
      expect(fake.scheduled, isNotEmpty);
      expect(fake.scheduled.last.length, greaterThanOrEqualTo(2));
      expect(
        tester
            .widget<CupertinoSwitch>(find.byType(CupertinoSwitch).first)
            .value,
        isTrue,
      );

      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.cancelAllCalls, 1);
      await _dispose(tester);
    },
  );

  testWidgets('settings: denied permission keeps reminders off', (
    tester,
  ) async {
    final env = await _pumpHome(tester, grant: false);
    final fake = env.notifications;
    await _openTab(tester, 'Настройки');
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch).first).value,
      isFalse,
    );
    expect(fake.scheduled, isEmpty);
    expect(find.textContaining('Нет разрешения'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('settings: reset wipes data and returns to onboarding', (
    tester,
  ) async {
    final env = await _pumpHome(tester);
    final fake = env.notifications;
    await _openTab(tester, 'Настройки');
    await tester.tap(find.text('Начать заново'));
    await _settle(tester);
    await tester.tap(find.text('Удалить'));
    await _settle(tester);

    expect(find.text('Ты уже сделал первый шаг'), findsOneWidget);
    expect(fake.cancelAllCalls, greaterThanOrEqualTo(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_v1'), isNull);
    await _dispose(tester);
  });

  testWidgets('SOS: call a friend asks for a contact first, then dials', (
    tester,
  ) async {
    final env = await _pumpHome(tester);
    await tester.tap(find.text('Хочу курить'));
    await _settle(tester);

    await tester.ensureVisible(find.text('Позвонить другу'));
    await tester.tap(find.text('Позвонить другу'));
    await _settle(tester);
    expect(find.text('Кому звонить в трудную минуту?'), findsOneWidget);

    // Некорректный номер не принимается.
    await tester.enterText(find.byKey(const Key('friend-phone')), '12');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(find.text('Введи корректный номер'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('friend-name')), 'Айдос');
    await tester.enterText(
      find.byKey(const Key('friend-phone')),
      '+7 (777) 123-45-67',
    );
    await tester.tap(find.text('Сохранить'));
    await _settle(tester);

    expect(env.dialer.calls, ['+77771234567']);
    expect(find.text('Позвонить: Айдос'), findsOneWidget);

    // Второй раз звоним сразу, без диалога.
    await tester.tap(find.text('Позвонить: Айдос'));
    await _settle(tester);
    expect(env.dialer.calls, hasLength(2));
    await _dispose(tester);
  });

  testWidgets('SOS: shows an error when the phone cannot be opened', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      dialSucceeds: false,
      extraPrefs: {
        'friend_name_v1': 'Аружан',
        'friend_phone_v1': '+77001112233',
      },
    );
    await tester.tap(find.text('Хочу курить'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Позвонить: Аружан'));
    await tester.tap(find.text('Позвонить: Аружан'));
    await _settle(tester);
    expect(find.text('Не удалось открыть телефон'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('settings: friend can be edited and removed', (tester) async {
    await _pumpHome(
      tester,
      extraPrefs: {
        'friend_name_v1': 'Аружан',
        'friend_phone_v1': '+77001112233',
      },
    );
    await _openTab(tester, 'Настройки');
    expect(find.textContaining('Аружан'), findsOneWidget);
    await tester.tap(find.byTooltip('Удалить контакт'));
    await tester.pump();
    expect(find.text('Не задан'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('friend_phone_v1'), isNull);
    await _dispose(tester);
  });

  testWidgets('settings: user can change the currency', (tester) async {
    await _pumpHome(tester);
    await _openTab(tester, 'Главная');
    expect(find.textContaining('₸'), findsWidgets);

    await _openTab(tester, 'Настройки');
    await tester.tap(find.text('Валюта'));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('currency-field')), 'сом');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await _settle(tester);
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_v1'), contains('"currency":"сом"'));
    await _openTab(tester, 'Главная');
    expect(find.textContaining('сом'), findsWidgets);
    expect(find.textContaining('₸'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('community: join a challenge, then leave', (tester) async {
    await _pumpHome(tester);
    await _openTab(tester, 'Сообщество');
    expect(find.text('Неделя без срывов'), findsOneWidget);

    await tester.tap(find.text('Принять вызов').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('из 7 дн.'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);

    await tester.tap(find.text('Выйти'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('из 7 дн.'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('community: cravings challenge progresses from the diary', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openTab(tester, 'Сообщество');
    // «10 побед над тягой» — четвёртая карточка.
    await tester.ensureVisible(find.text('10 побед над тягой'));
    await tester.tap(find.text('Принять вызов').at(3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0 из 10 раз'), findsOneWidget);

    await _openTab(tester, 'Главная');
    await tester.tap(find.text('Хочу курить'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Справился(ась)'));
    await tester.tap(find.text('Справился(ась)'));
    await _settle(tester);

    await _openTab(tester, 'Сообщество');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 из 10 раз'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('community: share progress and tips', (tester) async {
    final env = await _pumpHome(tester);
    await _openTab(tester, 'Сообщество');
    await tester.tap(find.text('Поддержка'));
    await _settle(tester);

    expect(find.text('Тяга проходит сама'), findsOneWidget);
    await tester.tap(find.text('Поделиться прогрессом'));
    await tester.pump();
    expect(env.sharer.shared, hasLength(1));
    expect(env.sharer.shared.single, contains('Я не курю уже 3 дня'));
    expect(env.sharer.shared.single, contains('₸'));
    await _dispose(tester);
  });
}
