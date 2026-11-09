import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile.dart';

class ProfileStore {
  static const _key = 'profile_v1';

  Future<Profile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Profile.decode(raw);
    } catch (_) {
      return null; // повреждённые данные -> заново пройти онбординг
    }
  }

  Future<void> save(Profile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, p.encode());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
