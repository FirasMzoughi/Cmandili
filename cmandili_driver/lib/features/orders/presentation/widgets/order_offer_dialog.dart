import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/background_location_service.dart';
import '../../providers/driver_orders_provider.dart';

/// Card title — type-aware so a driver can't mistake a courier package for
/// a food order (or vice versa) before deciding to accept. A named
/// restaurant/supermarket always wins; otherwise falls back to whatever
/// distinguishes the order type.
String _offerTitle(Map<String, dynamic> order, String partnerName) {
  if (partnerName.isNotEmpty) return partnerName;
  final orderType = order['order_type'] as String?;
  if (orderType == 'courier') {
    final desc = (order['package_description'] as String?)?.trim();
    return (desc != null && desc.isNotEmpty) ? desc : 'Colis';
  }
  if (orderType == 'facture' || orderType == 'billPayment') return 'Facture';
  return 'New delivery';
}

/// "Pizza Margherita x2, et 3 autres" — food/supermarket orders only.
String? _offerItemsSummary(Map<String, dynamic> order) {
  final orderType = order['order_type'] as String?;
  if (orderType != 'food' && orderType != 'supermarket') return null;
  final items = (order['order_items'] as List?) ?? [];
  if (items.isEmpty) return null;
  final names = items
      .cast<Map<String, dynamic>>()
      .map((it) {
        final foodItem = it['food_items'] as Map<String, dynamic>?;
        final groceryItem = it['grocery_items'] as Map<String, dynamic>?;
        final name = (foodItem?['name'] ?? groceryItem?['name'] ?? '') as String;
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        return qty > 1 ? '$name x$qty' : name;
      })
      .where((s) => s.isNotEmpty)
      .toList();
  if (names.isEmpty) return null;
  if (names.length <= 2) return names.join(', ');
  final remaining = names.length - 2;
  return '${names.take(2).join(', ')}, et $remaining autre${remaining > 1 ? 's' : ''}';
}

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
class OrderOfferDialog extends ConsumerStatefulWidget {
  final String orderId;
  // Fallback only, matching dispatch_driver_for_order's server-side default
  // (p_window_secs). Once the order loads, the countdown is resynced to its
  // real assignment_expires_at — this value only covers the first tick or
  // two before that arrives, and the rare case where the row has none.
  final int windowSeconds;

  const OrderOfferDialog({
    super.key,
    required this.orderId,
    this.windowSeconds = 30,
  });

  @override
  ConsumerState<OrderOfferDialog> createState() => _OrderOfferDialogState();
}

