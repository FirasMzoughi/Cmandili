import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';

final _supabase = Supabase.instance.client;

// Provider that resolves the current driver's UUID from the drivers table.
// Online/offline state is now managed explicitly by the driver via
// driverOnlineProvider — this resolver no longer flips is_online on its own,
// so opening the app does not silently override the driver's chosen state.
final currentDriverIdProvider = FutureProvider<String?>((ref) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final existing = await _supabase
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    // Create driver record on first use, default to offline.
    final created = await _supabase
        .from('drivers')
        .insert({'user_id': userId, 'is_online': false})
        .select('id')
        .single();
    return created['id'] as String;
  } catch (e) {
    debugPrint('Error getting/creating driver record: $e');
    return null;
  }
});

// Stream of available orders (pending or ready, unassigned).
//
// Uses the realtime stream on `orders` (the view can't be subscribed to via
// realtime), then enriches with customer info from a one-shot read of
// orders_with_customer keyed by id. Cheaper than joining profiles in Dart on
// every event.
final availableOrdersProvider = StreamProvider<List<Order>>((ref) async* {
  await for (final rows in _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)) {
    // Only offer orders the restaurant has marked 'ready' (food cooked) and
    // that no driver has claimed yet. 'pending' was previously included, which
    // let a driver grab an order before the restaurant even accepted it.
    final available = rows
        .where((row) =>
            row['status'] == 'ready' && row['driver_id'] == null)
        .toList();
    if (available.isEmpty) {
      yield <Order>[];
      continue;
    }
    final ids = available.map((r) => r['id'] as String).toList();
    Map<String, Map<String, dynamic>> byId = {};
    try {
      final enriched = await _supabase
          .from('orders_with_customer')
          .select('id, customer_name, customer_phone')
          .inFilter('id', ids);
      byId = {
        for (final row in (enriched as List).cast<Map<String, dynamic>>())
          row['id'] as String: row,
      };
    } catch (_) {
      // RLS or migration not yet applied — fall through with empty map.
    }
    yield available.map((row) {
      final extra = byId[row['id']];
      final mapped = _mapOrderRow(row);
      mapped['customerName'] = extra?['customer_name'];
      mapped['customerPhone'] = extra?['customer_phone'];
      return Order.fromJson(mapped);
    }).toList();
  }
});

// Stream of the driver's currently active delivery
final activeDeliveryProvider = StreamProvider<Order?>((ref) async* {
  final driverId = await ref.watch(currentDriverIdProvider.future);
  if (driverId == null) {
    yield null;
    return;
  }

  yield* _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) {
        final active = rows.where((row) =>
            row['driver_id'] == driverId &&
            row['status'] != 'delivered' &&
            row['status'] != 'cancelled');
        if (active.isEmpty) return null;
        return Order.fromJson(_mapOrderRow(active.first));
      });
});

// Stream completed deliveries for this driver
final driverDeliveryHistoryProvider = FutureProvider<List<Order>>((ref) async {
  final driverIdAsync = await ref.watch(currentDriverIdProvider.future);
  if (driverIdAsync == null) return [];

  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await _supabase
      .from('orders')
      .select('*, restaurants(name)')
      .eq('driver_id', driverIdAsync)
      .eq('status', 'delivered')
      .order('created_at', ascending: false);

  return (rows as List)
      .map((row) => Order.fromJson(_mapOrderRow(row)))
      .toList();
});

Map<String, dynamic> _mapOrderRow(Map<String, dynamic> row) {
  String restaurantName = '';
  if (row['restaurants'] is Map) {
    restaurantName = (row['restaurants'] as Map)['name'] ?? '';
  }

  Map<String, dynamic> deliveryAddress = {};
  if (row['delivery_address'] is Map) {
    deliveryAddress = Map<String, dynamic>.from(row['delivery_address'] as Map);
  }

  return {
    'id': row['id'] ?? '',
    'userId': row['user_id'] ?? '',
    'restaurantId': row['restaurant_id'] ?? '',
    'restaurantName': restaurantName,
    'items': [],
    'deliveryAddress': deliveryAddress,
    'subtotal': (row['subtotal'] ?? 0).toDouble(),
    'deliveryFee': (row['delivery_fee'] ?? 0).toDouble(),
    'total': (row['total'] ?? 0).toDouble(),
    'status': row['status'] ?? 'pending',
    'createdAt': row['created_at'] ?? DateTime.now().toIso8601String(),
    'estimatedDeliveryTime': row['estimated_delivery_time'],
    'driverId': row['driver_id'],
    'driverName': null,
    'driverPhone': null,
    'driverLatitude': null,
    'driverLongitude': null,
    'paymentMethod': row['payment_method'] ?? 'cash',
    'notes': row['notes'],
    'type': row['order_type'] ?? 'food',
    'pickupAddress': row['pickup_address'],
    'recipientName': row['recipient_name'],
    'recipientPhone': row['recipient_phone'],
    'senderPhone': row['sender_phone'],
    'packageDescription': row['package_description'],
    'packagePhotoUrl': row['package_photo_url'],
    'isRecipientAccepted': false,
    'billType': row['bill_type'],
    'billReference': row['bill_reference'],
    'billAmount': row['bill_amount'] != null ? (row['bill_amount'] as num).toDouble() : null,
    'billPhotoUrl': row['bill_photo_url'],
    'receiptPhotoUrl': row['bill_receipt_url'],
    'customerName': row['customer_name'],
    'customerPhone': row['customer_phone'],
  };
}
