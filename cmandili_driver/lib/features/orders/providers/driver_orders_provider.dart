import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';

final _supabase = Supabase.instance.client;

// Provider that resolves the current driver's UUID from the drivers table.
// Also sets is_online=true on creation/fetch, and registers an AppLifecycleListener
// to set is_online=false when the app is paused or detached.
final currentDriverIdProvider = FutureProvider<String?>((ref) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    String driverId;

    // Try to find existing driver record
    final existing = await _supabase
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      driverId = existing['id'] as String;
      // Mark online
      await _supabase
          .from('drivers')
          .update({'is_online': true})
          .eq('id', driverId);
    } else {
      // Create driver record on first use
      final created = await _supabase
          .from('drivers')
          .insert({'user_id': userId, 'is_online': true})
          .select('id')
          .single();
      driverId = created['id'] as String;
    }

    // Register lifecycle listener to go offline when app is backgrounded/closed
    final observer = _DriverLifecycleObserver(driverId: driverId);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
      // Best-effort offline on provider disposal
      _supabase
          .from('drivers')
          .update({'is_online': false})
          .eq('id', driverId)
          .then((_) {})
          .catchError((_) {});
    });

    return driverId;
  } catch (e) {
    debugPrint('Error getting/creating driver record: $e');
    return null;
  }
});

/// Marks the driver offline when the app goes to background or is closed.
class _DriverLifecycleObserver extends WidgetsBindingObserver {
  final String driverId;

  _DriverLifecycleObserver({required this.driverId});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _supabase
          .from('drivers')
          .update({'is_online': false})
          .eq('id', driverId)
          .then((_) {})
          .catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      _supabase
          .from('drivers')
          .update({'is_online': true})
          .eq('id', driverId)
          .then((_) {})
          .catchError((_) {});
    }
  }
}

// Stream of available orders (pending or ready, unassigned)
final availableOrdersProvider = StreamProvider<List<Order>>((ref) {
  return _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) {
        return rows
            .where((row) =>
                (row['status'] == 'pending' || row['status'] == 'ready') &&
                row['driver_id'] == null)
            .map((row) => Order.fromJson(_mapOrderRow(row)))
            .toList();
      });
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
    'packageDescription': row['package_description'],
    'isRecipientAccepted': false,
  };
}
