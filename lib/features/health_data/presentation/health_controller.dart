import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/health_source.dart';
import '../domain/health_metrics.dart';

class HealthController extends ChangeNotifier {
  HealthController(this._source);

  static const _key = 'health_connected_v1';

  final HealthSource _source;
  HealthTrend _trend = const HealthTrend();
  HealthAccess? _access;
  bool _connected = false;
  bool _loading = false;

  HealthTrend get trend => _trend;
  HealthAccess? get access => _access;
  bool get connected => _connected;
  bool get loading => _loading;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _connected = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Просит доступ и (при успехе) сразу подтягивает данные.
  Future<HealthAccess> connect(DateTime quitDate, [DateTime? now]) async {
    _access = await _source.connect();
    _connected = _access == HealthAccess.granted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _connected);
    notifyListeners();
    if (_connected) await refresh(quitDate, now);
    return _access!;
  }

  Future<void> refresh(DateTime quitDate, [DateTime? now]) async {
    if (!_connected) return;
    final t = now ?? DateTime.now();
    _loading = true;
    notifyListeners();
    try {
      final from = DateTime(t.year, t.month, t.day - 60);
      final days = await _source.daily(from, t);
      _trend = computeHealthTrend(days, quitDate, t);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _connected = false;
    _access = null;
    _trend = const HealthTrend();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
