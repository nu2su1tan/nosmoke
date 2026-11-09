import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nosmoke_server/app.dart';
import 'package:nosmoke_server/coach_backend.dart';
import 'package:nosmoke_server/db.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class FakeCoach implements CoachBackend {
  List<Map<String, String>>? lastMessages;
  String? lastContext;
  bool fail = false;

  @override
  Future<String> reply(
    List<Map<String, String>> messages,
    String context,
  ) async {
    if (fail) throw CoachUnavailable('boom');
    lastMessages = messages;
    lastContext = context;
    return 'Держись, тяга пройдёт.';
  }
}

class Client {
  Client(this.handler, [this.token]);

  final Handler handler;
  String? token;
  String? userId;
  String? nick;

  Future<(int, Map<String, dynamic>)> call(
    String method,
    String path, [
    Object? body,
  ]) async {
    final res = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'x-user-token': ?token},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final text = await res.readAsString();
    return (
      res.statusCode,
      text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>,
    );
  }

  Future<Client> register() async {
    final (s, b) = await call('POST', '/register');
    expect(s, 200);
    token = b['token'] as String;
    userId = b['userId'] as String;
    nick = b['nick'] as String;
    return this;
  }
}

void main() {
  late Db db;
  late DateTime now;
  late FakeCoach coach;
  late Handler handler;

  setUp(() {
    db = Db();
    now = DateTime.utc(2026, 11, 9, 12);
    coach = FakeCoach();
    handler = buildHandler(db, coach: coach, now: () => now, random: Random(1));
  });

  Future<Client> user() => Client(handler).register();

  group('auth', () {
    test('health is open, everything else needs a token', () async {
      final c = Client(handler);
      expect((await c.call('GET', '/health')).$1, 200);
      expect((await c.call('GET', '/posts')).$1, 401);
      c.token = 'wrong';
      expect((await c.call('GET', '/posts')).$1, 401);
    });

    test('register gives a distinct anonymous identity', () async {
      final a = await user();
      final b = await user();
      expect(a.userId, isNot(b.userId));
      expect(a.token, isNot(b.token));
      expect(a.nick, isNotEmpty);
      expect(a.nick, isNot(contains('@')));
    });

    test('malformed json is a 400, not a crash', () async {
      final a = await user();
      final res = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/posts'),
          headers: {'x-user-token': a.token!},
          body: '{not json',
        ),
      );
      expect(res.statusCode, 400);
    });
  });

  group('community feed', () {
    test('create, list newest first, mine flag', () async {
      final a = await user();
      final b = await user();
      expect((await a.call('POST', '/posts', {'text': 'Первый день'})).$1, 201);
      now = now.add(const Duration(minutes: 1));
      await b.call('POST', '/posts', {'text': 'Неделя без сигарет'});

      final (s, body) = await a.call('GET', '/posts');
      expect(s, 200);
      final posts = body['posts'] as List;
      expect(posts.map((p) => p['text']), [
        'Неделя без сигарет',
        'Первый день',
      ]);
      expect(posts[0]['mine'], isFalse);
      expect(posts[1]['mine'], isTrue);
      expect(posts[1]['nick'], a.nick);
    });

    test('moderation rejects empty, long, links and profanity', () async {
      final a = await user();
      Future<String> err(String? text) async {
        final (s, b) = await a.call('POST', '/posts', {'text': text});
        expect(s, 422);
        return b['error'] as String;
      }

      expect(await err(''), 'empty');
      expect(await err('   '), 'empty');
      expect(await err(null), 'empty');
      expect(await err('а' * 501), 'too_long');
      expect(await err('смотри https://spam.example'), 'links_not_allowed');
      expect(await err('заходи на site.ru'), 'links_not_allowed');
      expect(await err('ты сука'), 'inappropriate');
    });

    test('rate limit: 10 posts per hour, then free again', () async {
      final a = await user();
      for (var i = 0; i < 10; i++) {
        expect((await a.call('POST', '/posts', {'text': 'пост $i'})).$1, 201);
      }
      expect((await a.call('POST', '/posts', {'text': 'ещё'})).$1, 429);
      now = now.add(const Duration(hours: 1, minutes: 1));
      expect((await a.call('POST', '/posts', {'text': 'снова'})).$1, 201);
    });

    test('like toggles per user', () async {
      final a = await user();
      final b = await user();
      final id = (await a.call('POST', '/posts', {'text': 'hi'})).$2['id'];

      var (_, r) = await b.call('POST', '/posts/$id/like');
      expect(r, {'likes': 1, 'liked': true});
      (_, r) = await a.call('POST', '/posts/$id/like');
      expect(r['likes'], 2);
      (_, r) = await b.call('POST', '/posts/$id/like');
      expect(r, {'likes': 1, 'liked': false});
    });

    test('three reports hide a post; one user counts once', () async {
      final a = await user();
      final id = (await a.call('POST', '/posts', {'text': 'спорный'})).$2['id'];
      final r1 = await user();
      final r2 = await user();
      final r3 = await user();

      await r1.call('POST', '/posts/$id/report');
      await r1.call('POST', '/posts/$id/report'); // повтор не считается
      await r2.call('POST', '/posts/$id/report');
      expect(
        ((await a.call('GET', '/posts')).$2['posts'] as List),
        hasLength(1),
      );

      await r3.call('POST', '/posts/$id/report');
      expect(((await a.call('GET', '/posts')).$2['posts'] as List), isEmpty);
      expect((await a.call('POST', '/posts/$id/like')).$1, 404);
    });

    test('only the author can delete', () async {
      final a = await user();
      final b = await user();
      final id = (await a.call('POST', '/posts', {'text': 'моё'})).$2['id'];
      expect((await b.call('DELETE', '/posts/$id')).$1, 403);
      expect((await a.call('DELETE', '/posts/$id')).$1, 200);
      expect((await a.call('GET', '/posts')).$2['posts'], isEmpty);
    });

    test('comments: add, list, counted on the post, moderated', () async {
      final a = await user();
      final b = await user();
      final id = (await a.call('POST', '/posts', {'text': 'пост'})).$2['id'];

      expect(
        (await b.call('POST', '/posts/$id/comments', {'text': 'Держись!'})).$1,
        201,
      );
      expect(
        (await b.call('POST', '/posts/$id/comments', {
          'text': 'http://x.com',
        })).$1,
        422,
      );

      final (_, list) = await a.call('GET', '/posts/$id/comments');
      final comments = list['comments'] as List;
      expect(comments, hasLength(1));
      expect(comments.single['text'], 'Держись!');
      expect(comments.single['mine'], isFalse);

      final posts = (await a.call('GET', '/posts')).$2['posts'] as List;
      expect(posts.single['comments'], 1);
      expect(
        (await a.call('POST', '/posts/nope/comments', {'text': 'x'})).$1,
        404,
      );
    });
  });

  group('supporters', () {
    Future<(Client owner, Client friend)> linkedPair() async {
      final owner = await user();
      final friend = await user();
      final code = (await owner.call('POST', '/invites')).$2['code'] as String;
      final (s, b) = await friend.call('POST', '/invites/accept', {
        'code': code,
      });
      expect(s, 200);
      expect(b['ownerNick'], owner.nick);
      return (owner, friend);
    }

    test('invite codes are 6 chars without ambiguous symbols', () async {
      for (var i = 0; i < 20; i++) {
        final a = await user();
        final code = (await a.call('POST', '/invites')).$2['code'] as String;
        expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
      }
    });

    test('invite creation is rate limited (10 per hour)', () async {
      final a = await user();
      for (var i = 0; i < 10; i++) {
        expect((await a.call('POST', '/invites')).$1, 201);
      }
      expect((await a.call('POST', '/invites')).$1, 429);
    });

    test('accept links both ways and a code works only once', () async {
      final owner = await user();
      final f1 = await user();
      final f2 = await user();
      final code = (await owner.call('POST', '/invites')).$2['code'] as String;

      expect(
        (await f1.call('POST', '/invites/accept', {
          'code': code.toLowerCase(),
        })).$1,
        200,
      );
      final (s, b) = await f2.call('POST', '/invites/accept', {'code': code});
      expect((s, b['error']), (404, 'invalid_code'));

      final supporters =
          (await owner.call('GET', '/supporters')).$2['supporters'] as List;
      expect(supporters.single['nick'], f1.nick);
      final owners = (await f1.call('GET', '/supporting')).$2['owners'] as List;
      expect(owners.single['nick'], owner.nick);
    });

    test('own code, wrong code, expired code', () async {
      final owner = await user();
      final code = (await owner.call('POST', '/invites')).$2['code'] as String;
      expect(
        (await owner.call('POST', '/invites/accept', {
          'code': code,
        })).$2['error'],
        'own_code',
      );
      expect(
        (await owner.call('POST', '/invites/accept', {'code': 'ZZZZZZ'})).$1,
        404,
      );

      now = now.add(const Duration(days: 8));
      final late = await user();
      final (s, b) = await late.call('POST', '/invites/accept', {'code': code});
      expect((s, b['error']), (410, 'expired'));
    });

    test('at most 5 supporters per owner', () async {
      final owner = await user();
      for (var i = 0; i < 5; i++) {
        final f = await user();
        final code =
            (await owner.call('POST', '/invites')).$2['code'] as String;
        expect(
          (await f.call('POST', '/invites/accept', {'code': code})).$1,
          200,
        );
      }
      final f6 = await user();
      final code = (await owner.call('POST', '/invites')).$2['code'] as String;
      expect(
        (await f6.call('POST', '/invites/accept', {'code': code})).$2['error'],
        'too_many_supporters',
      );
    });

    test('supporter sees only the shared summary', () async {
      final (owner, friend) = await linkedPair();
      expect(
        (await owner.call('PUT', '/progress', {
          'smokeFreeDays': 12,
          'daysInProgram': 15,
          'cigsAvoided': 240,
        })).$1,
        200,
      );
      final o = ((await friend.call('GET', '/supporting')).$2['owners'] as List)
          .single;
      expect(o['smokeFreeDays'], 12);
      expect(o['daysInProgram'], 15);
      // приватные подробности (деньги, срывы, дневник) на сервер не уходят
      expect(o.keys, isNot(contains('moneySaved')));
      expect(o.keys, isNot(contains('relapses')));
    });

    test('progress validation', () async {
      final a = await user();
      for (final bad in [
        {'smokeFreeDays': -1, 'daysInProgram': 1, 'cigsAvoided': 1},
        {'smokeFreeDays': 'x', 'daysInProgram': 1, 'cigsAvoided': 1},
        {'daysInProgram': 1, 'cigsAvoided': 1},
      ]) {
        expect((await a.call('PUT', '/progress', bad)).$1, 400, reason: '$bad');
      }
    });

    test(
      'SOS ping is visible to supporters and survives progress updates',
      () async {
        final (owner, friend) = await linkedPair();
        await owner.call('PUT', '/progress', {
          'smokeFreeDays': 1,
          'daysInProgram': 1,
          'cigsAvoided': 5,
        });
        now = now.add(const Duration(minutes: 5));
        expect((await owner.call('POST', '/sos')).$1, 200);
        await owner.call('PUT', '/progress', {
          'smokeFreeDays': 2,
          'daysInProgram': 2,
          'cigsAvoided': 9,
        });

        final o =
            ((await friend.call('GET', '/supporting')).$2['owners'] as List)
                .single;
        expect(o['lastSosAt'], now.toIso8601String());
        expect(o['smokeFreeDays'], 2);
      },
    );

    test('cheers reach the owner; strangers cannot send', () async {
      final (owner, friend) = await linkedPair();
      final stranger = await user();

      expect(
        (await friend.call('POST', '/cheers', {
          'ownerId': owner.userId,
          'text': 'Ты молодец!',
        })).$1,
        201,
      );
      expect(
        (await stranger.call('POST', '/cheers', {
          'ownerId': owner.userId,
          'text': 'Привет',
        })).$2['error'],
        'not_linked',
      );
      expect(
        (await friend.call('POST', '/cheers', {
          'ownerId': owner.userId,
          'text': 'x' * 141,
        })).$2['error'],
        'too_long',
      );

      final msgs =
          (await owner.call('GET', '/messages')).$2['messages'] as List;
      expect(msgs.single['text'], 'Ты молодец!');
      expect(msgs.single['nick'], friend.nick);
      // since: уже прочитанное не возвращается
      final since = msgs.single['at'];
      expect(
        ((await owner.call('GET', '/messages?since=$since')).$2['messages']
            as List),
        isEmpty,
      );
      // чужие сообщения не видны
      expect(
        ((await friend.call('GET', '/messages')).$2['messages'] as List),
        isEmpty,
      );
    });

    test('either side can unlink; cheers stop working', () async {
      final (owner, friend) = await linkedPair();
      expect((await owner.call('DELETE', '/links/${friend.userId}')).$1, 200);
      expect(
        ((await friend.call('GET', '/supporting')).$2['owners'] as List),
        isEmpty,
      );
      expect(
        (await friend.call('POST', '/cheers', {
          'ownerId': owner.userId,
          'text': 'hi',
        })).$2['error'],
        'not_linked',
      );
      expect((await owner.call('DELETE', '/links/${friend.userId}')).$1, 404);
    });
  });

  group('account deletion', () {
    test(
      'removes everything the user owns and the token stops working',
      () async {
        final a = await user();
        final b = await user();
        final postId = (await a.call('POST', '/posts', {
          'text': 'удалится',
        })).$2['id'];
        await b.call('POST', '/posts/$postId/comments', {'text': 'коммент'});
        final bPost = (await b.call('POST', '/posts', {
          'text': 'останется',
        })).$2['id'];
        await a.call('POST', '/posts/$bPost/like');
        await a.call('POST', '/posts/$bPost/comments', {'text': 'мой коммент'});
        final code = (await a.call('POST', '/invites')).$2['code'];
        await b.call('POST', '/invites/accept', {'code': code});
        await a.call('PUT', '/progress', {
          'smokeFreeDays': 1,
          'daysInProgram': 1,
          'cigsAvoided': 1,
        });
        await b.call('POST', '/cheers', {'ownerId': a.userId, 'text': 'hi'});

        expect((await a.call('DELETE', '/account')).$1, 200);

        expect((await a.call('GET', '/posts')).$1, 401);
        final posts = (await b.call('GET', '/posts')).$2['posts'] as List;
        expect(posts.map((p) => p['text']), ['останется']);
        expect(posts.single['likes'], 0); // лайк удалённого пользователя снят
        final comments =
            (await b.call('GET', '/posts/$bPost/comments')).$2['comments']
                as List;
        expect(comments, isEmpty); // комментарии удалённого пользователя тоже
        expect(
          ((await b.call('GET', '/supporting')).$2['owners'] as List),
          isEmpty,
        );
        expect(db.users.containsKey(a.userId), isFalse);
        expect(db.progress, isEmpty);
        expect(db.messages, isEmpty);
        expect(db.invites, isEmpty);
      },
    );
  });

  group('coach proxy', () {
    test('returns the reply and passes cleaned history and context', () async {
      final a = await user();
      final (s, b) = await a.call('POST', '/coach', {
        'messages': [
          {
            'role': 'assistant',
            'text': 'Привет',
          }, // ведущий assistant отбрасывается
          {'role': 'user', 'text': 'Тянет курить'},
          {'role': 'user', 'text': 'очень'}, // подряд идущие склеиваются
        ],
        'context': 'Без сигарет: 3 дня',
      });
      expect(s, 200);
      expect(b['reply'], 'Держись, тяга пройдёт.');
      expect(coach.lastMessages, [
        {'role': 'user', 'content': 'Тянет курить\nочень'},
      ]);
      expect(coach.lastContext, 'Без сигарет: 3 дня');
    });

    test(
      '503 when no key configured or upstream fails; 400 for empty',
      () async {
        final a = await user();
        final noCoach = buildHandler(db, now: () => now, random: Random(2));
        final c = Client(noCoach, a.token);
        expect(
          (await c.call('POST', '/coach', {
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          })).$1,
          503,
        );

        coach.fail = true;
        expect(
          (await a.call('POST', '/coach', {
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          })).$1,
          503,
        );
        coach.fail = false;
        expect((await a.call('POST', '/coach', {'messages': []})).$1, 400);
      },
    );

    test('rate limited to 40 per hour', () async {
      final a = await user();
      for (var i = 0; i < 40; i++) {
        expect(
          (await a.call('POST', '/coach', {
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          })).$1,
          200,
        );
      }
      expect(
        (await a.call('POST', '/coach', {
          'messages': [
            {'role': 'user', 'text': 'hi'},
          ],
        })).$1,
        429,
      );
    });

    test('sanitizeMessages limits length and count', () {
      final many = [
        for (var i = 0; i < 30; i++)
          {'role': i.isEven ? 'user' : 'assistant', 'text': 'm$i'},
      ];
      expect(sanitizeMessages(many).length, lessThanOrEqualTo(20));
      final long = sanitizeMessages([
        {'role': 'user', 'text': 'я' * 5000},
      ]);
      expect(long.single['content']!.length, 1000);
      expect(
        sanitizeMessages([
          {'role': 'user', 'text': '  '},
          'garbage',
        ]),
        isEmpty,
      );
    });
  });

  group('persistence', () {
    test('state survives a restart; a corrupted file does not crash', () async {
      final dir = Directory.systemTemp.createTempSync('nosmoke_db');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/data.json';

      final h1 = buildHandler(Db.load(path), now: () => now, random: Random(7));
      final a = await Client(h1).register();
      await a.call('POST', '/posts', {'text': 'Сохранится'});

      final h2 = buildHandler(Db.load(path), now: () => now, random: Random(8));
      final again = Client(h2, a.token);
      final posts = (await again.call('GET', '/posts')).$2['posts'] as List;
      expect(posts.single['text'], 'Сохранится');

      File(path).writeAsStringSync('{broken');
      expect(() => Db.load(path), returnsNormally);
    });
  });
}
