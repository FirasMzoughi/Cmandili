import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../providers/partner_orders_provider.dart';
import 'order_detail_screen.dart';

class PartnerOrdersScreen extends ConsumerStatefulWidget {
  const PartnerOrdersScreen({super.key});

  @override
  ConsumerState<PartnerOrdersScreen> createState() => _PartnerOrdersScreenState();
}

class _PartnerOrdersScreenState extends ConsumerState<PartnerOrdersScreen> {
  OrderStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(partnerOrdersStreamProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.orders,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.manageOrdersRealtime,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(null, l.all),
                    const SizedBox(width: 8),
                    _buildFilterChip(OrderStatus.pending, l.filterNew),
                    const SizedBox(width: 8),
                    _buildFilterChip(OrderStatus.confirmed, l.confirmedFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(OrderStatus.preparing, l.preparingFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(OrderStatus.ready, l.ready),
                    const SizedBox(width: 8),
                    _buildFilterChip(OrderStatus.delivered, l.delivered),
                  ],
                ),
              ),
            ),
          ),

          // Orders list
          ordersAsync.when(
            data: (orders) {
              final filtered = _filterStatus == null
                  ? orders
                  : orders.where((o) => o.status == _filterStatus).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.noOrdersYet,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.newOrdersAppearHere,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderCard(order: filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  l.couldNotLoadOrders,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(OrderStatus? status, String label) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(order.status);
    // Resolved customer name from orders_with_customer view; fall back to the
    // address label, then a generic placeholder.
    final customerName = (order.customerName?.isNotEmpty ?? false)
        ? order.customerName!
        : (order.deliveryAddress.recipientName?.isNotEmpty ?? false)
            ? order.deliveryAddress.recipientName!
            : (order.deliveryAddress.label.isNotEmpty
                ? order.deliveryAddress.label
                : 'Customer');

    // First item name + overflow count — mirrors the dashboard card logic.
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final imageUrl = firstItem?.imageUrl ?? '';
    final String orderTitle;
    if (firstItem == null) {
      orderTitle = '#${order.id.substring(0, 8).toUpperCase()}';
    } else {
      final extra = order.items.length - 1;
      orderTitle = extra > 0
          ? '${firstItem.displayName} + $extra item(s)'
          : firstItem.displayName;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Item thumbnail with shopping-bag fallback — same as dashboard.
              SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: statusColor.withOpacity(0.08),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _itemFallback(statusColor),
                        )
                      : _itemFallback(statusColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$customerName • ${order.items.isEmpty ? "Order" : "${order.items.length} item(s)"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.getStatusText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${order.total.toStringAsFixed(2)} DT',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
                TextButton.icon(
                  onPressed: () => _showStatusSheet(context, ref),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(AppLocalizations.of(context)!.updateStatus),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _itemFallback(Color statusColor) {
    return Container(
      color: statusColor.withOpacity(0.12),
      child: Icon(Icons.shopping_bag_rounded, color: statusColor),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    final nextStatuses = _nextStatuses(order.status);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(ctx)!.updateOrderStatus,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '#${order.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ...nextStatuses.map((status) => _StatusOption(
                  status: status,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(partnerOrderRepositoryProvider)
                          .updateOrderStatus(order.id, status);
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                          'Order updated to ${status.toString().split('.').last}',
                        ),
                        backgroundColor: AppColors.success,
                      ));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(
                        content: Text('Failed to update order: $e'),
                        backgroundColor: AppColors.error,
                      ));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  List<OrderStatus> _nextStatuses(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready];
      case OrderStatus.ready:
        return [OrderStatus.pickedUp, OrderStatus.onTheWay];
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return [OrderStatus.delivered];
      default:
        return [];
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.primary;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.warning;
      case OrderStatus.ready:
        return AppColors.accent;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return AppColors.secondary;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

class _StatusOption extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onTap;
  const _StatusOption({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = _label(status, context);
    final color = _color(status);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_icon(status), color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _label(OrderStatus s, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (s) {
      case OrderStatus.confirmed: return l.confirmOrder;
      case OrderStatus.preparing: return l.startPreparing;
      case OrderStatus.ready: return l.markAsReady;
      case OrderStatus.pickedUp: return l.pickedUp;
      case OrderStatus.onTheWay: return l.outForDelivery;
      case OrderStatus.delivered: return l.markAsDelivered;
      case OrderStatus.cancelled: return l.cancelOrder;
      default: return s.toString().split('.').last;
    }
  }

  IconData _icon(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed: return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing: return Icons.restaurant_rounded;
      case OrderStatus.ready: return Icons.done_all_rounded;
      case OrderStatus.pickedUp: return Icons.directions_bike_rounded;
      case OrderStatus.onTheWay: return Icons.delivery_dining_rounded;
      case OrderStatus.delivered: return Icons.home_rounded;
      case OrderStatus.cancelled: return Icons.cancel_outlined;
      default: return Icons.circle_outlined;
    }
  }

  Color _color(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed: return AppColors.info;
      case OrderStatus.preparing: return AppColors.warning;
      case OrderStatus.ready: return AppColors.accent;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay: return AppColors.secondary;
      case OrderStatus.delivered: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
      default: return AppColors.primary;
    }
  }
}
