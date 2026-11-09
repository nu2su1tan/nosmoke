import '../../../core/network/api_client.dart';
import '../domain/coach_models.dart';
import '../domain/local_coach.dart';

class CoachReply {
  const CoachReply(this.text, this.source);

  final String text;
  final CoachSource source;
}

abstract class CoachService {
  Future<CoachReply> reply(List<CoachMessage> history, CoachContext context);
}

/// Коуч на сервере (прокси к Claude): ключ API хранится на сервере, не в
/// приложении.
class RemoteCoach implements CoachService {
  RemoteCoach(this._api);

  final ApiClient _api;

  @override
  Future<CoachReply> reply(
    List<CoachMessage> history,
    CoachContext context,
  ) async {
    final j = await _api.post('/coach', {
      'messages': [
        for (final m in history)
          {
            'role': m.role == CoachRole.user ? 'user' : 'assistant',
            'text': m.text,
          },
      ],
      'context': context.toPrompt(),
    });
    final text = (j['reply'] as String?)?.trim() ?? '';
    if (text.isEmpty) throw const ApiException(502, 'empty_reply');
    return CoachReply(text, CoachSource.remote);
  }
}

/// Главный коуч приложения:
/// 1. сообщения о кризисе всегда обрабатываются локально и мгновенно;
/// 2. если пользователь разрешил ИИ и сервер доступен, отвечает модель;
/// 3. при любой ошибке отвечает офлайн-коуч, чтобы чат никогда не молчал.
class FallbackCoach implements CoachService {
  FallbackCoach({
    required this.remote,
    required this.aiAllowed,
    this.local = const LocalCoach(),
  });

  /// Возвращает удалённый коуч или null, если сервер не подключён.
  final CoachService? Function() remote;
  final bool Function() aiAllowed;
  final LocalCoach local;

  @override
  Future<CoachReply> reply(
    List<CoachMessage> history,
    CoachContext context,
  ) async {
    final last = history.lastWhere(
      (m) => m.role == CoachRole.user,
      orElse: () => const CoachMessage(role: CoachRole.user, text: ''),
    );
    if (isCrisisMessage(last.text)) {
      return const CoachReply(crisisReply, CoachSource.local);
    }
    final r = aiAllowed() ? remote() : null;
    if (r != null) {
      try {
        return await r.reply(history, context);
      } catch (_) {
        // сеть, лимит, отказ модели: переходим на офлайн-ответ
      }
    }
    return CoachReply(local.reply(last.text, context), CoachSource.local);
  }
}