class _OrderOfferDialogState extends ConsumerState<OrderOfferDialog> {
  late Timer _ticker;
  late int _remaining;
  late int _totalSeconds;
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _settling = false;
  String? _acceptError;
  // When true, the inline reject-confirmation panel is visible.
  // The countdown timer is NOT paused — it keeps ticking normally.
  bool _confirmingReject = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.windowSeconds;
    _totalSeconds = widget.windowSeconds;
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
    Map<String, dynamic>? row;
    // This dialog can mount moments after a cold start (see
    // HomeScreen._checkForPendingOffer), while Supabase's session/network
    // may still be settling. Retry a couple of times on a transient failure
    // instead of immediately falling back to "could not load" — and always
    // log what actually went wrong, instead of swallowing it silently.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        row = await Supabase.instance.client
            .from('orders')
            .select('id, subtotal, delivery_fee, total, distance_km, '
                'delivery_address, restaurant_id, supermarket_id, '
                'loyalty_milestone_type, loyalty_discount_amount, '
                'order_type, package_description, bill_type, assignment_expires_at, '
                'order_items(quantity, food_items(name), grocery_items(name)), '
                'restaurants(name), supermarkets(name)')
            .eq('id', widget.orderId)
            .maybeSingle();
        break;
      } catch (e) {
        debugPrint('OrderOfferDialog: load failed for ${widget.orderId} '
            '(attempt $attempt/3): $e');
        if (attempt < 3) await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    if (!mounted) return;

    // Resync the countdown to the real server deadline instead of trusting
    // widget.windowSeconds — this dialog can open well into the offer's
    // actual window (e.g. HomeScreen._checkForPendingOffer firing seconds
    // after the offer was created, on resume), so a fixed default would
    // show more time than the driver actually has left.
    final expiresAtStr = row?['assignment_expires_at'] as String?;
    int? syncedRemaining;
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr).toUtc();
      final secsLeft = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      syncedRemaining = secsLeft > 0 ? secsLeft : 0;
    }

    final remaining = syncedRemaining;
    setState(() {
      _order = row;
      _loading = false;
      if (remaining != null) {
        _remaining = remaining;
        _totalSeconds = remaining > 0 ? remaining : 1;
      }
    });

    if (remaining == 0) _onPass(auto: true);
  }

  Future<void> _onAccept() async {
    if (_settling) return;
    setState(() {
      _settling = true;
      _acceptError = null;
    });
    try {
      final driverId = await ref.read(currentDriverIdProvider.future);
      if (driverId == null) throw 'Driver profile not found';

      // Atomically claim the order server-side — accept_order_offer() checks
      // assignment_expires_at against Postgres's own now(), not the phone's
      // clock. The old .update()...gt(<phone timestamp>) version compared
      // against whatever time the phone happened to send, so clock drift or
      // plain network latency could reject a still-valid offer. Returns the
      // claimed order id, or NULL if it lost the race (already taken,
      // reassigned, or genuinely expired per the server).
      final claimedId = await Supabase.instance.client.rpc(
        'accept_order_offer',
        params: {'p_order_id': widget.orderId},
      );

      if (claimedId == null) {
        throw 'This offer is no longer available.';
      }

      // Create delivery row now that we own the order — same shape as the
      // available-orders list's accept flow.
      final deliveryRow = await Supabase.instance.client
          .from('deliveries')
          .insert({
            'order_id': widget.orderId,
            'driver_id': driverId,
            'status': 'accepted',
            'current_lat': 0,
            'current_lng': 0,
          })
          .select('id')
          .single();

      await BackgroundLocationService.startTracking(
        driverId: driverId,
        deliveryId: deliveryRow['id'] as String,
      );

      _ticker.cancel();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('OrderOfferDialog: accept failed for ${widget.orderId}: $e');
      if (!mounted) return;
      setState(() {
        _settling = false;
        _acceptError = 'Impossible d\'accepter cette commande — elle a '
            'peut-être expiré ou a été prise par un autre livreur.';
      });
    }
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
    final progress = _remaining / _totalSeconds;
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
              if (_acceptError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _acceptError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // ── Inline reject confirmation panel ─────────────────────────────
              // Shown when driver taps "Refuser". The countdown timer (_ticker)
              // keeps running normally — if it expires while this panel is
              // visible, _onPass(auto: true) fires and pops the whole dialog.
              if (_confirmingReject) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Êtes-vous sûr ?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Voulez-vous vraiment refuser cette commande ?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _settling ? null : () => _onPass(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Oui, je refuse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _settling ? null : () {
                                setState(() => _confirmingReject = false);
                                _onAccept();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Non, j\'accepte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        // Show inline confirmation panel instead of passing immediately.
                        onPressed: _settling ? null : () => setState(() => _confirmingReject = true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
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
    final loyaltyMilestoneType = order['loyalty_milestone_type'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loyalty milestone banner — shown before Accept/Refuse so the
        // driver is never surprised at pickup/drop-off by reduced cash.
        // delivery_fee above already reflects the discount; this just
        // explains why and reassures the driver their earning is unaffected.
        if (loyaltyMilestoneType != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.loyalty_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loyaltyMilestoneType == 'free'
                        ? 'Commande fidélité — le client ne paiera aucun frais de livraison en espèces. Votre gain reste inchangé, la différence est prise en charge par la plateforme.'
                        : 'Commande fidélité — le client paiera 50% du tarif de livraison en espèces. Votre gain reste inchangé, la différence est prise en charge par la plateforme.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          _offerTitle(order, partnerName.toString()),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        if (_offerItemsSummary(order) != null) ...[
          const SizedBox(height: 2),
          Text(
            _offerItemsSummary(order)!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
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
