import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/entitlements.dart';

abstract class PurchaseService {
  /// Эмитит true, когда подписка активна (после покупки или восстановления).
  Stream<bool> get premiumChanges;

  Future<List<PremiumProduct>> products();

  /// Запускает покупку. false — не удалось начать.
  Future<bool> buy(String productId);

  Future<void> restore();

  void dispose();
}

/// Покупки через App Store / Google Play.
///
/// Внимание: статус подписки определяется на устройстве. Для защиты от
/// подделки проверяй чеки на сервере перед тем, как включать платные функции.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService() {
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Purchase stream error: $e'),
    );
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  final _controller = StreamController<bool>.broadcast();
  final Map<String, ProductDetails> _cache = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Stream<bool> get premiumChanges => _controller.stream;

  @override
  Future<List<PremiumProduct>> products() async {
    try {
      if (!await _iap.isAvailable()) return [];
      final res = await _iap.queryProductDetails(premiumProductIds);
      _cache
        ..clear()
        ..addEntries(res.productDetails.map((p) => MapEntry(p.id, p)));
      return [
        for (final p in res.productDetails)
          PremiumProduct(id: p.id, title: p.title, price: p.price),
      ];
    } catch (e) {
      debugPrint('Products failed: $e');
      return [];
    }
  }

  @override
  Future<bool> buy(String productId) async {
    final p = _cache[productId];
    if (p == null) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: p),
      );
    } catch (e) {
      debugPrint('Buy failed: $e');
      return false;
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final d in list) {
      if (d.status == PurchaseStatus.purchased ||
          d.status == PurchaseStatus.restored) {
        if (premiumProductIds.contains(d.productID)) _controller.add(true);
      }
      if (d.pendingCompletePurchase) {
        await _iap.completePurchase(d);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

/// Заглушка: используется, пока подписка выключена флагом.
class NoPurchaseService implements PurchaseService {
  @override
  Stream<bool> get premiumChanges => const Stream.empty();

  @override
  Future<List<PremiumProduct>> products() async => [];

  @override
  Future<bool> buy(String productId) async => false;

  @override
  Future<void> restore() async {}

  @override
  void dispose() {}
}
