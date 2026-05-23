import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Single non-consumable product: lifetime ownership for 7,000원.
class PurchaseController {
  PurchaseController._();
  static final PurchaseController instance = PurchaseController._();

  static const productId = 'daily_one_shot.lifetime';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});
    await _iap.restorePurchases();
  }

  Future<bool> buyLifetime() async {
    final available = await _iap.isAvailable();
    if (!available) return false;
    final response =
        await _iap.queryProductDetails(<String>{productId});
    if (response.productDetails.isEmpty) return false;
    final param = PurchaseParam(productDetails: response.productDetails.first);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _isPremium = true;
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
