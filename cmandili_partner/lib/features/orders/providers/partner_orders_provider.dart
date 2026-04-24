import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/partner_order_repository.dart';
import '../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';

final partnerOrderRepositoryProvider = Provider<PartnerOrderRepository>((ref) {
  return PartnerOrderRepository();
});

final partnerOrdersStreamProvider = StreamProvider<List<Order>>((ref) {
  final profileAsync = ref.watch(partnerProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile == null) return Stream.value([]);
      return ref
          .read(partnerOrderRepositoryProvider)
          .streamPartnerOrders(profile.entityId, profile.partnerType);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final profile = await ref.watch(partnerProfileProvider.future);
  if (profile == null) return {'orderCount': 0, 'revenue': '0.00'};
  return ref
      .read(partnerOrderRepositoryProvider)
      .getDashboardStats(profile.entityId, profile.partnerType);
});
