import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order.dart';
import 'partner_orders_provider.dart';

// Real-time stream of a single order, used by the order tracking screen.
final orderStreamProvider = StreamProvider.family<Order, String>((ref, orderId) {
  final repository = ref.watch(partnerOrderRepositoryProvider);
  return repository.streamOrder(orderId);
});
