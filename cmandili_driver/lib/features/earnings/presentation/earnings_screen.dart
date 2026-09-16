import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/driver_orders_provider.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';

/// Recent-deliveries card label — type-aware so a driver can tell what they
/// actually delivered, not just an opaque order ID. Same fallback shape as
/// available_orders_screen's _orderTitle, but food/supermarket orders show
/// the item names here instead of the restaurant name, since that's the
/// more useful "what was this" cue in a historical list.
String _deliveryPrimaryLabel(Order order) {
  switch (order.type) {
    case OrderType.courier:
      final desc = order.packageDescription?.trim();
      return (desc != null && desc.isNotEmpty) ? desc : 'Colis';
    case OrderType.facture:
    case OrderType.billPayment:
      return 'Facture';
    default:
      final summary = order.contentSummary?.trim();
      if (summary != null && summary.isNotEmpty) return summary;
      return order.restaurantName.isNotEmpty
          ? order.restaurantName
          : 'Order #${order.id.substring(0, 8).toUpperCase()}';
  }
}

/// "Collecté: 3.500 DT — Commission: -0.805 DT — Net: 2.695 DT", with a
/// "Subvention" field inserted when a loyalty subsidy applies. Net always
/// equals what a normal full-price delivery would have netted, since the
/// subsidy exists specifically to make loyalty-discounted deliveries earn
/// the same as full-price ones. Null when there's no commission_deduction
/// settlement for this order yet (generate_settlements_on_delivery() is
/// cash-only, so non-cash orders never get one).
String? _commissionBreakdownText(Order order) {
  final commission = order.commissionAmount;
  if (commission == null) return null;
  final collected = order.deliveryFee;
  final subsidy = order.loyaltySubsidyAmount;
  final net = collected + commission + (subsidy ?? 0);
  final parts = [
    'Collecté: ${collected.toStringAsFixed(3)} DT',
    'Commission: ${commission.toStringAsFixed(3)} DT',
    if (subsidy != null) 'Subvention: +${subsidy.toStringAsFixed(3)} DT',
    'Net: ${net.toStringAsFixed(3)} DT',
  ];
  return parts.join(' — ');
}

final _earningsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final supabase = Supabase.instance.client;
  final driverId = await ref.watch(currentDriverIdProvider.future);
  if (driverId == null) return {'total': 0.0, 'count': 0};

  final now = DateTime.now();
  DateTime start;
  if (period == 'today') {
    start = DateTime(now.year, now.month, now.day);
  } else if (period == 'week') {
    start = now.subtract(Duration(days: now.weekday - 1));
    start = DateTime(start.year, start.month, start.day);
  } else {
    start = DateTime(now.year, now.month, 1);
  }

  final result = await supabase.rpc('get_driver_earnings', params: {
    'p_driver_id': driverId,
    // Postgres receives these as timestamptz. Without an explicit UTC
    // conversion, a naive local-time string carries no zone info and gets
    // interpreted as UTC, silently shifting the "today" boundary by the
    // driver's own UTC offset.
    'p_start_date': start.toUtc().toIso8601String(),
    'p_end_date': now.toUtc().toIso8601String(),
  });
  if (result is Map) {
    return {
      'total': (result['total'] as num?)?.toDouble() ?? 0.0,
      'count': (result['count'] as num?)?.toInt() ?? 0,
    };
  }
  return {'total': 0.0, 'count': 0};
});

class EarningsScreen extends ConsumerStatefulWidget {
  // HomeScreen keeps every tab mounted via IndexedStack, so this screen
  // never gets a fresh initState when the driver switches to it — isActive
  // is how it finds out instead (see didUpdateWidget below).
  final bool isActive;

  const EarningsScreen({super.key, this.isActive = true});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  String _period = 'today';

  @override
  void didUpdateWidget(covariant EarningsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Becoming the active tab is the only signal available — refetch so
      // a delivery completed on another tab isn't shown stale here.
      ref.invalidate(_earningsProvider);
      ref.invalidate(driverDeliveryHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(_earningsProvider(_period));
    final historyAsync = ref.watch(driverDeliveryHistoryProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.earnings,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_earningsProvider);
          ref.invalidate(driverDeliveryHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Period selector
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  _PeriodTab(
                      label: l.today,
                      value: 'today',
                      selected: _period,
                      onTap: (v) => setState(() => _period = v)),
                  _PeriodTab(
                      label: l.thisWeek,
                      value: 'week',
                      selected: _period,
                      onTap: (v) => setState(() => _period = v)),
                  _PeriodTab(
                      label: l.thisMonth,
                      value: 'month',
                      selected: _period,
                      onTap: (v) => setState(() => _period = v)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Earnings card
            earningsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(l.couldNotLoadEarnings),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(_earningsProvider(_period)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.retry),
                    ),
                  ],
                ),
              ),
              data: (data) => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.totalEarnings,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${(data['total'] as double).toStringAsFixed(2)} DT',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.delivery_dining,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${data['count']} ${l.deliveriesCompleted}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent deliveries
            Text(l.recentDeliveries,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(l.couldNotLoadHistory),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(driverDeliveryHistoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.retry),
                    ),
                  ],
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long,
                              size: 48, color: AppColors.textLight),
                          const SizedBox(height: 12),
                          Text(l.noDeliveriesYet,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: orders.take(20).map((order) {
                    final breakdown = _commissionBreakdownText(order);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.check_circle,
                                    color: AppColors.success, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _deliveryPrimaryLabel(order),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '#${order.id.substring(0, 8).toUpperCase()} · ${order.deliveryAddress.fullAddress.isNotEmpty ? order.deliveryAddress.fullAddress : order.deliveryAddress.label}',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${order.deliveryFee.toStringAsFixed(2)} DT',
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                          if (breakdown != null) ...[
                            const SizedBox(height: 10),
                            Container(height: 1, color: AppColors.background),
                            const SizedBox(height: 8),
                            Text(
                              breakdown,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _PeriodTab(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
