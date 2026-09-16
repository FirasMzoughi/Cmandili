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
    // Item names for food/supermarket orders — .stream() above can't join,
    // so this is a second query merged in by order_id, same pattern as the
    // customer-name enrichment right above.
    Map<String, String?> summaryById = {};
    try {
      final itemRows = await _supabase
          .from('order_items')
          .select('order_id, quantity, food_items(name), grocery_items(name)')
          .inFilter('order_id', ids);
      final byOrder = <String, List<Map<String, dynamic>>>{};
      for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
        byOrder.putIfAbsent(row['order_id'] as String, () => []).add(row);
      }
      summaryById = {
        for (final entry in byOrder.entries)
          entry.key: _buildContentSummary(entry.value),
      };
    } catch (_) {
      // No items (courier/facture orders) or a transient error — the widget
      // falls back to packageDescription/billType for those types anyway.
    }
    yield available.map((row) {
      final extra = byId[row['id']];
      final mapped = _mapOrderRow(row);
      mapped['customerName'] = extra?['customer_name'];
      mapped['customerPhone'] = extra?['customer_phone'];
      mapped['contentSummary'] = summaryById[row['id']];
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

  final orderRows = (rows as List).cast<Map<String, dynamic>>();
  final ids = orderRows.map((r) => r['id'] as String).toList();

  // Item names for food/supermarket orders — same enrichment pattern as
  // availableOrdersProvider: a one-shot query merged in by order_id, since
  // the initial select above can't join order_items either.
  Map<String, String?> summaryById = {};
  if (ids.isNotEmpty) {
    try {
      final itemRows = await _supabase
          .from('order_items')
          .select('order_id, quantity, food_items(name), grocery_items(name)')
          .inFilter('order_id', ids);
      final byOrder = <String, List<Map<String, dynamic>>>{};
      for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
        byOrder.putIfAbsent(row['order_id'] as String, () => []).add(row);
      }
      summaryById = {
        for (final entry in byOrder.entries)
          entry.key: _buildContentSummary(entry.value),
      };
    } catch (_) {
      // No items (courier/facture orders) or a transient error — the widget
      // falls back to packageDescription/billType for those types anyway.
    }
  }

  // Commission/loyalty-subsidy settlements — generate_settlements_on_delivery()
  // only inserts these for cash orders, so an order with no matching row here
  // just gets no breakdown shown (same graceful-fallback shape as the item
  // summary above).
  Map<String, double> commissionByOrder = {};
  Map<String, double> subsidyByOrder = {};
  if (ids.isNotEmpty) {
    try {
      final settlementRows = await _supabase
          .from('settlements')
          .select('related_order_id, type, amount')
          .eq('user_id', userId)
          .eq('entity_type', 'driver')
          .inFilter('related_order_id', ids)
          .inFilter('type', ['commission_deduction', 'loyalty_subsidy']);
      for (final row in (settlementRows as List).cast<Map<String, dynamic>>()) {
        final orderId = row['related_order_id'] as String?;
        if (orderId == null) continue;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (row['type'] == 'commission_deduction') {
          commissionByOrder[orderId] = amount;
        } else if (row['type'] == 'loyalty_subsidy') {
          subsidyByOrder[orderId] = amount;
        }
      }
    } catch (_) {
      // Transient error — falls back to no breakdown for this load.
    }
  }

  return orderRows.map((row) {
    final mapped = _mapOrderRow(row);
    mapped['contentSummary'] = summaryById[row['id']];
    mapped['commissionAmount'] = commissionByOrder[row['id']];
    mapped['loyaltySubsidyAmount'] = subsidyByOrder[row['id']];
    return Order.fromJson(mapped);
  }).toList();
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
    'loyaltyMilestoneType': row['loyalty_milestone_type'],
    'loyaltyDiscountAmount': row['loyalty_discount_amount'],
    'contentSummary': row['content_summary'],
  };
}

/// "Pizza Margherita x2, Coca Cola, et 3 autres" — built from a food/
/// supermarket order's line items. Null for order types with no items
/// table (courier/facture use packageDescription/billType instead).
String? _buildContentSummary(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return null;
  final names = items
      .map((it) {
        final foodItem = it['food_items'] as Map<String, dynamic>?;
        final groceryItem = it['grocery_items'] as Map<String, dynamic>?;
        final name = (foodItem?['name'] ?? groceryItem?['name'] ?? '') as String;
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        return qty > 1 ? '$name x$qty' : name;
      })
      .where((s) => s.isNotEmpty)
      .toList();
  if (names.isEmpty) return null;
  if (names.length <= 2) return names.join(', ');
  final remaining = names.length - 2;
  return '${names.take(2).join(', ')}, et $remaining autre${remaining > 1 ? 's' : ''}';
}
