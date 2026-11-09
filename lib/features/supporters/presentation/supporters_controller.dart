import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../progress/domain/progress.dart';
import '../data/supporters_repository.dart';
import '../domain/supporters_models.dart';

class SupportersController extends ChangeNotifier {
  SupportersController(
    this._repoFactory, {
    this._seen = const SeenMarker(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SupportersRepository? Function() _repoFactory;
  final SeenMarker _seen;
  final DateTime Function() _clock;

  List<SupportedOwner> _supporting = [];
  List<SupporterInfo> _supporters = [];
  List<CheerMessage> _unread = [];
  bool _loading = false;
  String? _error;

  ProgressSummary? _lastPushed;
  DateTime? _lastPushAt;

  List<SupportedOwner> get supporting => List.unmodifiable(_supporting);
  List<SupporterInfo> get supporters => List.unmodifiable(_supporters);

  /// Непрочитанные сообщения поддержки (новые сверху).
  List<CheerMessage> get unread => List.unmodifiable(_unread);
  bool get loading => _loading;
  String? get error => _error;
  bool get available => _repoFactory() != null;
  bool get hasSupporters => _supporters.isNotEmpty;

  Future<void> refresh() async {
    final repo = _repoFactory();
    if (repo == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final seen = await _seen.load();
      final results = await Future.wait([
        repo.supporting(),
        repo.supporters(),
        repo.messages(since: seen),
      ]);
      _supporting = results[0] as List<SupportedOwner>;
      _supporters = results[1] as List<SupporterInfo>;
      _unread = results[2] as List<CheerMessage>;
    } on ApiException catch (e) {
      _error = e.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Создаёт код приглашения. Возвращает (код, ошибка).
  Future<(String?, String?)> createInvite() async {
    final repo = _repoFactory();
    if (repo == null) return (null, 'network');
    try {
      return (await repo.createInvite(), null);
    } on ApiException catch (e) {
      return (null, e.code);
    }
  }

  /// Принимает код. Возвращает (псевдоним владельца, ошибка).
  Future<(String?, String?)> accept(String code) async {
    final repo = _repoFactory();
    if (repo == null) return (null, 'network');
    try {
      final nick = await repo.acceptInvite(code.trim());
      await refresh();
      return (nick, null);
    } on ApiException catch (e) {
      return (null, e.code);
    }
  }

  /// Отправляет ободрение. Возвращает код ошибки или null.
  Future<String?> cheer(String ownerId, String text) async {
    final repo = _repoFactory();
    if (repo == null) return 'network';
    try {
      await repo.cheer(ownerId, text);
      return null;
    } on ApiException catch (e) {
      return e.code;
    }
  }

  Future<void> unlink(String id) async {
    final repo = _repoFactory();
    if (repo == null) return;
    try {
      await repo.unlink(id);
    } on ApiException {
      return;
    }
    _supporting = _supporting.where((o) => o.ownerId != id).toList();
    _supporters = _supporters.where((s) => s.supporterId != id).toList();
    notifyListeners();
  }

  /// Отмечает все текущие сообщения как прочитанные.
  Future<void> markRead() async {
    if (_unread.isEmpty) return;
    final latest = _unread
        .map((m) => m.at)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    await _seen.save(latest.toUtc().toIso8601String());
    _unread = [];
    notifyListeners();
  }

  /// Сообщает близким, что пользователь нажал SOS. Тихо игнорирует ошибки.
  Future<void> pingSos() async {
    final repo = _repoFactory();
    if (repo == null) return;
    try {
      await repo.sos();
    } on ApiException {
      return;
    }
  }

  /// Отправляет сводку прогресса. Не чаще раза в 10 минут, если ничего не
  /// изменилось.
  Future<void> syncProgress(ProgressSnapshot s) async {
    final repo = _repoFactory();
    if (repo == null || !s.started) return;
    final summary = ProgressSummary(
      smokeFreeDays: s.streakActive ? s.smokeFree.inDays : 0,
      daysInProgram: s.daysInProgram,
      cigsAvoided: s.cigsAvoided,
    );
    final now = _clock();
    final fresh =
        _lastPushAt != null &&
        now.difference(_lastPushAt!) < const Duration(minutes: 10);
    if (summary == _lastPushed && fresh) return;
    try {
      await repo.pushProgress(summary);
      _lastPushed = summary;
      _lastPushAt = now;
    } on ApiException {
      return;
    }
  }
}
