import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_repository.dart';
import '../data/models/order.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());

// Stream provider for tracking a specific order
final orderStreamProvider = StreamProvider.family<Order, String>((ref, orderId) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.streamOrder(orderId);
});

// Future provider for fetching user orders history
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getUserOrders();
});
