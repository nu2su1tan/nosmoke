import 'dart:io';

import 'package:nosmoke_server/app.dart';
import 'package:nosmoke_server/coach_backend.dart';
import 'package:nosmoke_server/db.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Запуск: ANTHROPIC_API_KEY=... PORT=8080 DATA_FILE=data.json dart run bin/server.dart
Future<void> main() async {
  final env = Platform.environment;
  final key = env['ANTHROPIC_API_KEY'];
  final handler = buildHandler(
    Db.load(env['DATA_FILE']),
    coach: key == null || key.isEmpty
        ? null
        : AnthropicCoachBackend(apiKey: key),
  );
  final server = await io.serve(
    handler,
    InternetAddress.anyIPv4,
    int.tryParse(env['PORT'] ?? '') ?? 8080,
  );
  stdout.writeln(
    'NoSmoke server: http://${server.address.host}:${server.port} '
    '(коуч: ${key == null || key.isEmpty ? 'выключен, нет ANTHROPIC_API_KEY' : 'включён'})',
  );
}
