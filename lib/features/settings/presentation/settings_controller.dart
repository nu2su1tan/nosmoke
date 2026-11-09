import 'package:flutter/foundation.dart';

import '../../notifications/data/notification_service.dart';
import '../data/settings_store.dart';
import '../domain/friend.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store, this._notifications);

  final SettingsStore _store;
  final NotificationService _notifications;
  bool _notificationsEnabled = false;
  Friend? _friend;
  bool? _coachAi;

  bool get notificationsEnabled => _notificationsEnabled;

  /// Разрешил ли пользователь отправлять сообщения коучу на сервер (ИИ).
  /// null — не выбрано.
  bool? get coachAi => _coachAi;

  /// Контакт, которому звоним из экрана SOS.
  Friend? get friend => _friend;

  Future<void> load() async {
    _notificationsEnabled = await _store.loadNotificationsEnabled();
    _friend = await _store.loadFriend();
    _coachAi = await _store.loadCoachAi();
    notifyListeners();
  }

  Future<void> setFriend(Friend? f) async {
    _friend = f;
    notifyListeners();
    await _store.saveFriend(f);
  }

  Future<void> setCoachAi(bool v) async {
    _coachAi = v;
    notifyListeners();
    await _store.saveCoachAi(v);
  }

  Future<void> clear() async {
    _notificationsEnabled = false;
    _friend = null;
    _coachAi = null;
    notifyListeners();
    await _store.clear();
  }

  /// Включает/выключает напоминания. При включении просит разрешение;
  /// возвращает false, если пользователь отказал.
  Future<bool> setNotificationsEnabled(bool value) async {
    if (value) {
      final granted = await _notifications.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        await _store.saveNotificationsEnabled(false);
        notifyListeners();
        return false;
      }
    } else {
      await _notifications.cancelAll();
    }
    _notificationsEnabled = value;
    await _store.saveNotificationsEnabled(value);
    notifyListeners();
    return true;
  }
}
