import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../orders/presentation/partner_orders_screen.dart';
import '../../menu/presentation/menu_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../orders/providers/partner_orders_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/partner_onboarding_screen.dart';
import '../../orders/providers/audio_alert_provider.dart';
import '../../orders/data/models/order.dart';
import '../../orders/presentation/incoming_order_dialog.dart';

// Tracks shop open/closed state, synced to restaurants/supermarkets table.
final _shopOpenProvider = StateNotifierProvider<_ShopOpenNotifier, bool?>((ref) {
  return _ShopOpenNotifier(ref);
});

class _ShopOpenNotifier extends StateNotifier<bool?> {
  final Ref _ref;
  _ShopOpenNotifier(this._ref) : super(null) { _init(); }

  Future<void> _init() async {
    final profile = await _ref.read(partnerProfileProvider.future);
    if (profile == null) return;
    final table = profile.partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';
    try {
      final row = await Supabase.instance.client
          .from(table).select('is_open').eq('id', profile.entityId).single();
      if (mounted) state = row['is_open'] as bool? ?? true;
    } catch (_) {}
  }

  Future<void> toggle(String entityId, String partnerType) async {
    final next = !(state ?? true);
    state = next;
    final table = partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';
    await Supabase.instance.client
        .from(table).update({'is_open': next}).eq('id', entityId);
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  /// IDs of pending orders for which a dialog has already been shown this
  /// session. Prevents the same order from triggering multiple dialogs if
  /// the stream emits it again (e.g. on reconnect).
  final Set<String> _shownPendingIds = {};

  final List<Widget> _tabs = const [
    _DashboardTab(),
    PartnerOrdersScreen(),
    MenuScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  /// Shows the incoming-order dialog for [order] after the current frame so
  /// it never interrupts an ongoing build pass.
  void _showIncomingOrderDialog(Order order) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, // partner must explicitly accept or reject
        builder: (_) => IncomingOrderDialog(order: order),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(partnerProfileProvider);
    final l = AppLocalizations.of(context)!;

    // Démarre l'écoute globale pour les alertes sonores de nouvelles commandes
    ref.listen(orderAlertProvider, (_, __) {});

    // Detect new pending orders and show the incoming-order dialog once per
    // order ID. addPostFrameCallback ensures the dialog is shown safely after
    // the current build completes, even if the stream emits during a rebuild.
    ref.listen<AsyncValue<List<Order>>>(partnerOrdersStreamProvider,
        (_, next) {
      next.whenData((orders) {
        for (final order in orders) {
          if (order.status == OrderStatus.pending &&
              !_shownPendingIds.contains(order.id)) {
            _shownPendingIds.add(order.id);
            _showIncomingOrderDialog(order);
          }
        }
      });
    });

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading profile: $err'))),
      data: (profile) {
        if (profile == null) {
          return const PartnerOnboardingScreen();
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _tabs,
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, l.dashboard),
                  _buildNavItem(1, Icons.receipt_long_rounded, l.orders),
                  _buildNavItem(2, Icons.restaurant_menu_rounded, l.menu),
                  _buildNavItem(3, Icons.insights_rounded, l.reports),
                  _buildNavItem(4, Icons.person_rounded, l.profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final ordersAsync = ref.watch(partnerOrdersStreamProvider);
    final profileAsync = ref.watch(partnerProfileProvider);
    final l = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: MediaQuery.of(context).size.height * 0.24,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.partnerDashboard,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              profileAsync.when(
                                data: (profile) => Text(
                                  profile?.businessName ?? 'Cmandili Partner',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                                loading: () => const SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(color: Colors.white54),
                                ),
                                error: (_, __) => Text(
                                  'Cmandili Partner',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      statsAsync.when(
                        data: (stats) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.revenueToday,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${(double.tryParse(stats['revenue']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)} DT',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      l.orders,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${stats['orderCount'] ?? 0}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        loading: () => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(l.couldNotLoadStats, style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildQuickStatCard(
                      icon: Icons.timer_rounded,
                      label: l.avgPrep,
                      value: statsAsync.when(
                        data: (s) => '${s['avgPrepTime'] ?? '--'} min',
                        loading: () => '-- min',
                        error: (_, __) => '-- min',
                      ),
                      color: AppColors.accent,
                    )),
                    const SizedBox(width: 14),
                    Expanded(child: _buildQuickStatCard(
                      icon: Icons.star_rounded,
                      label: l.rating,
                      value: statsAsync.when(
                        data: (s) => '${s['rating'] ?? '--'}',
                        loading: () => '--',
                        error: (_, __) => '--',
                      ),
                      color: AppColors.star,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Shop open/closed toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: profileAsync.when(
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();
                final isOpen = ref.watch(_shopOpenProvider);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isOpen ?? true) ? Colors.green.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isOpen ?? true) ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isOpen ?? true) ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (isOpen ?? true) ? l.shopOpen : l.shopClosed,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: (isOpen ?? true) ? Colors.green.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: isOpen ?? true,
                        activeColor: Colors.green,
                        onChanged: (_) => ref.read(_shopOpenProvider.notifier).toggle(profile.entityId, profile.partnerType),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.activeOrders,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => (context.findAncestorStateOfType<_HomeScreenState>()?._selectedIndex = 1),
                  child: Text(l.seeAll),
                ),
              ],
            ),
          ),
        ),
        ordersAsync.when(
          data: (orders) {
            final active = orders.where((o) =>
                o.status.index < 5).toList();
            if (active.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textLight),
                        const SizedBox(height: 8),
                        Text(
                          l.noActiveOrders,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = active[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildOrderCard(context, ref, order),
                  );
                },
                childCount: active.length > 3 ? 3 : active.length,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          ),
          error: (_, __) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('Could not load orders', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.quickActions,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final actions = [
                        {'label': l.newMenu, 'icon': Icons.restaurant_menu_rounded, 'color': AppColors.primary, 'tab': 2},
                        {'label': l.promos, 'icon': Icons.local_offer_rounded, 'color': AppColors.secondary, 'tab': 2},
                        {'label': l.reports, 'icon': Icons.insights_rounded, 'color': AppColors.info, 'tab': 3},
                        {'label': l.orders, 'icon': Icons.receipt_long_rounded, 'color': AppColors.accent, 'tab': 1},
                      ];
                      final action = actions[index];
                      return GestureDetector(
                        onTap: () {
                          final state = context.findAncestorStateOfType<_HomeScreenState>();
                          if (state != null) {
                            state.setState(() => state._selectedIndex = action['tab'] as int);
                          }
                        },
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (action['color'] as Color).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  action['icon'] as IconData,
                                  color: action['color'] as Color,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                action['label'] as String,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, dynamic order) {
    final typedOrder = order as Order;
    final statusColor = _statusColor(order.status);
    final isPending = order.status == OrderStatus.pending;

    // ── First-item thumbnail ──────────────────────────────────────────────
    final firstItem = typedOrder.items.isNotEmpty ? typedOrder.items.first : null;
    final imageUrl = firstItem?.imageUrl ?? '';

    // ── Order title: first item name + overflow count ─────────────────────
    final String orderTitle;
    if (firstItem == null) {
      orderTitle = '#${order.id.substring(0, 8).toUpperCase()}';
    } else {
      final extra = typedOrder.items.length - 1;
      orderTitle = extra > 0
          ? '${firstItem.displayName} + $extra item(s)'
          : firstItem.displayName;
    }

    return Container(
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
          // ── Item thumbnail (52×52) with shopping-bag fallback ──────────
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${typedOrder.items.length} item(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.total.toStringAsFixed(2)} DT',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.getStatusText(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
      if (isPending) ...[
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showRejectDialog(context, ref, order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await ref.read(audioAlertServiceProvider).stopAlert();
                  ref.read(partnerOrderRepositoryProvider).updateOrderStatus(order.id, OrderStatus.confirmed);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text('Accepter'),
              ),
            ),
          ],
        ),
      ],
    ],
  ),
);
  }

  /// Fallback widget shown when an item has no image or the URL fails to load.
  Widget _itemFallback(Color statusColor) {
    return Container(
      color: statusColor.withOpacity(0.12),
      child: Icon(Icons.shopping_bag_rounded, color: statusColor),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, dynamic order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: const Text('Êtes-vous sûr de vouloir refuser cette commande ? Cette action est irréversible.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(partnerOrderRepositoryProvider).updateOrderStatus(order.id, OrderStatus.cancelled);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sûr de refuser'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'ready':
        return AppColors.success;
      case 'preparing':
        return AppColors.warning;
      case 'pending':
        return AppColors.primary;
      case 'confirmed':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}
