import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Анонимная учётная запись на сервере сообщества.
class RemoteAccount {
  const RemoteAccount({
    required this.baseUrl,
    required this.userId,
    required this.token,
    required this.nick,
  });

  final String baseUrl;
  final String userId;
  final String token;
  final String nick;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'userId': userId,
    'token': token,
    'nick': nick,
  };

  factory RemoteAccount.fromJson(Map<String, dynamic> j) => RemoteAccount(
    baseUrl: j['baseUrl'] as String,
    userId: j['userId'] as String,
    token: j['token'] as String,
    nick: j['nick'] as String,
  );
}

class AccountStore {
  static const _key = 'account_v1';

  Future<RemoteAccount?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return RemoteAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RemoteAccount a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(a.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
