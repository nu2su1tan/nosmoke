import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nosmoke_server/app.dart';
import 'package:nosmoke_server/coach_backend.dart';
import 'package:nosmoke_server/db.dart';
import 'package:shelf/shelf.dart' as shelf;

class FakeCoachBackend implements CoachBackend {
  final List<List<Map<String, String>>> calls = [];
  String? lastContext;
  bool fail = false;

  @override
  Future<String> reply(
    List<Map<String, String>> messages,
    String context,
  ) async {
    if (fail) throw CoachUnavailable('down');
    calls.add(messages);
    lastContext = context;
    return 'Ответ ИИ: дыши глубже.';
  }
}

/// Настоящий серверный код, запущенный внутри теста. Клиентское приложение
/// общается с ним через обычный http.Client, без сети.
class InProcessServer {
  InProcessServer({bool withCoach = true, DateTime Function()? now})
    : coach = withCoach ? FakeCoachBackend() : null {
    db = Db();
    handler = buildHandler(db, coach: coach, now: now, random: Random(42));
  }

  static const baseUrl = 'https://nosmoke.test';

  late final Db db;
  late final shelf.Handler handler;
  final FakeCoachBackend? coach;

  /// Все запросы, которые дошли до сервера: «METHOD /path».
  final List<String> requests = [];
  final List<String> bodies = [];

  /// Фабрика клиентов для Services.httpClient.
  http.Client Function() get clientFactory =>
      () => MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        bodies.add(req.body);
        final res = await handler(
          shelf.Request(
            req.method,
            req.url,
            headers: req.headers,
            body: req.bodyBytes,
          ),
        );
        final bytes = await res.read().fold<List<int>>(
          [],
          (a, b) => a..addAll(b),
        );
        return http.Response.bytes(
          bytes,
          res.statusCode,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

  /// Регистрирует пользователя напрямую (для подготовки второго участника).
  Future<({String userId, String token, String nick})> registerUser() async {
    final res = await handler(
      shelf.Request('POST', Uri.parse('$baseUrl/register')),
    );
    final j = await res.readAsString();
    final m = Map<String, dynamic>.from(_decode(j) as Map);
    return (
      userId: m['userId'] as String,
      token: m['token'] as String,
      nick: m['nick'] as String,
    );
  }

  /// Выполняет запрос от имени другого пользователя.
  Future<Map<String, dynamic>> as(
    String token,
    String method,
    String path, [
    String? body,
  ]) async {
    final res = await handler(
      shelf.Request(
        method,
        Uri.parse('$baseUrl$path'),
        headers: {'x-user-token': token},
        body: body,
      ),
    );
    final text = await res.readAsString();
    return text.isEmpty ? {} : Map<String, dynamic>.from(_decode(text) as Map);
  }
}

dynamic _decode(String s) => jsonDecode(s);
