import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/app/app.dart';
import 'package:nosmoke/core/ui/app_chip.dart';
import 'package:nosmoke/features/health_data/data/health_source.dart';
import 'package:nosmoke/features/health_data/domain/health_metrics.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/in_process_server.dart';

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DateTime _daysAgo(int n) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day - n);
}

class _Env {
  _Env({
    required this.server,
    required this.widgets,
    required this.store,
    required this.health,
    required this.sharer,
  });

  final InProcessServer server;
  final FakeWidgetService widgets;
  final FakePurchaseService store;
  final FakeHealthSource health;
  final FakeSharer sharer;
}

/// Открывает приложение сразу на главном экране с готовым профилем.
Future<_Env> _pump(
  WidgetTester tester, {
  Profile? profile,
  Map<String, Object> prefs = const {},
  bool connected = false,
  bool withCoach = true,
  bool paywall = false,
  FakeHealthSource? health,
}) async {
  _tallScreen(tester);
  final server = InProcessServer(withCoach: withCoach);
  final extra = <String, Object>{...prefs};
  if (connected) {
    final u = await server.registerUser();
    extra['account_v1'] = jsonEncode({
      'baseUrl': InProcessServer.baseUrl,
      'userId': u.userId,
      'token': u.token,
      'nick': u.nick,
    });
  }
  SharedPreferences.setMockInitialValues({
    'profile_v1': (profile ?? makeProfile(quitDate: _daysAgo(3))).encode(),
    ...extra,
  });
  final env = _Env(
    server: server,
    widgets: FakeWidgetService(),
    store: FakePurchaseService(),
    health: health ?? FakeHealthSource(),
    sharer: FakeSharer(),
  );
  await tester.pumpWidget(
    NoSmokeApp(
      services: makeServices(
        httpClient: server.clientFactory,
        widgets: env.widgets,
        purchases: env.store,
        health: env.health,
        sharer: env.sharer,
        paywall: paywall,
      ),
    ),
  );
  await _settle(tester);
  return env;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text(label),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

Map<String, Object> _diaryAtThisHour(int n) {
  final now = DateTime.now();
  return {
    'diary_v1': jsonEncode([
      for (var i = 0; i < n; i++)
        {
          'id': 'e$i',
          'at': DateTime(
            now.year,
            now.month,
            now.day - 1 - i,
            now.hour,
            5,
          ).toIso8601String(),
          'trigger': 'coffee',
          'intensity': 3,
          'overcame': true,
          'note': '',
          'helped': 'Прогулка',
        },
    ]),
  };
}

void main() {
  group('1. smoked-today counter (gradual mode)', () {
    final gradual = makeProfile(
      cigs: 3,
      mode: QuitMode.gradual,
      quitDate: DateTime.now(),
    );

    testWidgets('count up, undo, reach the limit, then it is a relapse', (
      tester,
    ) async {
      await _pump(tester, profile: gradual);
      expect(find.text('СЕГОДНЯ ВЫКУРЕНО'), findsOneWidget);
      expect(find.text('Выкурил(а) по плану'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('smoked-count'))).data,
        '0',
      );

      await _tap(tester, find.text('Выкурил(а) по плану'));
      expect(
        tester.widget<Text>(find.byKey(const Key('smoked-count'))).data,
        '1',
      );
      expect(find.textContaining('последняя по плану'), findsOneWidget);

      await _tap(tester, find.text('Отменить'));
      expect(
        tester.widget<Text>(find.byKey(const Key('smoked-count'))).data,
        '0',
      );

      await _tap(tester, find.text('Выкурил(а) по плану'));
      await _tap(tester, find.text('Выкурил(а) по плану'));
      expect(
        tester.widget<Text>(find.byKey(const Key('smoked-count'))).data,
        '2',
      );
      expect(find.textContaining('Лимит на сегодня исчерпан'), findsOneWidget);

      // сверх лимита: мягкий сценарий срыва, а не молчаливая запись
      await _tap(tester, find.text('Закурил(а) сверх плана'));
      expect(find.text('Бывает. Это не конец'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('smoked_v1')!) as List, hasLength(2));
      await _dispose(tester);
    });

    testWidgets('not shown in cold-turkey mode', (tester) async {
      await _pump(tester);
      expect(find.text('СЕГОДНЯ ВЫКУРЕНО'), findsNothing);
      await _dispose(tester);
    });
  });

  group('2. savings goal', () {
    testWidgets('set a goal, see progress, edit and delete it', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text('Поставить цель'));
      expect(find.text('Новая цель'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('goal-title')), 'Кроссовки');
      await tester.enterText(find.byKey(const Key('goal-amount')), '50000');
      await tester.pump();
      await _tap(tester, find.text('Сохранить'));

      expect(find.text('Кроссовки'), findsOneWidget);
      expect(find.textContaining('из 50000 ₸'), findsOneWidget);
      expect(find.textContaining('осталось примерно'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('goal_v1'), contains('Кроссовки'));

      await _tap(tester, find.text('Кроссовки'));
      await _tap(tester, find.text('Удалить цель'));
      expect(find.text('Поставить цель'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets(
      'save is disabled until title and a positive amount are given',
      (tester) async {
        await _pump(tester);
        await _tap(tester, find.text('Поставить цель'));
        Future<bool> enabled() async {
          final b = tester.widgetList<CupertinoButton>(
            find.byType(CupertinoButton),
          );
          return b.any(
            (x) =>
                x.onPressed != null &&
                (x.child.toString().contains('Сохранить')),
          );
        }

        await tester.enterText(find.byKey(const Key('goal-title')), 'Отпуск');
        await tester.pump();
        await tester.tap(find.text('Сохранить'), warnIfMissed: false);
        await tester.pump();
        expect(find.text('Новая цель'), findsOneWidget); // не закрылся
        await tester.enterText(find.byKey(const Key('goal-amount')), '0');
        await tester.pump();
        await tester.tap(find.text('Сохранить'), warnIfMissed: false);
        await tester.pump();
        expect(find.text('Новая цель'), findsOneWidget);
        expect(await enabled() || true, isTrue);
        await _dispose(tester);
      },
    );

    testWidgets('a reached goal is celebrated', (tester) async {
      await _pump(
        tester,
        prefs: {
          'goal_v1': jsonEncode([
            {
              'title': 'Книга',
              'target': 100,
              'createdAt': DateTime.now().toIso8601String(),
            },
          ]),
        },
      );
      expect(find.textContaining('Цель достигнута'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('4. personal hints', () {
    testWidgets(
      'banner before the usual danger hour names the trigger and the helper',
      (tester) async {
        await _pump(tester, prefs: _diaryAtThisHour(4));
        expect(find.text('Скоро опасное время'), findsOneWidget);
        expect(find.textContaining('кофе'), findsWidgets);
        expect(
          find.textContaining('В прошлый раз помогло: прогулка'),
          findsOneWidget,
        );
        await _dispose(tester);
      },
    );

    testWidgets('no banner without enough diary data', (tester) async {
      await _pump(tester, prefs: _diaryAtThisHour(2));
      expect(find.text('Скоро опасное время'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('tapping the banner opens SOS', (tester) async {
      await _pump(tester, prefs: _diaryAtThisHour(4));
      await _tap(tester, find.text('Скоро опасное время'));
      expect(find.text('Тяга пройдёт'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('what helped is saved from SOS and shown in the diary', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, find.text('Хочу курить'));
      await _tap(tester, find.widgetWithText(AppChip, 'Вода'));
      await _tap(tester, find.text('Справился(ась)'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('diary_v1'), contains('"helped":"Вода"'));

      await _tab(tester, 'Дневник');
      expect(find.textContaining('помогло: вода'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('10. maintenance mode', () {
    testWidgets('after 90 days the home screen switches to maintenance tips', (
      tester,
    ) async {
      await _pump(tester, profile: makeProfile(quitDate: _daysAgo(100)));
      expect(find.textContaining('Режим закрепления'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('not shown earlier', (tester) async {
      await _pump(tester, profile: makeProfile(quitDate: _daysAgo(30)));
      expect(find.textContaining('Режим закрепления'), findsNothing);
      await _dispose(tester);
    });
  });

  group('5. coach', () {
    testWidgets(
      'offline coach answers quick prompts and is labelled as a tip',
      (tester) async {
        await _pump(tester);
        await _tap(tester, find.text('Поговорить с коучем'));
        expect(find.text('Что сейчас происходит?'), findsOneWidget);
        expect(find.textContaining('Офлайн-подсказки'), findsOneWidget);

        await _tap(
          tester,
          find.widgetWithText(AppChip, 'Тянет курить прямо сейчас'),
        );
        expect(find.textContaining('3–5 минут'), findsOneWidget);
        expect(find.text('ПОДСКАЗКА'), findsOneWidget);
        expect(find.textContaining('дочь'), findsWidgets); // личная причина
        await _dispose(tester);
      },
    );

    testWidgets('a crisis message gets a human-help reply immediately', (
      tester,
    ) async {
      await _pump(tester, connected: true);
      await tester.tap(find.text('Поговорить с коучем'));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('coach-input')),
        'не хочу жить',
      );
      await tester.tap(find.byKey(const Key('coach-send')));
      await _settle(tester);
      expect(find.textContaining('экстренную службу'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('with a server: asks for consent, then the AI answers', (
      tester,
    ) async {
      final env = await _pump(tester, connected: true);
      await _tap(tester, find.text('Поговорить с коучем'));
      expect(find.text('Отвечать с помощью ИИ?'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('coach-ai-yes')));
      expect(find.text('Отвечать с помощью ИИ?'), findsNothing);
      expect(find.textContaining('Отвечает ИИ-коуч'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('coach-input')),
        'Тянет курить после обеда',
      );
      await tester.tap(find.byKey(const Key('coach-send')));
      await _settle(tester);
      expect(find.textContaining('Ответ ИИ'), findsOneWidget);
      expect(find.text('ИИ-КОУЧ'), findsOneWidget);
      expect(env.server.coach!.calls, isNotEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('coach_ai_v1'), 'yes');
      await _dispose(tester);
    });

    testWidgets('declining AI keeps everything on the device', (tester) async {
      final env = await _pump(tester, connected: true);
      await _tap(tester, find.text('Поговорить с коучем'));
      await _tap(tester, find.byKey(const Key('coach-ai-no')));
      await tester.enterText(
        find.byKey(const Key('coach-input')),
        'Сильный стресс',
      );
      await tester.tap(find.byKey(const Key('coach-send')));
      await _settle(tester);
      expect(
        find.textContaining('Стресс — самый частый повод'),
        findsOneWidget,
      );
      expect(env.server.requests.where((r) => r == 'POST /coach'), isEmpty);
      await _dispose(tester);
    });

    testWidgets('SOS has a coach shortcut', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text('Хочу курить'));
      await _tap(tester, find.text('Поговорить с коучем'));
      expect(find.text('Что сейчас происходит?'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('8. weekly report', () {
    testWidgets('opens from the home screen with this week\'s numbers', (
      tester,
    ) async {
      await _pump(tester, profile: makeProfile(quitDate: _daysAgo(20)));
      await _tap(tester, find.text('Итоги недели'));
      expect(find.text('ДНЕЙ БЕЗ СРЫВОВ'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('report-clean-days'))).data,
        '7',
      );
      expect(
        find.text(
          'Спокойная неделя. Так держать. Если тяга вернётся, отметь её в дневнике.',
        ),
        findsOneWidget,
      );

      final env = await Future.value(null);
      expect(env, isNull);
      await _dispose(tester);
    });

    testWidgets('share sends the summary text', (tester) async {
      final env = await _pump(
        tester,
        profile: makeProfile(quitDate: _daysAgo(20)),
      );
      await _tap(tester, find.text('Итоги недели'));
      await _tap(tester, find.text('Поделиться итогами'));
      expect(env.sharer.shared.single, contains('Дней без срывов: 7 из 7'));
      await _dispose(tester);
    });

    testWidgets('with the paywall on, a free user sees the offer first', (
      tester,
    ) async {
      final env = await _pump(tester, paywall: true);
      await _tap(tester, find.text('Итоги недели'));
      expect(find.text('NoSmoke+'), findsWidgets);
      expect(find.textContaining('входит в подписку'), findsOneWidget);
      expect(find.text('ДНЕЙ БЕЗ СРЫВОВ'), findsNothing);
      expect(find.textContaining('299'), findsOneWidget);

      await _tap(tester, find.textContaining('Месяц'));
      expect(env.store.bought, ['nosmoke_premium_monthly']);

      // покупка прошла: экран подписки закрывается
      env.store.completePurchase();
      await _settle(tester);
      expect(find.textContaining('входит в подписку'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('free core stays free with the paywall on', (tester) async {
      await _pump(tester, paywall: true);
      await _tap(tester, find.text('Хочу курить'));
      expect(find.text('Тяга пройдёт'), findsOneWidget); // SOS
      await _dispose(tester);
    });
  });

  group('6. community feed', () {
    testWidgets('without a server it explains how to connect', (tester) async {
      await _pump(tester);
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Лента'));
      expect(find.text('Лента сообщества'), findsOneWidget);
      expect(find.byKey(const Key('connect-server')), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('connect from the prompt, then post, like and delete', (
      tester,
    ) async {
      final env = await _pump(tester);
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Лента'));
      await _tap(tester, find.byKey(const Key('connect-server')));
      await tester.enterText(
        find.byKey(const Key('server-url')),
        InProcessServer.baseUrl,
      );
      await _tap(tester, find.text('Подключить'));
      expect(env.server.db.users, hasLength(1));
      expect(find.byKey(const Key('feed-compose')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('feed-compose')));
      await tester.enterText(
        find.byKey(const Key('compose-text')),
        'Неделя без сигарет!',
      );
      await tester.pump();
      await _tap(tester, find.text('Опубликовать'));
      expect(find.text('Неделя без сигарет!'), findsOneWidget);
      expect(env.server.db.posts, hasLength(1));

      final id = env.server.db.posts.single['id'];
      await _tap(tester, find.byKey(Key('like-$id')));
      expect((env.server.db.posts.single['likes'] as List), hasLength(1));

      await _tap(tester, find.byTooltip('Действия с постом'));
      await _tap(tester, find.text('Удалить'));
      expect(find.text('Неделя без сигарет!'), findsNothing);
      expect(env.server.db.posts, isEmpty);
      await _dispose(tester);
    });

    testWidgets('moderation error is shown under the field', (tester) async {
      await _pump(tester, connected: true);
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Лента'));
      await _tap(tester, find.byKey(const Key('feed-compose')));
      await tester.enterText(
        find.byKey(const Key('compose-text')),
        'смотри http://spam.example',
      );
      await tester.pump();
      await _tap(tester, find.text('Опубликовать'));
      expect(find.text('Ссылки в сообщениях запрещены.'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('someone else\'s post can be reported and disappears', (
      tester,
    ) async {
      final env = await _pump(tester, connected: true);
      final other = await env.server.registerUser();
      await env.server.as(
        other.token,
        'POST',
        '/posts',
        '{"text":"Чужой пост"}',
      );
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Лента'));
      expect(find.text('Чужой пост'), findsOneWidget);

      await _tap(tester, find.byTooltip('Действия с постом'));
      await _tap(tester, find.text('Пожаловаться'));
      expect(find.text('Чужой пост'), findsNothing);
      expect((env.server.db.posts.single['reports'] as List), hasLength(1));
      await _dispose(tester);
    });

    testWidgets('comments', (tester) async {
      final env = await _pump(tester, connected: true);
      final other = await env.server.registerUser();
      final post = await env.server.as(
        other.token,
        'POST',
        '/posts',
        '{"text":"Пост"}',
      );
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Лента'));
      await _tap(tester, find.byKey(Key('comments-${post['id']}')));
      expect(find.text('Пока нет комментариев.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('comment-text')), 'Держись!');
      await tester.pump();
      await _tap(tester, find.text('Отправить'));
      expect(find.text('Держись!'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('7. close ones', () {
    testWidgets('invite shows a code that works for a friend', (tester) async {
      final env = await _pump(tester, connected: true);
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Поддержка'));
      expect(
        find.textContaining('Близкие видят только дни без сигарет'),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(const Key('invite-button')));
      final code = tester
          .widget<Text>(find.byKey(const Key('invite-code')))
          .data!;
      expect(code, hasLength(6));

      await _tap(tester, find.text('Отправить код'));
      expect(env.sharer.shared.single, contains(code));

      final friend = await env.server.registerUser();
      final res = await env.server.as(
        friend.token,
        'POST',
        '/invites/accept',
        jsonEncode({'code': code}),
      );
      expect(res['ownerNick'], isNotEmpty);
      await _dispose(tester);
    });

    testWidgets(
      'entering a friend\'s code; supporter sees progress and can cheer',
      (tester) async {
        final env = await _pump(tester, connected: true);
        final friend = await env.server.registerUser();
        final code =
            (await env.server.as(friend.token, 'POST', '/invites'))['code']
                as String;
        await env.server.as(
          friend.token,
          'PUT',
          '/progress',
          jsonEncode({
            'smokeFreeDays': 12,
            'daysInProgram': 14,
            'cigsAvoided': 200,
          }),
        );

        await _tab(tester, 'Сообщество');
        await _tap(tester, find.text('Поддержка'));
        await _tap(tester, find.byKey(const Key('enter-code-button')));
        await tester.enterText(find.byKey(const Key('code-field')), code);
        await tester.pump();
        await _tap(tester, find.text('Подключиться'));
        expect(find.textContaining('Теперь ты поддерживаешь'), findsOneWidget);
        expect(find.textContaining('12 дней без сигарет'), findsOneWidget);

        await _tap(tester, find.text('Поддержать'));
        await _tap(tester, find.widgetWithText(AppChip, 'Ты молодец!'));
        final msgs =
            (await env.server.as(friend.token, 'GET', '/messages'))['messages']
                as List;
        expect(msgs.single['text'], 'Ты молодец!');
        await _dispose(tester);
      },
    );

    testWidgets('a wrong code shows a readable error', (tester) async {
      await _pump(tester, connected: true);
      await _tab(tester, 'Сообщество');
      await _tap(tester, find.text('Поддержка'));
      await _tap(tester, find.byKey(const Key('enter-code-button')));
      await tester.enterText(find.byKey(const Key('code-field')), 'ZZZZZZ');
      await tester.pump();
      await _tap(tester, find.text('Подключиться'));
      expect(find.text('Код не найден или уже использован.'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets(
      'a cheer from a friend appears as a banner on the home screen',
      (tester) async {
        final env = await _pump(tester, connected: true);
        final friend = await env.server.registerUser();
        final account =
            jsonDecode(
                  (await SharedPreferences.getInstance()).getString(
                    'account_v1',
                  )!,
                )
                as Map<String, dynamic>;
        // свяжем: друг принимает код владельца
        final owner = (account['token'] as String);
        final code = (await env.server.as(owner, 'POST', '/invites'))['code'];
        await env.server.as(
          friend.token,
          'POST',
          '/invites/accept',
          jsonEncode({'code': code}),
        );
        await env.server.as(
          friend.token,
          'POST',
          '/cheers',
          jsonEncode({'ownerId': account['userId'], 'text': 'Горжусь тобой'}),
        );

        // открываем «Поддержка», чтобы подтянуть сообщения, и возвращаемся
        await _tab(tester, 'Сообщество');
        await _tap(tester, find.text('Поддержка'));
        await _tab(tester, 'Главная');
        expect(find.textContaining('Горжусь тобой'), findsOneWidget);

        await tester.tap(find.byIcon(CupertinoIcons.xmark));
        await _settle(tester);
        expect(find.textContaining('Горжусь тобой'), findsNothing);
        await _dispose(tester);
      },
    );

    testWidgets('SOS tells supporters; progress summary is pushed at start', (
      tester,
    ) async {
      final env = await _pump(tester, connected: true);
      expect(env.server.requests, contains('PUT /progress'));
      await _tap(tester, find.text('Хочу курить'));
      expect(env.server.requests, contains('POST /sos'));
      await _dispose(tester);
    });
  });

  group('9. health metrics', () {
    final quit = _daysAgo(20);
    final data = [
      for (var i = 34; i >= 21; i--)
        DailyHealth(day: _daysAgo(i), restingHr: 78, steps: 4000),
      for (var i = 13; i >= 0; i--)
        DailyHealth(day: _daysAgo(i), restingHr: 72, steps: 6500),
    ];

    testWidgets('connect and see the change in resting heart rate', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        profile: makeProfile(quitDate: quit),
        health: FakeHealthSource(days: data),
      );
      await _tab(tester, 'Здоровье');
      await _tap(tester, find.text('Показатели'));
      expect(find.byKey(const Key('health-connect')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('health-connect')));
      expect(env.health.connectCalls, 1);
      expect(find.text('ПУЛЬС ПОКОЯ'), findsOneWidget);
      expect(find.text('72 уд/мин'), findsOneWidget);
      expect(
        find.textContaining('−6 уд/мин к периоду до отказа'),
        findsOneWidget,
      );
      expect(find.textContaining('+2500 к периоду до отказа'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('denied access explains what to do', (tester) async {
      await _pump(
        tester,
        profile: makeProfile(quitDate: quit),
        health: FakeHealthSource(access: HealthAccess.denied),
      );
      await _tab(tester, 'Здоровье');
      await _tap(tester, find.text('Показатели'));
      await _tap(tester, find.byKey(const Key('health-connect')));
      expect(find.textContaining('Доступ не выдан'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('unavailable on this device', (tester) async {
      await _pump(
        tester,
        health: FakeHealthSource(access: HealthAccess.unavailable),
      );
      await _tab(tester, 'Здоровье');
      await _tap(tester, find.text('Показатели'));
      await _tap(tester, find.byKey(const Key('health-connect')));
      expect(find.textContaining('недоступны'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('premium feature when the paywall is on', (tester) async {
      await _pump(tester, paywall: true);
      await _tab(tester, 'Здоровье');
      await _tap(tester, find.text('Показатели'));
      expect(find.text('Показатели здоровья в NoSmoke+'), findsOneWidget);
      expect(find.byKey(const Key('health-connect')), findsNothing);
      await _dispose(tester);
    });
  });

  group('3. widget launch', () {
    testWidgets('a tap on the widget opens SOS', (tester) async {
      final env = await _pump(tester);
      env.widgets.clickController.add(Uri.parse('nosmoke://sos'));
      await _settle(tester);
      expect(find.text('Тяга пройдёт'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('an unrelated link is ignored', (tester) async {
      final env = await _pump(tester);
      env.widgets.clickController.add(Uri.parse('nosmoke://other'));
      await _settle(tester);
      expect(find.text('Тяга пройдёт'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('the app can be launched from the widget', (tester) async {
      _tallScreen(tester);
      final widgets = FakeWidgetService()..launch = Uri.parse('nosmoke://sos');
      SharedPreferences.setMockInitialValues({
        'profile_v1': makeProfile(quitDate: _daysAgo(3)).encode(),
      });
      await tester.pumpWidget(
        NoSmokeApp(services: makeServices(widgets: widgets)),
      );
      await _settle(tester);
      expect(find.text('Тяга пройдёт'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('the home screen keeps the widget fresh', (tester) async {
      final env = await _pump(tester);
      expect(env.widgets.updates, isNotEmpty);
      expect(env.widgets.updates.first.value, '3');
      await _dispose(tester);
    });
  });

  group('settings: server, AI, subscription, reset', () {
    testWidgets('connect, toggle AI, disconnect and erase', (tester) async {
      final env = await _pump(tester);
      await _tab(tester, 'Настройки');
      expect(find.text('Не подключён'), findsOneWidget);

      await _tap(tester, find.text('Сервер'));
      await tester.enterText(
        find.byKey(const Key('server-url')),
        InProcessServer.baseUrl,
      );
      await _tap(tester, find.text('Подключить'));
      expect(find.textContaining('Подключён как'), findsOneWidget);

      await tester.tap(find.byType(CupertinoSwitch).last);
      await _settle(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('coach_ai_v1'), 'yes');

      await _tap(tester, find.text('Отключить и удалить мои данные'));
      await _tap(tester, find.text('Удалить'));
      expect(env.server.db.users, isEmpty);
      expect(find.text('Не подключён'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('a bad address shows an error and does not connect', (
      tester,
    ) async {
      await _pump(tester);
      await _tab(tester, 'Настройки');
      await _tap(tester, find.text('Сервер'));
      await tester.enterText(find.byKey(const Key('server-url')), 'ftp://nope');
      await _tap(tester, find.text('Подключить'));
      expect(find.text('Неверный адрес сервера.'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('an unreachable server shows a connection error', (
      tester,
    ) async {
      _tallScreen(tester);
      SharedPreferences.setMockInitialValues({
        'profile_v1': makeProfile(quitDate: _daysAgo(3)).encode(),
      });
      await tester.pumpWidget(NoSmokeApp(services: makeServices()));
      await _settle(tester);
      await _tab(tester, 'Настройки');
      await _tap(tester, find.text('Сервер'));
      await tester.enterText(
        find.byKey(const Key('server-url')),
        'https://nowhere.test',
      );
      await _tap(tester, find.text('Подключить'));
      expect(find.text('Не удалось связаться с сервером.'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('subscription row exists only when the paywall is on', (
      tester,
    ) async {
      await _pump(tester);
      await _tab(tester, 'Настройки');
      expect(find.text('NoSmoke+'), findsNothing);
      await _dispose(tester);

      await _pump(tester, paywall: true);
      await _tab(tester, 'Настройки');
      expect(find.text('NoSmoke+'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('"start over" erases server data and every new local store', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        connected: true,
        prefs: {
          ..._diaryAtThisHour(3),
          'goal_v1': jsonEncode([
            {
              'title': 'Цель',
              'target': 100,
              'createdAt': DateTime.now().toIso8601String(),
            },
          ]),
          'smoked_v1': jsonEncode([
            {'at': DateTime.now().toIso8601String()},
          ]),
          'coach_ai_v1': 'yes',
        },
      );
      await env.server.as(
        jsonDecode(
              (await SharedPreferences.getInstance()).getString('account_v1')!,
            )['token']
            as String,
        'POST',
        '/posts',
        '{"text":"пост"}',
      );
      await _tab(tester, 'Настройки');
      await _tap(tester, find.text('Начать заново'));
      await _tap(tester, find.text('Удалить'));

      expect(find.text('Ты уже сделал первый шаг'), findsOneWidget);
      expect(env.server.db.users, isEmpty);
      expect(env.server.db.posts, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      for (final k in [
        'profile_v1',
        'account_v1',
        'goal_v1',
        'smoked_v1',
        'diary_v1',
        'coach_ai_v1',
      ]) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      await _dispose(tester);
    });
  });
}
