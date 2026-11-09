import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nosmoke_server/coach_backend.dart';
import 'package:test/test.dart';

void main() {
  late http.Request captured;

  AnthropicCoachBackend backend(
    Map<String, dynamic> response, {
    int status = 200,
  }) => AnthropicCoachBackend(
    apiKey: 'test-key',
    client: MockClient((req) async {
      captured = req;
      return http.Response.bytes(
        utf8.encode(jsonEncode(response)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  test('sends a well-formed Messages API request', () async {
    final b = backend({
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'text', 'text': 'Подыши глубоко.'},
      ],
    });
    final reply = await b.reply([
      {'role': 'user', 'content': 'Тянет'},
    ], 'Без сигарет: 3 дня');

    expect(reply, 'Подыши глубоко.');
    expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(captured.headers['x-api-key'], 'test-key');
    expect(captured.headers['anthropic-version'], '2026-10-21');

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['max_tokens'], greaterThan(0));
    expect(body['messages'], [
      {'role': 'user', 'content': 'Тянет'},
    ]);
    expect(body['system'], contains('Без сигарет: 3 дня'));
    expect(body['system'], contains('Ты не врач'));
    expect(body['output_config'], {'effort': 'low'});
    // Параметры, которые новые модели отклоняют (400), отправлять нельзя.
    for (final k in ['temperature', 'top_p', 'top_k', 'budget_tokens']) {
      expect(body.containsKey(k), isFalse, reason: k);
    }
    expect(body.containsKey('thinking'), isFalse);
  });

  test('joins several text blocks and ignores thinking blocks', () async {
    final b = backend({
      'content': [
        {'type': 'thinking', 'thinking': ''},
        {'type': 'text', 'text': 'Первое.'},
        {'type': 'text', 'text': 'Второе.'},
      ],
    });
    expect(
      await b.reply([
        {'role': 'user', 'content': 'x'},
      ], ''),
      'Первое.\nВторое.',
    );
  });

  test(
    'upstream error, refusal and empty reply become CoachUnavailable',
    () async {
      for (final (resp, status) in [
        (<String, dynamic>{'error': {}}, 500),
        (<String, dynamic>{'error': {}}, 429),
        (<String, dynamic>{'stop_reason': 'refusal', 'content': []}, 200),
        (<String, dynamic>{'content': []}, 200),
      ]) {
        final b = backend(resp, status: status);
        expect(
          () => b.reply([
            {'role': 'user', 'content': 'x'},
          ], ''),
          throwsA(isA<CoachUnavailable>()),
          reason: '$status $resp',
        );
      }
    },
  );

  test('system prompt keeps the safety rules', () {
    expect(coachSystemPrompt, contains('не врач'));
    expect(coachSystemPrompt, contains('экстренную службу'));
    expect(coachSystemPrompt, contains('Срыв — не провал'));
  });
}
