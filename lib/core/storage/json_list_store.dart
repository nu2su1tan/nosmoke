import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Хранит список JSON-объектов под одним ключом в SharedPreferences.
class JsonListStore<T> {
  const JsonListStore({
    required this.key,
    required this.fromJson,
    required this.toJson,
  });

  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  Future<List<T>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final List decoded;
    try {
      decoded = jsonDecode(raw) as List;
    } catch (_) {
      return []; // файл целиком повреждён
    }
    // Одна плохая запись не должна стирать остальные.
    final items = <T>[];
    for (final e in decoded) {
      try {
        items.add(fromJson(e as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  Future<void> save(List<T> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
