import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/core/network/api_client.dart';
import 'package:nosmoke/features/account/data/account_store.dart';
import 'package:nosmoke/features/account/presentation/account_controller.dart';
import 'package:nosmoke/features/coach/data/coach_service.dart';
import 'package:nosmoke/features/coach/domain/coach_models.dart';
import 'package:nosmoke/features/coach/domain/local_coach.dart';
import 'package:nosmoke/features/coach/presentation/coach_controller.dart';
import 'package:nosmoke/features/diary/domain/diary_insights.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/in_process_server.dart';

CoachContext ctx({
  int days = 3,
  String? motivation = 'дочь',
  Trigger? trigger,
  String? helper,
}) => CoachContext(
  smokeFreeDays: days,
  daysInProgram: days,
  relapseCount: 0,
  cigsPerDay: 20,
  yearsSmoking: 8,
  gradual: false,
  motivation: motivation,
  topTrigger: trigger,
  topHelper: helper,
);

CoachMessage user(String t) => CoachMessage(role: CoachRole.user, text: t);

void main() {
  group('intent detection', () {
    test('table', () {
      final cases = {
        'Тянет курить прямо сейчас': CoachIntent.craving,
        'очень хочу курить': CoachIntent.craving,
        'Я сорвался(ась)': CoachIntent.relapse,
        'закурил после работы': CoachIntent.relapse,
        'Сильный стресс': CoachIntent.stress,
        'Не могу уснуть': CoachIntent.sleep,
        'выпил пива с друзьями': CoachIntent.alcohol,
        'Боюсь поправиться': CoachIntent.weight,
        'Можно ли использовать пластырь?': CoachIntent.medical,
        'спасибо!': CoachIntent.thanks,
        'как дела': CoachIntent.other,
        '': CoachIntent.other,
      };
      cases.forEach(
        (text, intent) => expect(detectIntent(text), intent, reason: text),
      );
    });

    test('every quick prompt is understood (no dead buttons)', () {
      for (final p in coachQuickPrompts) {
        expect(detectIntent(p), isNot(CoachIntent.other), reason: p);
      }
    });

    test('crisis wording is detected before everything else', () {
      for (final t in [
        'не хочу жить',
        'хочу покончить с собой',
        'думаю про суицид',
        'я сорвался и хочу убить себя',
      ]) {
        expect(isCrisisMessage(t), isTrue, reason: t);
        expect(detectIntent(t), CoachIntent.crisis, reason: t);
      }
      expect(isCrisisMessage('тяга убивает, хочу курить'), isFalse);
    });
  });

  group('LocalCoach', () {
    const coach = LocalCoach();

    test('craving plan is personal: motivation, streak, helper', () {
      final r = coach.reply('тянет', ctx(helper: 'Прогулка'));
      expect(r, contains('3–5 минут'));
      expect(r, contains('дочь'));
      expect(r, contains('3 дня без сигарет'));
      expect(r, contains('помогало: прогулка'));
    });

    test('craving without data still gives a plan', () {
      final r = coach.reply('тянет', ctx(days: 0, motivation: null));
      expect(r, contains('вдох'));
      expect(r, isNot(contains('null')));
    });

    test('relapse reply is kind, does not shame, keeps progress', () {
      final r = coach.reply(
        'я сорвался',
        ctx(days: 10, trigger: Trigger.stress),
      );
      expect(r, contains('не провал'));
      expect(r, contains('10 дней в программе'));
      expect(r, contains('стресс'));
      expect(r.toLowerCase(), isNot(contains('слабак')));
    });

    test('medical question defers to a doctor', () {
      final r = coach.reply('какие таблетки принимать', ctx());
      expect(r, contains('врач'));
      expect(r, contains('не врач'));
    });

    test('crisis reply points to real help and not to quitting tips', () {
      final r = coach.reply('не хочу жить', ctx());
      expect(r, crisisReply);
      expect(r, contains('экстренную службу'));
      // никаких советов «переждать тягу» в кризисе
      expect(r.toLowerCase(), isNot(contains('вдох')));
      expect(r.toLowerCase(), isNot(contains('воды')));
    });

    test('unknown message asks what is going on', () {
      expect(coach.reply('привет', ctx()), contains('Расскажи'));
    });
  });

  group('CoachContext', () {
    test('prompt has facts but no identity', () {
      final p = makeProfile(motivationText: 'играть с дочерью');
      final s = computeProgress(p, [], DateTime(2026, 1, 11));
      final c = CoachContext.from(
        p,
        s,
        const DiaryInsights(total: 0, peakHour: 15, topHelper: 'Вода'),
        DateTime(2026, 1, 11),
      );
      final text = c.toPrompt();
      expect(text, contains('Дней без сигарет: 10'));
      expect(text, contains('играть с дочерью'));
      expect(text, contains('Пик тяги около 15:00'));
      expect(text, contains('помогало: вода'));
      expect(text, isNot(contains('+7')));
      expect(text, isNot(contains('@')));
    });

    test('gradual mode shows the limit', () {
      final p = makeProfile(mode: QuitMode.gradual);
      final s = computeProgress(p, [], DateTime(2026, 1, 3));
      final c = CoachContext.from(
        p,
        s,
        const DiaryInsights(total: 0),
        DateTime(2026, 1, 3),
      );
      expect(c.toPrompt(), contains('лимит сегодня: 16'));
    });
  });

  group('FallbackCoach (with the real server code)', () {
    late InProcessServer server;
    late AccountController account;
    var consent = true;

    FallbackCoach make() => FallbackCoach(
      remote: () {
        final api = account.api;
        return api == null ? null : RemoteCoach(api);
      },
      aiAllowed: () => consent,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      consent = true;
      server = InProcessServer();
      account = AccountController(
        AccountStore(),
        clientFactory: server.clientFactory,
      );
      await account.connect(InProcessServer.baseUrl);
    });

    test('uses the AI when allowed and the server is reachable', () async {
      final r = await make().reply([user('Тянет курить')], ctx());
      expect(r.source, CoachSource.remote);
      expect(r.text, 'Ответ ИИ: дыши глубже.');
      expect(server.coach!.calls.single.single['content'], 'Тянет курить');
      expect(server.coach!.lastContext, contains('Дней без сигарет: 3'));
    });

    test('without consent nothing leaves the device', () async {
      consent = false;
      final r = await make().reply([user('Тянет курить')], ctx());
      expect(r.source, CoachSource.local);
      expect(server.requests.where((r) => r == 'POST /coach'), isEmpty);
    });

    test('a crisis message never goes to the model', () async {
      final r = await make().reply([user('не хочу жить')], ctx());
      expect(r.text, crisisReply);
      expect(r.source, CoachSource.local);
      expect(server.requests.where((r) => r == 'POST /coach'), isEmpty);
    });

    test(
      'falls back to the offline coach when the model backend fails',
      () async {
        server.coach!.fail = true;
        final r = await make().reply([user('Тянет курить')], ctx());
        expect(r.source, CoachSource.local);
        expect(r.text, contains('3–5 минут'));
      },
    );

    test(
      'falls back when the server is unreachable or not connected',
      () async {
        final none = FallbackCoach(remote: () => null, aiAllowed: () => true);
        expect(
          (await none.reply([user('тянет')], ctx())).source,
          CoachSource.local,
        );

        final offline = FallbackCoach(
          remote: () => RemoteCoach(
            ApiClient(
              baseUrl: 'https://x.test',
              token: 't',
              client: offlineClient(),
            ),
          ),
          aiAllowed: () => true,
        );
        expect(
          (await offline.reply([user('тянет')], ctx())).source,
          CoachSource.local,
        );
      },
    );

    test('server without an API key (503) also falls back', () async {
      final bare = InProcessServer(withCoach: false);
      final acc = AccountController(
        AccountStore(),
        clientFactory: bare.clientFactory,
      );
      await acc.connect(InProcessServer.baseUrl);
      final coach = FallbackCoach(
        remote: () => RemoteCoach(acc.api!),
        aiAllowed: () => true,
      );
      final r = await coach.reply([user('тянет')], ctx());
      expect(r.source, CoachSource.local);
    });
  });

  group('CoachController', () {
    test(
      'keeps the conversation and ignores empty or parallel sends',
      () async {
        final chat = CoachController(
          FallbackCoach(remote: () => null, aiAllowed: () => false),
          () => ctx(),
        );
        await chat.send('   ');
        expect(chat.messages, isEmpty);

        final first = chat.send('Тянет курить');
        expect(chat.sending, isTrue);
        await chat.send('второе пока идёт первое'); // игнорируется
        await first;
        expect(chat.messages.map((m) => m.role), [
          CoachRole.user,
          CoachRole.assistant,
        ]);
        expect(chat.messages.last.text, contains('3–5 минут'));
        expect(chat.sending, isFalse);

        chat.clear();
        expect(chat.messages, isEmpty);
      },
    );

    test('an unexpected failure becomes a friendly message', () async {
      final chat = CoachController(_Throwing(), () => ctx());
      await chat.send('привет');
      expect(chat.messages.last.text, contains('Не получилось ответить'));
      expect(chat.sending, isFalse);
    });
  });
}

class _Throwing implements CoachService {
  @override
  Future<CoachReply> reply(
    List<CoachMessage> history,
    CoachContext context,
  ) async => throw StateError('boom');
}
