import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _rcApiKey = String.fromEnvironment('REVENUECAT_API_KEY');
const _rcAppleKey = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
const _rcGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');

class RevenueCatService {
  static bool _initialized = false;

  static bool get isConfigured =>
      _rcApiKey.isNotEmpty || _rcAppleKey.isNotEmpty || _rcGoogleKey.isNotEmpty;

  static String get _effectiveKey {
    if (Platform.isIOS && _rcAppleKey.isNotEmpty) return _rcAppleKey;
    if (Platform.isAndroid && _rcGoogleKey.isNotEmpty) return _rcGoogleKey;
    return _rcApiKey;
  }

  static Future<void> init() async {
    final key = _effectiveKey;
    if (key.isEmpty) {
      debugPrint('[RC] No API key — tipping will be mock-only');
      return;
    }
    if (_initialized) return;
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(key));
    _initialized = true;
    debugPrint('[RC] Initialized');
  }

  static Future<void> setUserId(String userId) async {
    if (!_initialized) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  static Future<void> logOut() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  /// Returns available tip products from RevenueCat offerings.
  static Future<List<StoreProduct>> getTipProducts() async {
    if (!_initialized) return [];
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current ?? offerings.all.values.firstOrNull;
      if (offering == null) return [];
      // Filter products that look like tips (contains 'tip')
      final tips = offering.availablePackages
          .where((p) => p.storeProduct.identifier.toLowerCase().contains('tip'))
          .map((p) => p.storeProduct)
          .toList();
      if (tips.isNotEmpty) return tips;
      // Fallback: return all products if no tip-named products
      return offering.availablePackages.map((p) => p.storeProduct).toList();
    } catch (e) {
      debugPrint('[RC] getOfferings failed: $e');
      return [];
    }
  }

  /// Purchase a tip product. Returns true on success.
  static Future<bool> purchaseTip(StoreProduct product) async {
    if (!_initialized) return false;
    try {
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(product),
      );
      return result.customerInfo.entitlements.all.isNotEmpty ||
          result.customerInfo.activeSubscriptions.isNotEmpty ||
          true; // for consumables, no entitlement, success = no exception
    } catch (e) {
      debugPrint('[RC] purchase failed: $e');
      rethrow;
    }
  }

  /// Find product matching amount in dollars (e.g. 5.00 -> tip_500 or tip_5)
  static StoreProduct? findProductForAmount(
    List<StoreProduct> products,
    double amount,
  ) {
    final cents = (amount * 100).round();
    final candidates = [
      'tip_$cents',
      'tip_${amount.toStringAsFixed(0)}',
      'tip_${amount.toStringAsFixed(2)}',
    ];
    for (final c in candidates) {
      for (final p in products) {
        if (p.identifier == c) return p;
      }
    }
    // Fallback: match by price
    for (final p in products) {
      if ((p.price * 100).round() == cents) return p;
    }
    return null;
  }

  /// Decompose [cents] into multiple products (greedy) so any custom amount
  /// works with just a few SKUs, e.g. 750 = 500 + 200 + 50.
  static List<StoreProduct>? decomposeAmount(
    List<StoreProduct> products,
    int cents,
  ) {
    if (products.isEmpty) return null;
    // Build price -> product map (price in cents)
    final sorted = [...products]
      ..sort(
        (a, b) => (b.price * 100).round().compareTo((a.price * 100).round()),
      );
    final result = <StoreProduct>[];
    var remaining = cents;
    for (final p in sorted) {
      final price = (p.price * 100).round();
      if (price <= 0) continue;
      while (remaining >= price) {
        result.add(p);
        remaining -= price;
      }
    }
    if (remaining != 0) return null; // not representable with current SKUs
    return result.isEmpty ? null : result;
  }
}
