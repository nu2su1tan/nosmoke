import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'coach_backend.dart';
import 'db.dart';
import 'moderation.dart';

class _HttpError implements Exception {
  _HttpError(this.status, this.code);

  final int status;
  final String code;
}

Response _json(Object body, [int status = 200]) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Собирает все маршруты. [now] и [random] подменяются в тестах.
Handler buildHandler(
  Db db, {
  CoachBackend? coach,
  DateTime Function()? now,
  Random? random,
}) {
  final clock = now ?? DateTime.now;
  final rnd = random ?? Random.secure();

  Map<String, dynamic> auth(Request req) {
    final token = req.headers['x-user-token'];
    if (token == null) throw _HttpError(401, 'unauthorized');
    for (final u in db.users.values) {
      if (u['token'] == token) return u;
    }
    throw _HttpError(401, 'unauthorized');
  }

  Future<Map<String, dynamic>> body(Request req) async {
    try {
      final raw = await req.readAsString();
      if (raw.isEmpty) return {};
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    throw _HttpError(400, 'bad_json');
  }

  void limit(String key, int n, Duration w) {
    if (!db.allow(key, n, w, clock())) throw _HttpError(429, 'rate_limited');
  }

  String iso(DateTime t) => t.toUtc().toIso8601String();

  Map<String, dynamic> postJson(Map<String, dynamic> p, String me) => {
    'id': p['id'],
    'nick': p['nick'],
    'text': p['text'],
    'at': p['at'],
    'likes': (p['likes'] as List).length,
    'liked': (p['likes'] as List).contains(me),
    'comments': (db.comments[p['id']] ?? []).length,
    'mine': p['userId'] == me,
  };

  bool linked(String ownerId, String supporterId) => db.links.any(
    (l) => l['ownerId'] == ownerId && l['supporterId'] == supporterId,
  );

  final r = Router();

  r.get('/health', (Request req) => _json({'ok': true}));

  r.post('/register', (Request req) async {
    limit(
      'register:${req.headers['x-forwarded-for'] ?? 'local'}',
      20,
      const Duration(hours: 1),
    );
    final id = randomId(rnd);
    final user = {
      'id': id,
      'token': randomToken(rnd),
      'nick': randomNick(rnd),
      'createdAt': iso(clock()),
    };
    db.users[id] = user;
    db.save();
    return _json({'userId': id, 'token': user['token'], 'nick': user['nick']});
  });

  // ---------- Лента ----------
  r.get('/posts', (Request req) {
    final me = auth(req)['id'] as String;
    final n = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 30;
    final visible = db.posts.where((p) => p['hidden'] != true).toList()
      ..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));
    return _json({
      'posts': [for (final p in visible.take(n.clamp(1, 100))) postJson(p, me)],
    });
  });

  r.post('/posts', (Request req) async {
    final u = auth(req);
    final j = await body(req);
    final m = moderate(j['text'] as String?);
    if (!m.isOk) throw _HttpError(422, m.error!);
    limit('post:${u['id']}', 10, const Duration(hours: 1));
    final post = {
      'id': randomId(rnd),
      'userId': u['id'],
      'nick': u['nick'],
      'text': (j['text'] as String).trim(),
      'at': iso(clock()),
      'likes': <String>[],
      'reports': <String>[],
      'hidden': false,
    };
    db.posts.add(post);
    db.save();
    return _json(postJson(post, u['id'] as String), 201);
  });

  Map<String, dynamic> findPost(String id) {
    for (final p in db.posts) {
      if (p['id'] == id && p['hidden'] != true) return p;
    }
    throw _HttpError(404, 'not_found');
  }

  r.delete('/posts/<id>', (Request req, String id) {
    final u = auth(req);
    final p = findPost(id);
    if (p['userId'] != u['id']) throw _HttpError(403, 'forbidden');
    db.posts.remove(p);
    db.comments.remove(id);
    db.save();
    return _json({'ok': true});
  });

  r.post('/posts/<id>/like', (Request req, String id) {
    final me = auth(req)['id'] as String;
    final likes = (findPost(id)['likes'] as List).cast<String>();
    final liked = !likes.contains(me);
    liked ? likes.add(me) : likes.remove(me);
    db.save();
    return _json({'likes': likes.length, 'liked': liked});
  });

  r.post('/posts/<id>/report', (Request req, String id) {
    final me = auth(req)['id'] as String;
    final p = findPost(id);
    final reports = (p['reports'] as List).cast<String>();
    if (!reports.contains(me)) reports.add(me);
    if (reports.length >= reportsToHide) p['hidden'] = true;
    db.save();
    return _json({'ok': true});
  });

  r.get('/posts/<id>/comments', (Request req, String id) {
    final me = auth(req)['id'] as String;
    findPost(id);
    return _json({
      'comments': [
        for (final c in db.comments[id] ?? [])
          {
            'id': c['id'],
            'nick': c['nick'],
            'text': c['text'],
            'at': c['at'],
            'mine': c['userId'] == me,
          },
      ],
    });
  });

  r.post('/posts/<id>/comments', (Request req, String id) async {
    final u = auth(req);
    findPost(id);
    final j = await body(req);
    final m = moderate(j['text'] as String?, maxLength: maxCommentLength);
    if (!m.isOk) throw _HttpError(422, m.error!);
    limit('comment:${u['id']}', 30, const Duration(hours: 1));
    final c = {
      'id': randomId(rnd),
      'userId': u['id'],
      'nick': u['nick'],
      'text': (j['text'] as String).trim(),
      'at': iso(clock()),
    };
    db.comments.putIfAbsent(id, () => []).add(c);
    db.save();
    return _json({
      'id': c['id'],
      'nick': c['nick'],
      'text': c['text'],
      'at': c['at'],
      'mine': true,
    }, 201);
  });

  // ---------- Близкие ----------
  r.post('/invites', (Request req) {
    final u = auth(req);
    limit('invite:${u['id']}', 10, const Duration(hours: 1));
    final code = randomInviteCode(rnd);
    db.invites[code] = {
      'ownerId': u['id'],
      'createdAt': iso(clock()),
      'used': false,
    };
    db.save();
    return _json({'code': code, 'expiresInDays': 7}, 201);
  });

  r.post('/invites/accept', (Request req) async {
    final u = auth(req);
    final j = await body(req);
    limit('accept:${u['id']}', 10, const Duration(hours: 1));
    final code = (j['code'] as String? ?? '').trim().toUpperCase();
    final inv = db.invites[code];
    if (inv == null || inv['used'] == true) {
      throw _HttpError(404, 'invalid_code');
    }
    final created = DateTime.parse(inv['createdAt'] as String);
    if (clock().difference(created) > const Duration(days: 7)) {
      throw _HttpError(410, 'expired');
    }
    final ownerId = inv['ownerId'] as String;
    if (ownerId == u['id']) throw _HttpError(400, 'own_code');
    if (linked(ownerId, u['id'] as String)) {
      throw _HttpError(409, 'already_linked');
    }
    if (db.links.where((l) => l['ownerId'] == ownerId).length >= 5) {
      throw _HttpError(409, 'too_many_supporters');
    }
    inv['used'] = true;
    db.links.add({
      'ownerId': ownerId,
      'supporterId': u['id'],
      'at': iso(clock()),
    });
    db.save();
    return _json({'ownerNick': db.users[ownerId]!['nick']});
  });

  r.put('/progress', (Request req) async {
    final u = auth(req);
    final j = await body(req);
    int n(String k) {
      final v = j[k];
      if (v is int && v >= 0 && v < 100000) return v;
      throw _HttpError(400, 'bad_$k');
    }

    final old = db.progress[u['id']] ?? {};
    db.progress[u['id'] as String] = {
      'smokeFreeDays': n('smokeFreeDays'),
      'daysInProgram': n('daysInProgram'),
      'cigsAvoided': n('cigsAvoided'),
      'updatedAt': iso(clock()),
      'lastSosAt': old['lastSosAt'],
    };
    db.save();
    return _json({'ok': true});
  });

  r.post('/sos', (Request req) {
    final u = auth(req);
    final p = db.progress.putIfAbsent(
      u['id'] as String,
      () => {
        'smokeFreeDays': 0,
        'daysInProgram': 0,
        'cigsAvoided': 0,
        'updatedAt': iso(clock()),
      },
    );
    p['lastSosAt'] = iso(clock());
    db.save();
    return _json({'ok': true});
  });

  r.get('/supporting', (Request req) {
    final me = auth(req)['id'] as String;
    return _json({
      'owners': [
        for (final l in db.links.where((l) => l['supporterId'] == me))
          () {
            final ownerId = l['ownerId'] as String;
            final p = db.progress[ownerId] ?? {};
            return {
              'ownerId': ownerId,
              'nick': db.users[ownerId]?['nick'],
              'smokeFreeDays': p['smokeFreeDays'] ?? 0,
              'daysInProgram': p['daysInProgram'] ?? 0,
              'updatedAt': p['updatedAt'],
              'lastSosAt': p['lastSosAt'],
            };
          }(),
      ],
    });
  });

  r.get('/supporters', (Request req) {
    final me = auth(req)['id'] as String;
    return _json({
      'supporters': [
        for (final l in db.links.where((l) => l['ownerId'] == me))
          {
            'supporterId': l['supporterId'],
            'nick': db.users[l['supporterId']]?['nick'],
            'since': l['at'],
          },
      ],
    });
  });

  r.post('/cheers', (Request req) async {
    final u = auth(req);
    final j = await body(req);
    final ownerId = j['ownerId'] as String? ?? '';
    if (!linked(ownerId, u['id'] as String)) {
      throw _HttpError(403, 'not_linked');
    }
    final m = moderate(j['text'] as String?, maxLength: maxCheerLength);
    if (!m.isOk) throw _HttpError(422, m.error!);
    limit('cheer:${u['id']}', 20, const Duration(days: 1));
    db.messages.add({
      'id': randomId(rnd),
      'ownerId': ownerId,
      'nick': u['nick'],
      'text': (j['text'] as String).trim(),
      'at': iso(clock()),
    });
    db.save();
    return _json({'ok': true}, 201);
  });

  r.get('/messages', (Request req) {
    final me = auth(req)['id'] as String;
    final since = req.url.queryParameters['since'];
    final mine =
        db.messages
            .where((m) => m['ownerId'] == me)
            .where(
              (m) => since == null || (m['at'] as String).compareTo(since) > 0,
            )
            .toList()
          ..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));
    return _json({
      'messages': [
        for (final m in mine.take(50))
          {'id': m['id'], 'nick': m['nick'], 'text': m['text'], 'at': m['at']},
      ],
    });
  });

  r.delete('/links/<otherId>', (Request req, String otherId) {
    final me = auth(req)['id'] as String;
    final before = db.links.length;
    db.links.removeWhere(
      (l) =>
          (l['ownerId'] == me && l['supporterId'] == otherId) ||
          (l['supporterId'] == me && l['ownerId'] == otherId),
    );
    if (db.links.length == before) throw _HttpError(404, 'not_found');
    db.save();
    return _json({'ok': true});
  });

  // ---------- Аккаунт ----------
  /// Полное удаление данных пользователя: учётка, посты, комментарии,
  /// связи, сводка прогресса и сообщения.
  r.delete('/account', (Request req) {
    final me = auth(req)['id'] as String;
    final myPosts = db.posts
        .where((p) => p['userId'] == me)
        .map((p) => p['id'])
        .toSet();
    db.posts.removeWhere((p) => p['userId'] == me);
    for (final id in myPosts) {
      db.comments.remove(id);
    }
    for (final list in db.comments.values) {
      list.removeWhere((c) => c['userId'] == me);
    }
    for (final p in db.posts) {
      (p['likes'] as List).remove(me);
      (p['reports'] as List).remove(me);
    }
    db.links.removeWhere((l) => l['ownerId'] == me || l['supporterId'] == me);
    db.invites.removeWhere((_, i) => i['ownerId'] == me);
    db.progress.remove(me);
    db.messages.removeWhere((m) => m['ownerId'] == me);
    db.users.remove(me);
    db.save();
    return _json({'ok': true});
  });

  // ---------- Коуч ----------
  r.post('/coach', (Request req) async {
    final u = auth(req);
    final backend = coach;
    if (backend == null) throw _HttpError(503, 'coach_unavailable');
    final j = await body(req);
    final messages = sanitizeMessages(j['messages'] as List? ?? []);
    if (messages.isEmpty) throw _HttpError(400, 'no_messages');
    limit('coach:${u['id']}', 40, const Duration(hours: 1));
    var context = (j['context'] as String? ?? '').trim();
    if (context.length > 1500) context = context.substring(0, 1500);
    try {
      return _json({'reply': await backend.reply(messages, context)});
    } on CoachUnavailable {
      throw _HttpError(503, 'coach_unavailable');
    }
  });

  return const Pipeline().addMiddleware(_errors()).addHandler(r.call);
}

Middleware _errors() =>
    (inner) => (req) async {
      try {
        return await inner(req);
      } on _HttpError catch (e) {
        return _json({'error': e.code}, e.status);
      } catch (_) {
        return _json({'error': 'internal'}, 500);
      }
    };
