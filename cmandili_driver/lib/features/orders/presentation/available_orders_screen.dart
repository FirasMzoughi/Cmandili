import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/push/push_service.dart';
import '../data/models/order.dart';
import '../providers/driver_orders_provider.dart';
import 'order_tracking_screen.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';

class AvailableOrdersScreen extends ConsumerWidget {
  const AvailableOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(availableOrdersProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.availableOrders, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delivery_dining, size: 80, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  Text(
                    l.noOrdersAvailable,
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.pullDownToRefresh,
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(availableOrdersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) =>
                  _OrderCard(order: orders[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;
  const _OrderCard({required this.order});

  Future<void> _acceptOrder(BuildContext context, WidgetRef ref) async {
    final supabase = Supabase.instance.client;

    // Stop the alarm immediately so the driver isn't still hearing it while
    // the accept flow runs. cancelDeliveryAlarm() is a no-op if no alarm is
    // playing (e.g. the driver opened via a tapped notification).
    await PushService.instance.cancelDeliveryAlarm();

    try {
      // Get or create driver record
      final driverId = await ref.read(currentDriverIdProvider.future);
      if (driverId == null) throw 'Driver profile not found';

      // Atomically claim the order: only succeeds if driver_id is still null,
      // so two drivers tapping Accept at the same time can't both win. The
      // second one gets an empty result and we abort before creating a
      // deliveries row or starting GPS tracking.
      final claimed = await supabase
          .from('orders')
          .update({'driver_id': driverId})
          .eq('id', order.id)
          .isFilter('driver_id', null)
          .select('id');

      if ((claimed as List).isEmpty) {
        throw 'This order was just taken by another driver.';
      }

      // Create delivery row now that we own the order.
      final deliveryRow = await supabase.from('deliveries').insert({
        'order_id': order.id,
        'driver_id': driverId,
        'status': 'accepted',
        'current_lat': 0,
        'current_lng': 0,
      }).select('id').single();

      // Start background GPS tracking so location updates persist even when
      // the driver navigates away from the tracking screen.
      await BackgroundLocationService.startTracking(
        driverId: driverId,
        deliveryId: deliveryRow['id'] as String,
      );

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept order: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String? get _customerName {
    if ((order.customerName ?? '').isNotEmpty) return order.customerName;
    if ((order.deliveryAddress.recipientName ?? '').isNotEmpty) {
      return order.deliveryAddress.recipientName;
    }
    return null;
  }

  String? get _customerPhone {
    if ((order.customerPhone ?? '').isNotEmpty) return order.customerPhone;
    if ((order.deliveryAddress.phone ?? '').isNotEmpty) {
      return order.deliveryAddress.phone;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = order.deliveryAddress;
    final cname = _customerName;
    final cphone = _customerPhone;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.restaurantName.isNotEmpty
                        ? order.restaurantName
                        : 'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    CurrencyFormatter.formatPrice(order.total),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer (name + tap-to-call)
            if (cname != null || cphone != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.textLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cname ?? AppLocalizations.of(context)!.customer,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (cphone != null)
                    InkWell(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: cphone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              cphone,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Delivery address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address.fullAddress.isNotEmpty
                        ? address.fullAddress
                        : address.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment method
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 18, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  order.paymentMethod,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  'Delivery fee: ${CurrencyFormatter.formatPrice(order.deliveryFee)}',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Accept button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _acceptOrder(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.acceptOrder,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
