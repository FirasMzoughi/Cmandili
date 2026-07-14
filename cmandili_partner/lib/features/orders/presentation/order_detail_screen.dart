import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../providers/partner_orders_provider.dart';
import 'widgets/voice_note_player.dart';

// State provider to handle the self-delivery confirmation loading state.
// Scoped per order-detail screen instance via order ID.
final _selfDeliveryLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

class OrderDetailScreen extends ConsumerWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(order.status);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('#${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(order.status), color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.getStatusText(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_formatDateTime(order.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
                  TextButton(
                    onPressed: () => _showStatusSheet(context, ref),
                    child: Text(l.update),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Customer
          _CustomerSection(order: order),

          const SizedBox(height: 12),

          // Delivery address
          _Section(
            title: l.deliveryAddress,
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.deliveryAddress.fullAddress.isNotEmpty
                        ? order.deliveryAddress.fullAddress
                        : order.deliveryAddress.label,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment
          _Section(
            title: l.payment,
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text(order.paymentMethod, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Text(
                  '${order.total.toStringAsFixed(2)} DT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary),
                ),
              ],
            ),
          ),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: l.customerNotes,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(order.notes!, style: const TextStyle(color: Colors.orange, fontSize: 14))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Order items with customizations
          _Section(
            title: '${l.items} (${order.items.length})',
            child: Column(
              children: order.items.map((item) => _ItemRow(item: item)).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Price breakdown
          _Section(
            title: l.priceBreakdown,
            child: Column(
              children: [
                _PriceRow(label: 'Subtotal', value: order.subtotal),
                const SizedBox(height: 8),
                _PriceRow(label: l.deliveryFee, value: order.deliveryFee),
                const Divider(height: 20),
                _PriceRow(label: l.total, value: order.total, isBold: true),
              ],
            ),
          ),

          if (order.driverId != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: l.driver,
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(order.driverName ?? l.assigned, style: const TextStyle(fontSize: 15)),
                  if (order.driverPhone != null) ...[
                    const Spacer(),
                    Text(order.driverPhone!, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Self-delivery banner: shown when the waterfall failed and the
          // partner hasn't committed to self-delivery yet.
          if (_showSelfDeliveryBanner(order))
            _SelfDeliveryBanner(order: order),

          if (_showSelfDeliveryBanner(order)) const SizedBox(height: 12),

          // Action buttons for non-final statuses
          if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _showStatusSheet(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l.updateOrderStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  bool _showSelfDeliveryBanner(Order o) {
    // Show the banner when:
    //  - The DB has recorded that all drivers were exhausted (no_driver_notified_at set)
    //  - The partner hasn't chosen self-delivery yet
    //  - No driver has accepted the order
    //  - The order is still awaiting delivery (ready or confirmed)
    return o.noDriverNotifiedAt != null &&
        !o.selfDelivery &&
        o.driverId == null &&
        (o.status == OrderStatus.ready || o.status == OrderStatus.confirmed);
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    final nextStatuses = _nextStatuses(order.status);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(ctx)!.updateOrderStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...nextStatuses.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _statusColor(s).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(_statusIcon(s), color: _statusColor(s), size: 20),
              ),
              title: Text(_statusLabel(s, ctx), style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(partnerOrderRepositoryProvider).updateOrderStatus(order.id, s);
                  if (context.mounted) Navigator.pop(context);
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
      case OrderStatus.pending: return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed: return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing: return [OrderStatus.ready];
      case OrderStatus.ready: return [OrderStatus.pickedUp, OrderStatus.onTheWay];
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay: return [OrderStatus.delivered];
      default: return [];
    }
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return AppColors.primary;
      case OrderStatus.confirmed: return AppColors.info;
      case OrderStatus.preparing: return AppColors.warning;
      case OrderStatus.ready: return AppColors.accent;
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay: return AppColors.secondary;
      case OrderStatus.delivered: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
    }
  }

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return Icons.hourglass_empty_rounded;
      case OrderStatus.confirmed: return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing: return Icons.restaurant_rounded;
      case OrderStatus.ready: return Icons.done_all_rounded;
      case OrderStatus.pickedUp: return Icons.directions_bike_rounded;
      case OrderStatus.onTheWay: return Icons.delivery_dining_rounded;
      case OrderStatus.delivered: return Icons.home_rounded;
      case OrderStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  String _statusLabel(OrderStatus s, BuildContext context) {
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item; // CartItem
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasText = (item.specialInstructions as String?)?.isNotEmpty ?? false;
    final hasVoice = (item.voiceNoteContent as String?)?.isNotEmpty ?? false;
    final duration = item.voiceNoteDurationSeconds as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}× ${item.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                '${item.totalPrice.toStringAsFixed(2)} DT',
                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (hasText) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.specialInstructions as String,
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          if (hasVoice) ...[
            const SizedBox(height: 6),
            Builder(builder: (_) {
              final url = item.voiceNoteContent as String;
              // Only render the player for HTTP URLs (uploaded clips). Older
              // orders may still hold a local file path that the partner can't
              // play; show the static badge for those.
              if (url.startsWith('http')) {
                return VoiceNotePlayer(url: url, durationSeconds: duration);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      duration != null ? 'Voice note (${duration}s)' : 'Voice note',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (item != (context.findAncestorWidgetOfExactType<Column>()?.children.last))
            const Divider(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CustomerSection extends StatelessWidget {
  final Order order;
  const _CustomerSection({required this.order});

  String? get _name {
    if ((order.customerName ?? '').isNotEmpty) return order.customerName;
    if ((order.deliveryAddress.recipientName ?? '').isNotEmpty) {
      return order.deliveryAddress.recipientName;
    }
    return null;
  }

  String? get _phone {
    if ((order.customerPhone ?? '').isNotEmpty) return order.customerPhone;
    if ((order.deliveryAddress.phone ?? '').isNotEmpty) {
      return order.deliveryAddress.phone;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = _name ?? l.customer;
    final phone = _phone;
    return _Section(
      title: l.customer,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (phone != null) ...[
                  const SizedBox(height: 2),
                  Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              tooltip: l.callCustomer,
              icon: const Icon(Icons.phone, color: AppColors.success),
              onPressed: () async {
                final uri = Uri(scheme: 'tel', path: phone);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── Self-delivery banner ──────────────────────────────────────────────────────

class _SelfDeliveryBanner extends ConsumerWidget {
  final Order order;
  const _SelfDeliveryBanner({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(_selfDeliveryLoadingProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucun livreur disponible',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Voulez-vous livrer cette commande vous-même ?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _onConfirmSelfDelivery(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.orange.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Je livre cette commande',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirmSelfDelivery(BuildContext context, WidgetRef ref) async {
    ref.read(_selfDeliveryLoadingProvider.notifier).state = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(partnerOrderRepositoryProvider).confirmSelfDelivery(order.id);
      // The realtime subscription on orders will update the UI automatically.
      // Status is now 'on_the_way' — partner uses the existing mark-delivered flow.
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Vous êtes maintenant en livraison. Marquez la commande comme livrée une fois remise.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (context.mounted) {
        ref.read(_selfDeliveryLoadingProvider.notifier).state = false;
      }
    }
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  const _PriceRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.textPrimary : AppColors.textSecondary)),
        Text('${value.toStringAsFixed(2)} DT', style: TextStyle(fontSize: isBold ? 17 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}
