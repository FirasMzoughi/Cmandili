import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

final _reportsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final profile = await ref.watch(partnerProfileProvider.future);
  if (profile == null) return _emptyStats();

  final filterColumn = profile.partnerType == 'restaurant' ? 'restaurant_id' : 'supermarket_id';

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

  try {
    final client = Supabase.instance.client;
    final rows = await client
        .from('orders')
        .select('total, delivery_fee, status, created_at')
        .eq(filterColumn, profile.entityId)
        .gte('created_at', start.toIso8601String());

    final all = rows as List;
    final delivered = all.where((r) => r['status'] == 'delivered').toList();
    final cancelled = all.where((r) => r['status'] == 'cancelled').toList();

    final totalRevenue = delivered.fold<double>(0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
    final totalFees = delivered.fold<double>(0, (s, r) => s + ((r['delivery_fee'] as num?)?.toDouble() ?? 0));

    return {
      'totalOrders': all.length,
      'deliveredOrders': delivered.length,
      'cancelledOrders': cancelled.length,
      'totalRevenue': totalRevenue,
      'deliveryFees': totalFees,
    };
  } catch (e, st) {
    return Error.throwWithStackTrace(
      Exception('Failed to load reports: $e'),
      st,
    );
  }
});

Map<String, dynamic> _emptyStats() => {
  'totalOrders': 0,
  'deliveredOrders': 0,
  'cancelledOrders': 0,
  'totalRevenue': 0.0,
  'deliveryFees': 0.0,
};

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'today';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_reportsProvider(_period));
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.reportsAnalytics, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Period selector
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                _PeriodTab(label: l.today, value: 'today', selected: _period, onTap: (v) => setState(() => _period = v)),
                _PeriodTab(label: l.thisWeek, value: 'week', selected: _period, onTap: (v) => setState(() => _period = v)),
                _PeriodTab(label: l.thisMonth, value: 'month', selected: _period, onTap: (v) => setState(() => _period = v)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          statsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(l.couldNotLoadReports, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(_reportsProvider(_period)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (stats) => Column(
              children: [
                // Revenue card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.totalRevenue, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${(stats['totalRevenue'] as double).toStringAsFixed(2)} DT',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Delivery fees: ${(stats['deliveryFees'] as double).toStringAsFixed(2)} DT',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats grid
                Row(
                  children: [
                    Expanded(child: _StatCard(label: l.totalOrders, value: '${stats['totalOrders']}', icon: Icons.receipt_long_rounded, color: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: l.delivered, value: '${stats['deliveredOrders']}', icon: Icons.check_circle_rounded, color: AppColors.success)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatCard(label: l.cancelled, value: '${stats['cancelledOrders']}', icon: Icons.cancel_rounded, color: AppColors.error)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(
                      label: l.successRate,
                      value: stats['totalOrders'] > 0
                          ? '${((stats['deliveredOrders'] / stats['totalOrders']) * 100).toStringAsFixed(0)}%'
                          : '—',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.secondary,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _PeriodTab({required this.label, required this.value, required this.selected, required this.onTap});

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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
