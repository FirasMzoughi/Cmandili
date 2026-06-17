import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../providers/audio_alert_provider.dart';
import '../providers/partner_orders_provider.dart';

/// Full-screen modal shown the instant a new 'pending' order arrives.
///
/// Audio is already playing (started by [orderAlertProvider]). This dialog
/// surfaces the order details and gives the partner two actions:
///   • Accepter  → confirmed  + stop audio
///   • Refuser   → confirmation sub-dialog → cancelled + stop audio
///                 (pressing "Non" returns to this dialog)
class IncomingOrderDialog extends ConsumerWidget {
  final Order order;
  const IncomingOrderDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstItem  = order.items.isNotEmpty ? order.items.first : null;
    final imageUrl   = firstItem?.imageUrl ?? '';
    final extra      = order.items.length - 1;
    final orderTitle = firstItem == null
        ? '#${order.id.substring(0, 8).toUpperCase()}'
        : extra > 0
            ? '${firstItem.displayName} + $extra item(s)'
            : firstItem.displayName;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              children: [
                // Pulsing bell icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '🔔 Nouvelle commande !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Order details ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              children: [
                // Item thumbnail + title
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.primary.withOpacity(0.08),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _fallback(),
                              )
                            : _fallback(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.items.length} article(s)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Summary rows
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Total',
                  value: '${order.total.toStringAsFixed(2)} DT',
                  valueColor: AppColors.primary,
                  bold: true,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.payment_rounded,
                  label: 'Paiement',
                  value: order.paymentMethod == 'cash'
                      ? 'Espèces à la livraison'
                      : order.paymentMethod,
                ),
                if (order.customerName?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Client',
                    value: order.customerName!,
                  ),
                ],
                if (order.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: order.notes!,
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(
              children: [
                // Refuser
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _onReject(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Refuser',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accepter
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _onAccept(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '✓  Accepter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onAccept(BuildContext context, WidgetRef ref) async {
    // Stop audio immediately — don't wait for the stream update.
    await ref.read(audioAlertServiceProvider).stopAlert();
    try {
      await ref
          .read(partnerOrderRepositoryProvider)
          .updateOrderStatus(order.id, OrderStatus.confirmed);
    } catch (_) {}
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onReject(BuildContext context, WidgetRef ref) async {
    // Show confirmation sub-dialog. "Non" closes it and returns here.
    // "Oui" cancels the order and closes both dialogs.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Refuser la commande ?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir refuser cette commande ?\n'
          'Cette action est irréversible.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Non → returns false → stay on main dialog
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Non', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          // Oui → returns true → cancel order + close both
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Oui, refuser',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(audioAlertServiceProvider).stopAlert();
      try {
        await ref
            .read(partnerOrderRepositoryProvider)
            .updateOrderStatus(order.id, OrderStatus.cancelled);
      } catch (_) {}
      if (context.mounted) Navigator.of(context).pop();
    }
    // confirmed == false → sub-dialog closed, main dialog stays open.
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _fallback() => Container(
        color: AppColors.primary.withOpacity(0.08),
        child: const Icon(
          Icons.shopping_bag_rounded,
          color: AppColors.primary,
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
