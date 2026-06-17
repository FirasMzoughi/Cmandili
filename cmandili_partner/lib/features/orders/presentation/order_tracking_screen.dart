import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_map.dart';
import '../data/models/order.dart';
import '../providers/order_provider.dart';
import '../providers/partner_orders_provider.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final Order order;

  const OrderTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final AppMapController _mapController = AppMapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _confirmReceipt(Order currentOrder) async {
    await ref
        .read(partnerOrderRepositoryProvider)
        .updateOrderStatus(currentOrder.id, OrderStatus.delivered);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.recipientConfirmed),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time order updates from Supabase; fall back to initial order.
    final orderAsync = ref.watch(orderStreamProvider(widget.order.id));
    final currentOrder = orderAsync.valueOrNull ?? widget.order;
    final isCourier = currentOrder.type == OrderType.courier;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          // Map — shown when driver location is available
          if (currentOrder.status == OrderStatus.onTheWay &&
              currentOrder.driverLatitude != null)
            AppMap(
              controller: _mapController,
              initialLatitude: currentOrder.deliveryAddress.latitude,
              initialLongitude: currentOrder.deliveryAddress.longitude,
              initialZoom: 14,
              markers: {
                AppMapMarker(
                  id: 'delivery',
                  latitude: currentOrder.deliveryAddress.latitude,
                  longitude: currentOrder.deliveryAddress.longitude,
                  kind: AppMapMarkerKind.delivery,
                  title: 'Delivery Location',
                ),
                if (isCourier && currentOrder.pickupAddress != null)
                  AppMapMarker(
                    id: 'pickup',
                    latitude: currentOrder.pickupAddress!.latitude,
                    longitude: currentOrder.pickupAddress!.longitude,
                    kind: AppMapMarkerKind.pickup,
                    title: 'Pickup Location',
                  ),
                AppMapMarker(
                  id: 'driver',
                  latitude: currentOrder.driverLatitude!,
                  longitude: currentOrder.driverLongitude!,
                  kind: AppMapMarkerKind.driver,
                  title: currentOrder.driverName ?? 'Driver',
                ),
              },
            )
          else
            Container(
              color: AppColors.background,
              child: Center(
                child: Icon(
                  isCourier ? Icons.local_shipping : Icons.restaurant,
                  size: 100,
                  color: AppColors.textLight.withValues(alpha: 0.3),
                ),
              ),
            ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Order Status
                    Text(
                      currentOrder.getStatusText(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (currentOrder.estimatedDeliveryTime != null)
                      Text(
                        'Estimated delivery: ${_formatTime(currentOrder.estimatedDeliveryTime!)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Recipient confirmation button (courier orders)
                    if (isCourier &&
                        currentOrder.status == OrderStatus.onTheWay &&
                        !currentOrder.isRecipientAccepted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmReceipt(currentOrder),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(l.confirmRecipientAccepted),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    if (currentOrder.isRecipientAccepted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.recipientAccepted,
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Status Timeline
                    _OrderTimeline(
                      status: currentOrder.status,
                      isCourier: isCourier,
                    ),

                    const SizedBox(height: 24),

                    // Driver Info
                    if ((currentOrder.status == OrderStatus.onTheWay ||
                            currentOrder.status == OrderStatus.pickedUp) &&
                        currentOrder.driverName != null) ...[
                      Text(
                        l.yourCourier,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.primary,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentOrder.driverName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    currentOrder.driverPhone ?? '',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _callPhone(context, currentOrder.driverPhone),
                              icon: const Icon(
                                Icons.phone,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Order Details
                    Text(
                      isCourier ? l.packageDetails : l.orderDetailsHeader,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (isCourier) ...[
                      _DetailRow(
                          label: l.recipient,
                          value: currentOrder.recipientName ?? 'N/A'),
                      _DetailRow(
                          label: l.phone,
                          value: currentOrder.recipientPhone ?? 'N/A'),
                      _DetailRow(
                          label: l.item,
                          value:
                              currentOrder.packageDescription ?? l.package),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        currentOrder.restaurantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...currentOrder.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.quantity}x ${item.name}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPrice(item.totalPrice),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    const Divider(height: 24),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.total,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPrice(currentOrder.total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Payment Method
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentOrder.paymentMethod,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    final number = phone?.trim();
    if (number == null || number.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.driverPhoneNotAvailable)),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unableToStartCall)),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final OrderStatus status;
  final bool isCourier;

  const _OrderTimeline({
    required this.status,
    this.isCourier = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = isCourier
        ? [
            _TimelineStep(
              title: 'Request Confirmed',
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: 'Picked Up',
              isCompleted: status.index >= OrderStatus.pickedUp.index,
              icon: Icons.inventory_2,
            ),
            _TimelineStep(
              title: 'On the Way',
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.local_shipping,
            ),
            _TimelineStep(
              title: 'Delivered',
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ]
        : [
            _TimelineStep(
              title: 'Order Confirmed',
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: 'Preparing',
              isCompleted: status.index >= OrderStatus.preparing.index,
              icon: Icons.restaurant,
            ),
            _TimelineStep(
              title: 'On the Way',
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.delivery_dining,
            ),
            _TimelineStep(
              title: 'Delivered',
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ];

    return Column(
      children: List.generate(
        steps.length,
        (index) => _TimelineItem(
          step: steps[index],
          isLast: index == steps.length - 1,
        ),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final bool isCompleted;
  final IconData icon;

  _TimelineStep({
    required this.title,
    required this.isCompleted,
    required this.icon,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineItem({
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    step.isCompleted ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.isCompleted
                      ? AppColors.primary
                      : AppColors.textLight,
                  width: 2,
                ),
              ),
              child: Icon(
                step.icon,
                color: step.isCompleted ? Colors.white : AppColors.textLight,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted
                    ? AppColors.primary
                    : AppColors.textLight.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            step.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  step.isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: step.isCompleted
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
