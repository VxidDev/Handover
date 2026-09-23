import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/api.dart';
import '../services/revenuecat_service.dart';
import '../theme/colors.dart';

Future<void> showTipSheet(
  BuildContext context, {
  required int recipientId,
  required String recipientName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        TipSheet(recipientId: recipientId, recipientName: recipientName),
  );
}

class TipSheet extends StatefulWidget {
  const TipSheet({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });
  final int recipientId;
  final String recipientName;

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  final _controller = TextEditingController();
  List<StoreProduct> _products = [];
  bool _loadingProducts = true;
  bool _sending = false;
  double? _selectedAmount;

  static const _fallbacks = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final prods = await RevenueCatService.getTipProducts();
    if (mounted) {
      setState(() {
        _products = prods;
        _loadingProducts = false;
      });
    }
  }

  List<double> get _presetAmounts {
    if (_products.isNotEmpty) {
      return _products.map((p) => p.price).toList()..sort();
    }
    return _fallbacks;
  }

  void _pickPreset(double amount) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAmount = amount;
      _controller.text = amount.toStringAsFixed(
        amount.truncateToDouble() == amount ? 0 : 2,
      );
    });
  }

  void _stepAmount(double delta) {
    final cur = _customAmount ?? 0;
    final next = ((cur + delta) * 2).round() / 2.0;
    final clamped = next.clamp(0.5, 100.0);
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAmount = null;
      _controller.text = clamped.toStringAsFixed(
        clamped.truncateToDouble() == clamped ? 0 : 2,
      );
    });
  }

  double? get _customAmount {
    if (_selectedAmount != null) return _selectedAmount;
    final t = _controller.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    return (v * 2).round() / 2.0;
  }

  Future<void> _sendTip() async {
    final amount = _customAmount;
    if (amount == null) {
      _snack('Enter an amount');
      return;
    }
    if (amount < 0.5 || amount > 100) {
      _snack('Amount must be \$0.50 – \$100');
      return;
    }
    final cents = (amount * 100).round();

    setState(() => _sending = true);
    try {
      String? productId;

      // Play Billing: mock allowed in debug/profile for testing; blocked in release.
      if (RevenueCatService.isConfigured) {
        if (_products.isEmpty) {
          // In debug/profile with simulated store (no products), allow mock tip for testing
          if (kDebugMode || kProfileMode) {
            debugPrint('[Tip] No products — mock tip allowed in debug');
          } else {
            _snack(
              'Tipping is temporarily unavailable — purchases not configured. Please try again later.',
            );
            setState(() => _sending = false);
            return;
          }
        } else {
          // Try exact product first, then decompose into multiple purchases
          final exact = RevenueCatService.findProductForAmount(
            _products,
            amount,
          );
          List<StoreProduct> toPurchase;
          if (exact != null) {
            toPurchase = [exact];
          } else {
            final decomposed = RevenueCatService.decomposeAmount(
              _products,
              cents,
            );
            if (decomposed == null) {
              if (mounted)
                _snack(
                  'Can\'t make \$${amount.toStringAsFixed(2)} with available products — try \$${_presetAmounts.map((a) => a.toStringAsFixed(0)).join(", \$")}',
                );
              setState(() => _sending = false);
              return;
            }
            toPurchase = decomposed;
          }
          productId = toPurchase.map((p) => p.identifier).join(',');
          try {
            for (final p in toPurchase) {
              await RevenueCatService.purchaseTip(p);
            }
          } catch (e) {
            if (e.toString().contains('cancelled') ||
                e.toString().contains('UserCancelled')) {
              setState(() => _sending = false);
              return;
            }
            rethrow;
          }
        }
      } else {
        // Dev-only mock allowed; inform user no charge will occur.
        // In production backend will reject this — frontend guards by isConfigured check
        // but keep mock path for emulator/dev.
        if (_products.isEmpty) {
          // ignore: avoid_print
          debugPrint('[Tip] Mock tip — no RevenueCat configured (dev only)');
        } else {
          // Should not happen: products imply configured
          productId = null;
        }
      }

      await Api.post(
        '/api/tips',
        body: {
          'recipient_id': widget.recipientId,
          'amount_cents': cents,
          // ignore: use_null_aware_elements
          if (productId case final pid?) 'product_id': pid,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tipped \$${amount.toStringAsFixed(2)} to ${widget.recipientName} ❤️',
          ),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      _snack(describeError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + insets),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send a tip to ${widget.recipientName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Custom amount — choose a preset or enter your own',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingProducts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetAmounts.map((a) {
                  final selected = _customAmount == a;
                  return ChoiceChip(
                    label: Text(
                      '\$${a.toStringAsFixed(a.truncateToDouble() == a ? 0 : 2)}',
                    ),
                    selected: selected,
                    onSelected: (_) => _pickPreset(a),
                    selectedColor: AppColors.terracotta.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.terracottaDeep
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => _stepAmount(-0.5),
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSand : Colors.white,
                    foregroundColor: theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() => _selectedAmount = null),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                      hintText: '7.50',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSand.withValues(alpha: 0.6)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _stepAmount(0.5),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Step \$0.50',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            if (_customAmount != null && _customAmount! >= 0.5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Recipient gets 80% (\$${(_customAmount! * 0.8).toStringAsFixed(2)}) · platform 20% (\$${(_customAmount! * 0.2).toStringAsFixed(2)})',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11.5,
                  ),
                ),
              ),
            if (_customAmount != null && _customAmount! >= 0.5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Charged via Google Play Billing. You will see the Play confirmation and price before paying.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (!RevenueCatService.isConfigured)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Dev mode — no charge. Production requires Google Play Billing (backend will reject mock tips).',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              )
            else if (_products.isEmpty && !_loadingProducts)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Purchases unavailable — please try again later. Tips must use Google Play Billing per Play Payments policy.',
                  style: TextStyle(
                    color: AppColors.error.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _sendTip,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send tip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
