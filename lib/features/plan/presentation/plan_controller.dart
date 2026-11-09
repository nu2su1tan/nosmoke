import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/purchase_service.dart';
import '../domain/entitlements.dart';

/// Права доступа. Если подписка выключена флагом ([paywall] == false), доступно всё.
class PlanController extends ChangeNotifier {
  PlanController(this._service, {bool? paywall})
    : paywall = paywall ?? paywallEnabled {
    _sub = _service.premiumChanges.listen((active) async {
      if (active) await _setPremium(true);
    });
  }

  static const _key = 'premium_v1';

  final PurchaseService _service;
  final bool paywall;
  StreamSubscription<bool>? _sub;

  bool _premium = false;
  List<PremiumProduct> _products = [];
  bool _loading = false;

  bool get isPremium => _premium;
  List<PremiumProduct> get products => List.unmodifiable(_products);
  bool get loading => _loading;

  bool can(PremiumFeature f) => !paywall || _premium;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _premium = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _loading = true;
    notifyListeners();
    try {
      _products = await _service.products();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> buy(String id) => _service.buy(id);

  Future<void> restore() => _service.restore();

  Future<void> _setPremium(bool v) async {
    if (_premium == v) return;
    _premium = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
  }

  Future<void> clear() async {
    _premium = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
