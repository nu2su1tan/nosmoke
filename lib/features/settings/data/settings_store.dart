import 'package:shared_preferences/shared_preferences.dart';

import '../domain/friend.dart';

class SettingsStore {
  static const _notifKey = 'notifications_enabled_v1';
  static const _friendNameKey = 'friend_name_v1';
  static const _friendPhoneKey = 'friend_phone_v1';
  static const _coachAiKey = 'coach_ai_v1';

  Future<bool> loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifKey) ?? false;
  }

  Future<void> saveNotificationsEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, v);
  }

  Future<Friend?> loadFriend() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_friendPhoneKey);
    if (phone == null || phone.isEmpty) return null;
    return Friend(name: prefs.getString(_friendNameKey) ?? '', phone: phone);
  }

  Future<void> saveFriend(Friend? f) async {
    final prefs = await SharedPreferences.getInstance();
    if (f == null) {
      await prefs.remove(_friendNameKey);
      await prefs.remove(_friendPhoneKey);
    } else {
      await prefs.setString(_friendNameKey, f.name);
      await prefs.setString(_friendPhoneKey, f.phone);
    }
  }

  /// Согласие на ИИ-коуч: null — ещё не выбрано.
  Future<bool?> loadCoachAi() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_coachAiKey)) {
      'yes' => true,
      'no' => false,
      _ => null,
    };
  }

  Future<void> saveCoachAi(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coachAiKey, v ? 'yes' : 'no');
  }

  /// Удаляет все настройки (при сбросе приложения).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notifKey);
    await prefs.remove(_friendNameKey);
    await prefs.remove(_friendPhoneKey);
    await prefs.remove(_coachAiKey);
  }
}
