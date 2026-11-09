import 'package:flutter/foundation.dart';

import '../data/coach_service.dart';
import '../domain/coach_models.dart';

class CoachController extends ChangeNotifier {
  CoachController(this._service, this._context);

  final CoachService _service;
  final CoachContext Function() _context;

  final List<CoachMessage> _messages = [];
  bool _sending = false;

  List<CoachMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;
    _messages.add(CoachMessage(role: CoachRole.user, text: t));
    _sending = true;
    notifyListeners();
    try {
      final reply = await _service.reply(List.of(_messages), _context());
      _messages.add(
        CoachMessage(
          role: CoachRole.assistant,
          text: reply.text,
          source: reply.source,
        ),
      );
    } catch (_) {
      _messages.add(
        const CoachMessage(
          role: CoachRole.assistant,
          text: 'Не получилось ответить. Попробуй ещё раз.',
        ),
      );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }
}
