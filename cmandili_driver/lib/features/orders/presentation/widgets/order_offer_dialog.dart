import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Modal countdown shown when the backend offers an order to this driver.
///
/// The dialog fetches the order row directly so we don't depend on the
/// orders provider being awake. If the timer expires without action, we
/// call the `pass_order_offer` RPC so the next driver gets pinged
/// immediately rather than waiting for the next cron tick.
///
/// Returns:
///   - true  → driver tapped Accept (caller should refresh available orders)
///   - false → driver tapped Pass or the timer expired
///   - null  → dialog was dismissed externally (rare; treated like Pass)
class OrderOfferDialog extends StatefulWidget {
  final String orderId;
  final int windowSeconds;

  const OrderOfferDialog({
    super.key,
    required this.orderId,
    this.windowSeconds = 10,
  });

  @override
  State<OrderOfferDialog> createState() => _OrderOfferDialogState();
}

class _OrderOfferDialogState extends State<OrderOfferDialog> {
  late Timer _ticker;
  late int _remaining;
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.windowSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _remaining - 1);
      if (_remaining <= 0) _onPass(auto: true);
    });
    _loadOrder();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select('id, subtotal, delivery_fee, total, distance_km, '
              'delivery_address, restaurant_id, supermarket_id, '
              'restaurants(name), supermarkets(name)')
          .eq('id', widget.orderId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _order = row;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAccept() async {
    if (_settling) return;
    setState(() => _settling = true);
    // Closing with `true` so the caller refreshes available orders. Actual
    // accept logic (delivery row + driver_id write) is the existing flow in
    // available_orders_screen, triggered from the home screen on result.
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onPass({bool auto = false}) async {
    if (_settling) return;
    _settling = true;
    _ticker.cancel();
    try {
      await Supabase.instance.client
          .rpc('pass_order_offer', params: {'p_order_id': widget.orderId});
    } catch (_) {
      // Non-fatal: cron will retry. Don't trap the driver.
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.windowSeconds;
    final progressColor = _remaining <= 3 ? AppColors.error : AppColors.primary;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delivery_dining, color: progressColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'New delivery',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${_remaining}s',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildOrderSummary(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _settling ? null : () => _onPass(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Pass', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _settling ? null : _onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final order = _order;
    if (order == null) {
      return const Text(
        'Could not load order details — tap Accept to view, or Pass to skip.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    final partnerName = (order['restaurants'] is Map)
        ? (order['restaurants']['name'] ?? '')
        : (order['supermarkets'] is Map)
            ? (order['supermarkets']['name'] ?? '')
            : '';
    final fee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final distanceKm = (order['distance_km'] as num?)?.toDouble();
    final addr = order['delivery_address'];
    final addrText = (addr is Map ? (addr['fullAddress'] ?? addr['address'] ?? '') : '') as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partnerName.toString().isNotEmpty) ...[
          Text(
            partnerName.toString(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textLight),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                addrText.isEmpty ? 'Customer address' : addrText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Pill(
              icon: Icons.payments_rounded,
              label: '${CurrencyFormatter.formatPrice(fee)} fee',
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            if (distanceKm != null)
              _Pill(
                icon: Icons.route_outlined,
                label: '${distanceKm.toStringAsFixed(1)} km',
                color: AppColors.primary,
              ),
            const Spacer(),
            Text(
              CurrencyFormatter.formatPrice(total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
