import 'dart:convert';

import 'package:http/http.dart' as http;

/// Модель по умолчанию для коуча.
const coachModel = 'claude-opus-5-5';

const coachSystemPrompt = '''
Ты — поддерживающий коуч в приложении, которое помогает бросить курить. Отвечай по-русски, тепло и кратко (до 120 слов), без нравоучений и без списков длиннее 3 пунктов.

Правила:
- Ты не врач. Не назначай лекарства и дозировки. При вопросах о никотинзаместительной терапии, лекарствах или симптомах предложи обсудить это с врачом.
- Тяга длится обычно 3–5 минут: помогай её переждать (дыхание, вода, движение, отвлечение, звонок близкому).
- Срыв — не провал. Не стыди. Помоги понять причину и вернуться к плану.
- Используй только факты о пользователе из блока КОНТЕКСТ. Ничего не выдумывай о нём.
- Если человек пишет о желании причинить себе вред или о кризисе, мягко и коротко скажи, что ему нужна живая помощь, и посоветуй обратиться к близкому человеку или в экстренную службу своей страны. Не продолжай обычный разговор о курении.
- Не обсуждай темы, не связанные с отказом от курения, здоровьем и самочувствием; вежливо возвращай разговор к ним.
''';

/// Источник ответов коуча. Интерфейс нужен, чтобы тесты не ходили в сеть.
abstract class CoachBackend {
  Future<String> reply(List<Map<String, String>> messages, String context);
}

/// Приводит историю к виду, который принимает Messages API: начинается с
/// сообщения пользователя, роли чередуются, длина ограничена.
List<Map<String, String>> sanitizeMessages(List<dynamic> raw) {
  final out = <Map<String, String>>[];
  for (final m in raw.skip(raw.length > 20 ? raw.length - 20 : 0)) {
    if (m is! Map) continue;
    final role = m['role'] == 'assistant' ? 'assistant' : 'user';
    var text = (m['text'] ?? '').toString().trim();
    if (text.isEmpty) continue;
    if (text.length > 1000) text = text.substring(0, 1000);
    if (out.isEmpty && role == 'assistant') continue;
    if (out.isNotEmpty && out.last['role'] == role) {
      out.last = {'role': role, 'content': '${out.last['content']}\n$text'};
    } else {
      out.add({'role': role, 'content': text});
    }
  }
  return out;
}

class AnthropicCoachBackend implements CoachBackend {
  AnthropicCoachBackend({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<String> reply(
    List<Map<String, String>> messages,
    String context,
  ) async {
    final res = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2026-10-21',
          },
          body: jsonEncode({
            'model': coachModel,
            'max_tokens': 1024,
            'system': '$coachSystemPrompt\n\nКОНТЕКСТ:\n$context',
            'messages': messages,
            'output_config': {'effort': 'low'},
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw CoachUnavailable('upstream_${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    // Безопасное завершение: при отказе классификатора текста может не быть.
    if (body['stop_reason'] == 'refusal') {
      throw CoachUnavailable('refusal');
    }
    final text = [
      for (final b in (body['content'] as List? ?? []))
        if (b is Map && b['type'] == 'text') b['text'] as String,
    ].join('\n').trim();
    if (text.isEmpty) throw CoachUnavailable('empty');
    return text;
  }
}

class CoachUnavailable implements Exception {
  CoachUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'CoachUnavailable($reason)';
}
