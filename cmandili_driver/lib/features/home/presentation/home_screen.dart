import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/presentation/available_orders_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../orders/providers/driver_orders_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../earnings/presentation/earnings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeDeliveryAsync = ref.watch(activeDeliveryProvider);

    final pages = [
      _DashboardTab(onGoToOrders: () => setState(() => _selectedIndex = 1)),
      const AvailableOrdersScreen(),
      // Active delivery tab: show tracking if active, else placeholder
      activeDeliveryAsync.when(
        data: (order) => order != null
            ? OrderTrackingScreen(orderId: order.id)
            : _NoActiveDelivery(onBrowse: () => setState(() => _selectedIndex = 1)),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => _NoActiveDelivery(onBrowse: () => setState(() => _selectedIndex = 1)),
      ),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(index: 0, icon: Icons.dashboard_rounded, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
              _NavItem(index: 1, icon: Icons.delivery_dining_rounded, label: 'Orders', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
              _NavItem(index: 2, icon: Icons.navigation_rounded, label: 'Active', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              _NavItem(index: 3, icon: Icons.account_balance_wallet_rounded, label: 'Earnings', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
              _NavItem(index: 4, icon: Icons.person_rounded, label: 'Profile', selected: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.index, required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
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
  final VoidCallback onGoToOrders;
  const _DashboardTab({required this.onGoToOrders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeDeliveryProvider);
    final availableAsync = ref.watch(availableOrdersProvider);

    final availableCount = availableAsync.value?.length ?? 0;
    final hasActive = activeAsync.value != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Dashboard',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasActive ? 'You have an active delivery' : 'Ready for orders',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _HeaderStat(label: 'Available', value: '$availableCount'),
                            const SizedBox(width: 1),
                            Container(width: 1, height: 32, color: Colors.white24),
                            const SizedBox(width: 1),
                            _HeaderStat(label: 'Active', value: hasActive ? '1' : '0'),
                          ],
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasActive) ...[
                    Text('Active Delivery', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _ActiveDeliveryCard(order: activeAsync.value!),
                    const SizedBox(height: 24),
                  ],

                  Text('Available Orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$availableCount order(s) waiting for a driver', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onGoToOrders,
                      icon: const Icon(Icons.delivery_dining_rounded),
                      label: const Text('View Available Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final dynamic order;
  const _ActiveDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.id.toString().substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryAddress?.fullAddress ?? order.deliveryAddress?.label ?? '',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('On the Way', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _NoActiveDelivery extends StatelessWidget {
  final VoidCallback onBrowse;
  const _NoActiveDelivery({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: AppColors.textLight),
            const SizedBox(height: 16),
            const Text('No active delivery', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Accept an order to start delivering', style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onBrowse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Browse Available Orders'),
            ),
          ],
        ),
      ),
    );
  }
}
