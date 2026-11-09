import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/features/account/data/account_store.dart';
import 'package:nosmoke/features/account/presentation/account_controller.dart';
import 'package:nosmoke/features/profile/domain/profile.dart';
import 'package:nosmoke/features/progress/domain/progress.dart';
import 'package:nosmoke/features/supporters/data/supporters_repository.dart';
import 'package:nosmoke/features/supporters/domain/supporters_models.dart';
import 'package:nosmoke/features/supporters/presentation/supporters_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/in_process_server.dart';

void main() {
  late InProcessServer server;
  late AccountController account;
  late SupportersController owner;
  late DateTime clock;

  SupportersController controllerFor(AccountController a) =>
      SupportersController(() {
        final api = a.api;
        return api == null ? null : RemoteSupportersRepository(api);
      }, clock: () => clock);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 11, 9, 12);
    server = InProcessServer();
    account = AccountController(
      AccountStore(),
      clientFactory: server.clientFactory,
    );
    await account.connect(InProcessServer.baseUrl);
    owner = controllerFor(account);
  });

  ProgressSnapshot snap({
    int days = 5,
    int avoided = 100,
    bool streak = true,
  }) => ProgressSnapshot(
    started: true,
    daysInProgram: days + 2,
    cigsAvoided: avoided,
    moneySaved: 99999, // не должно уйти на сервер
    lifeRegained: Duration.zero,
    smokeFree: Duration(days: days),
    bestStreak: Duration(days: days),
    streakActive: streak,
    relapseCount: 7, // не должно уйти на сервер
  );

  test('invite → friend accepts → both sides see each other', () async {
    final (code, err) = await owner.createInvite();
    expect(err, isNull);
    expect(code, hasLength(6));

    final friend = await server.registerUser();
    final res = await server.as(
      friend.token,
      'POST',
      '/invites/accept',
      jsonEncode({'code': code}),
    );
    expect(res['ownerNick'], account.account!.nick);

    await owner.refresh();
    expect(owner.supporters.single.nick, friend.nick);
    expect(owner.hasSupporters, isTrue);
  });

  test('accepting a code as the supporter', () async {
    final other = await server.registerUser();
    final code =
        (await server.as(other.token, 'POST', '/invites'))['code'] as String;

    final (nick, err) = await owner.accept(code.toLowerCase());
    expect(err, isNull);
    expect(nick, other.nick);
    expect(owner.supporting.single.nick, other.nick);
    expect(owner.supporting.single.smokeFreeDays, 0);
  });

  test('accept errors are mapped to readable text', () async {
    final (nick, err) = await owner.accept('ZZZZZZ');
    expect(nick, isNull);
    expect(err, 'invalid_code');
    expect(supportErrorText('invalid_code'), contains('не найден'));
    expect(supportErrorText('expired'), contains('истёк'));
    expect(supportErrorText('own_code'), contains('собственный'));
    expect(supportErrorText('too_many_supporters'), contains('максимум'));
    expect(supportErrorText('network'), contains('Нет связи'));

    final (code, _) = await owner.createInvite();
    final (_, ownErr) = await owner.accept(code!);
    expect(ownErr, 'own_code');
  });

  test('only three numbers leave the device', () async {
    await owner.syncProgress(snap(days: 12, avoided: 240));
    final progress = server.db.progress[account.account!.userId]!;
    expect(progress['smokeFreeDays'], 12);
    expect(progress['daysInProgram'], 14);
    expect(progress['cigsAvoided'], 240);
    expect(progress.keys, isNot(contains('moneySaved')));
    expect(progress.keys, isNot(contains('relapseCount')));
    final body = server.bodies.lastWhere((b) => b.contains('smokeFreeDays'));
    expect(body, isNot(contains('99999')));
  });

  test(
    'progress is not re-sent when nothing changed (within 10 minutes)',
    () async {
      await owner.syncProgress(snap());
      await owner.syncProgress(snap());
      expect(server.requests.where((r) => r == 'PUT /progress'), hasLength(1));

      clock = clock.add(const Duration(minutes: 11));
      await owner.syncProgress(snap());
      expect(server.requests.where((r) => r == 'PUT /progress'), hasLength(2));
    },
  );

  test('changed progress is sent immediately', () async {
    await owner.syncProgress(snap(days: 5));
    await owner.syncProgress(snap(days: 6));
    expect(server.requests.where((r) => r == 'PUT /progress'), hasLength(2));
  });

  test(
    'a gradual-ramp user reports 0 smoke-free days, not the ramp length',
    () async {
      await owner.syncProgress(snap(days: 9, streak: false));
      expect(server.db.progress[account.account!.userId]!['smokeFreeDays'], 0);
    },
  );

  test('not started / not connected: nothing is sent', () async {
    await owner.syncProgress(
      const ProgressSnapshot(
        started: false,
        daysInProgram: 0,
        cigsAvoided: 0,
        moneySaved: 0,
        lifeRegained: Duration.zero,
        smokeFree: Duration.zero,
        bestStreak: Duration.zero,
        streakActive: false,
        relapseCount: 0,
      ),
    );
    await SupportersController(() => null).syncProgress(snap());
    expect(server.requests.where((r) => r == 'PUT /progress'), isEmpty);
  });

  test('SOS ping is visible to the supporter within two hours', () async {
    final friend = await server.registerUser();
    final (code, _) = await owner.createInvite();
    await server.as(
      friend.token,
      'POST',
      '/invites/accept',
      jsonEncode({'code': code}),
    );

    await owner.pingSos();
    final res = await server.as(friend.token, 'GET', '/supporting');
    final o = SupportedOwner.fromJson(
      (res['owners'] as List).single as Map<String, dynamic>,
    );
    expect(o.lastSosAt, isNotNull);

    final justNow = o.lastSosAt!.add(const Duration(minutes: 5));
    expect(o.sosRecently(justNow), isTrue);
    expect(o.sosRecently(o.lastSosAt!.add(const Duration(hours: 3))), isFalse);
    expect(
      o.sosRecently(o.lastSosAt!.subtract(const Duration(minutes: 1))),
      isFalse,
    );
  });

  test('cheers arrive as unread messages and are marked read', () async {
    final friend = await server.registerUser();
    final (code, _) = await owner.createInvite();
    await server.as(
      friend.token,
      'POST',
      '/invites/accept',
      jsonEncode({'code': code}),
    );
    await server.as(
      friend.token,
      'POST',
      '/cheers',
      jsonEncode({'ownerId': account.account!.userId, 'text': 'Ты молодец!'}),
    );

    await owner.refresh();
    expect(owner.unread.single.text, 'Ты молодец!');
    expect(owner.unread.single.nick, friend.nick);

    await owner.markRead();
    expect(owner.unread, isEmpty);

    // после перезапуска прочитанное не возвращается, новое приходит
    final again = controllerFor(account);
    await again.refresh();
    expect(again.unread, isEmpty);
    await server.as(
      friend.token,
      'POST',
      '/cheers',
      jsonEncode({'ownerId': account.account!.userId, 'text': 'Ещё раз'}),
    );
    await again.refresh();
    expect(again.unread.single.text, 'Ещё раз');
  });

  test('cheering requires a link', () async {
    final stranger = await server.registerUser();
    expect(await owner.cheer(stranger.userId, 'привет'), 'not_linked');
  });

  test('unlink removes the person from both lists', () async {
    final friend = await server.registerUser();
    final (code, _) = await owner.createInvite();
    await server.as(
      friend.token,
      'POST',
      '/invites/accept',
      jsonEncode({'code': code}),
    );
    await owner.refresh();
    await owner.unlink(friend.userId);
    expect(owner.supporters, isEmpty);
    expect(server.db.links, isEmpty);
  });

  test('without a server it is all a safe no-op', () async {
    final none = SupportersController(() => null);
    expect(none.available, isFalse);
    await none.refresh();
    expect((await none.createInvite()).$2, 'network');
    expect((await none.accept('ABC123')).$2, 'network');
    expect(await none.cheer('x', 'y'), 'network');
    await none.pingSos();
    await none.unlink('x');
  });

  test('models: presets are short, errors have text', () {
    expect(cheerPresets, isNotEmpty);
    for (final p in cheerPresets) {
      expect(p.length, lessThanOrEqualTo(140));
    }
    expect(
      const ProgressSummary(
        smokeFreeDays: 1,
        daysInProgram: 2,
        cigsAvoided: 3,
      ).toJson(),
      {'smokeFreeDays': 1, 'daysInProgram': 2, 'cigsAvoided': 3},
    );
  });

  test('computeProgress feeds the summary consistently', () async {
    final p = makeProfile(quitDate: DateTime(2026, 11, 1));
    final s = computeProgress(p, [], DateTime(2026, 11, 9, 12));
    await owner.syncProgress(s);
    final stored = server.db.progress[account.account!.userId]!;
    expect(stored['smokeFreeDays'], 8);
    expect(stored['daysInProgram'], 8);
    expect(p.quitMode, QuitMode.cold);
  });
}
