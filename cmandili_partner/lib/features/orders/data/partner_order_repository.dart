import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';

class PartnerOrderRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch all orders for a partner, with items joined.
  ///
  /// Reads from the `orders_with_customer` view so each row already contains
  /// the resolved `customer_name` + `customer_phone` (delivery_address →
  /// profiles → recipient_* fallback chain) without a second round-trip.
  Future<List<Order>> getPartnerOrders(
      String entityId, String partnerType) async {
    final filterColumn =
        partnerType == 'restaurant' ? 'restaurant_id' : 'supermarket_id';
    final rows = await _supabase
        .from('orders_with_customer')
        .select('*, order_items(*, food_items(*), grocery_items(*))')
        .eq(filterColumn, entityId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((json) => Order.fromJson(_mapOrderFromDb(json)))
        .toList();
  }

  /// Stream all orders for a given partner entity in real-time.
  ///
  /// Supabase's `.stream()` does not support joins, so we use Postgres Changes
  /// for real-time notifications and re-fetch the full list (with items) on
  /// every change. Re-fetches are debounced and de-duped so a burst of
  /// changes (e.g. a status flip + a driver-assignment) collapse into one
  /// refresh instead of N round-trips with all the join data.
  Stream<List<Order>> streamPartnerOrders(
      String entityId, String partnerType) {
    final controller = StreamController<List<Order>>();
    Timer? debounce;
    bool inFlight = false;
    bool pending = false;

    Future<void> refresh() async {
      if (inFlight) {
        pending = true;
        return;
      }
      inFlight = true;
      try {
        final orders = await getPartnerOrders(entityId, partnerType);
        if (!controller.isClosed) controller.add(orders);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        inFlight = false;
        if (pending) {
          pending = false;
          // Drain anything that arrived while we were fetching.
          unawaited(refresh());
        }
      }
    }

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), refresh);
    }

    // Initial load is immediate (no debounce — user is waiting on first paint).
    unawaited(refresh());

    final filterColumn =
        partnerType == 'restaurant' ? 'restaurant_id' : 'supermarket_id';
    final channel = _supabase
        .channel('partner_orders_$entityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterColumn,
            value: entityId,
          ),
          callback: (_) => scheduleRefresh(),
        )
        .subscribe();

    controller.onCancel = () {
      debounce?.cancel();
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Fetch a single order once by id (with items joined).
  ///
  /// Used by the notification deep-link: when the partner taps an alarm we only
  /// have the order id, so we resolve the full [Order] before pushing the
  /// detail screen. Returns null if the order no longer exists / isn't visible.
  Future<Order?> fetchOrder(String orderId) async {
    final row = await _supabase
        .from('orders_with_customer')
        .select('*, order_items(*, food_items(*), grocery_items(*))')
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return Order.fromJson(_mapOrderFromDb(row));
  }

  /// Stream a single order in real-time for the tracking screen.
  ///
  /// Supabase's `.stream()` can't join, so we listen for Postgres changes on
  /// this order's row and re-fetch the full record (with items) on each change.
  /// The first value is emitted immediately on subscribe.
  Stream<Order> streamOrder(String orderId) {
    final controller = StreamController<Order>();
    bool inFlight = false;

    Future<void> refresh() async {
      if (inFlight) return;
      inFlight = true;
      try {
        final row = await _supabase
            .from('orders_with_customer')
            .select('*, order_items(*, food_items(*), grocery_items(*))')
            .eq('id', orderId)
            .maybeSingle();
        if (row != null && !controller.isClosed) {
          controller.add(Order.fromJson(_mapOrderFromDb(row)));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        inFlight = false;
      }
    }

    unawaited(refresh());

    final channel = _supabase
        .channel('partner_order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Update the status of an order.
  ///
  /// Returns true on success, false on failure. The error is also rethrown so
  /// callers can surface it to the user — a silent `return false` previously
  /// hid trigger failures (e.g. the notifications.message column drift) and
  /// made the UI look frozen.
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase.from('orders').update({
        'status': newStatus.toString().split('.').last,
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  /// Get today's dashboard stats for a partner.
  Future<Map<String, dynamic>> getDashboardStats(
      String entityId, String partnerType) async {
    try {
      final filterColumn =
          partnerType == 'restaurant' ? 'restaurant_id' : 'supermarket_id';
      final todayMidnight = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).toIso8601String();

      // Orders today with prep timestamps
      final ordersResp = await _supabase
          .from('orders')
          .select('total, status, created_at, confirmed_at, ready_at')
          .eq(filterColumn, entityId)
          .gte('created_at', todayMidnight);

      final orders = ordersResp as List;
      final orderCount = orders.length;
      final revenue = orders.fold<double>(
        0.0,
        (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0.0),
      );

      // avgPrepTime: mean of (ready_at - confirmed_at) in minutes for delivered/ready orders
      final prepMinutes = <double>[];
      for (final o in orders) {
        final confirmedStr = o['confirmed_at'] as String?;
        final readyStr = o['ready_at'] as String?;
        if (confirmedStr != null && readyStr != null) {
          final confirmed = DateTime.tryParse(confirmedStr);
          final ready = DateTime.tryParse(readyStr);
          if (confirmed != null && ready != null && ready.isAfter(confirmed)) {
            prepMinutes.add(ready.difference(confirmed).inMinutes.toDouble());
          }
        }
      }
      final avgPrepTime = prepMinutes.isEmpty
          ? '--'
          : '${(prepMinutes.reduce((a, b) => a + b) / prepMinutes.length).round()} min';

      // Rating: average from reviews table for this entity
      String rating = '--';
      try {
        final reviewsResp = await _supabase
            .from('reviews')
            .select('rating')
            .eq('entity_id', entityId);
        final reviews = reviewsResp as List;
        if (reviews.isNotEmpty) {
          final avg = reviews.fold<double>(
                0.0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0.0)) /
              reviews.length;
          rating = avg.toStringAsFixed(1);
        }
      } catch (_) {}

      return {
        'orderCount': orderCount,
        'revenue': revenue.toStringAsFixed(2),
        'avgPrepTime': avgPrepTime,
        'rating': rating,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return {'orderCount': 0, 'revenue': '0.00', 'avgPrepTime': '--', 'rating': '--'};
    }
  }

  Map<String, dynamic> _mapOrderFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'userId': dbJson['user_id'],
      'restaurantId': dbJson['restaurant_id'] ?? '',
      'restaurantName': '',
      'items': _parseOrderItems(dbJson['order_items']),
      'deliveryAddress': dbJson['delivery_address'] ?? {},
      'subtotal': dbJson['subtotal'],
      'deliveryFee': dbJson['delivery_fee'],
      'total': dbJson['total'],
      'status': dbJson['status'],
      'createdAt': dbJson['created_at'],
      'estimatedDeliveryTime': dbJson['estimated_delivery_time'],
      'driverId': dbJson['driver_id'],
      'driverName': null,
      'driverPhone': null,
      'driverLatitude': null,
      'driverLongitude': null,
      'paymentMethod': dbJson['payment_method'],
      'notes': dbJson['notes'],
      'type': dbJson['order_type'],
      'pickupAddress': dbJson['pickup_address'],
      'recipientName': dbJson['recipient_name'],
      'recipientPhone': dbJson['recipient_phone'],
      'packageDescription': dbJson['package_description'],
      'isRecipientAccepted': false,
      'customerName': dbJson['customer_name'],
      'customerPhone': dbJson['customer_phone'],
      'selfDelivery': dbJson['self_delivery'] ?? false,
      'noDriverNotifiedAt': dbJson['no_driver_notified_at'],
    };
  }

  /// Mark an order as partner-self-delivered.
  ///
  /// Sets self_delivery = true and advances status to 'onTheWay' (camelCase —
  /// the only spelling orders_status_check accepts) so the partner can use
  /// the existing "mark as delivered" flow to complete it.
  /// driver_fee_cut will be 0 when the settlement trigger fires on delivery.
  Future<void> confirmSelfDelivery(String orderId) async {
    await _supabase.from('orders').update({
      'self_delivery': true,
      'status': 'onTheWay',
    }).eq('id', orderId);
  }

  /// Parse the nested `order_items` array returned by the join.
  List<Map<String, dynamic>> _parseOrderItems(dynamic rawItems) {
    if (rawItems == null) return [];
    final items = rawItems as List<dynamic>;
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      final row = item as Map<String, dynamic>;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
      final price = (row['price'] as num?)?.toDouble() ?? 0.0;
      final specialInstructions = row['special_instructions'] as String?;
      // options contains voice/text customization set by the mobile client.
      // Prefer the dedicated voice_note_url column when present — it's the
      // public Supabase Storage URL set by the mobile checkout flow. Fall
      // back to legacy options.content for older rows.
      final voiceNoteUrl = row['voice_note_url'] as String?;
      final options = row['options'];
      Map<String, dynamic> mergedOptions = options is Map
          ? Map<String, dynamic>.from(options)
          : <String, dynamic>{};
      if (voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) {
        mergedOptions['type'] = 'voice';
        mergedOptions['content'] = voiceNoteUrl;
      }

      // Food item (restaurant order)
      final foodData = row['food_items'] as Map<String, dynamic>?;
      if (foodData != null) {
        result.add({
          'type': 'restaurant',
          'quantity': quantity,
          'specialInstructions': specialInstructions,
          'options': mergedOptions,
          'foodItem': {
            'id': foodData['id'] ?? '',
            'restaurantId': foodData['restaurant_id'] ?? '',
            'name': foodData['name'] ?? '',
            'description': foodData['description'] ?? '',
            'imageUrl': foodData['image_url'] ?? '',
            'price': price, // use order-time price, not current price
            'category': foodData['category'] ?? '',
            'isAvailable': foodData['is_available'] ?? true,
            'tags': [],
            'preparationTime': foodData['preparation_time'] ?? 15,
            'isVegetarian': foodData['is_vegetarian'] ?? false,
            'isSpicy': foodData['is_spicy'] ?? false,
          },
        });
        continue;
      }

      // Grocery item (supermarket order)
      final groceryData = row['grocery_items'] as Map<String, dynamic>?;
      if (groceryData != null) {
        result.add({
          'type': 'grocery',
          'quantity': quantity,
          'options': mergedOptions,
          'groceryItem': {
            'id': groceryData['id'] ?? '',
            'supermarketId': groceryData['supermarket_id'] ?? '',
            'name': groceryData['name'] ?? '',
            'description': groceryData['description'] ?? '',
            'imageUrl': groceryData['image_url'] ?? '',
            'price': price,
            'category': groceryData['category'] ?? 'vegetables',
            'unit': groceryData['unit'] ?? 'piece',
            'isOrganic': groceryData['is_organic'] ?? false,
            'isAvailable': groceryData['is_available'] ?? true,
          },
        });
        continue;
      }

      // Fallback: item row has name/price directly (no joined relation data)
      if (row['food_item_id'] != null) {
        result.add({
          'type': 'restaurant',
          'quantity': quantity,
          'specialInstructions': specialInstructions,
          'options': mergedOptions,
          'foodItem': {
            'id': row['food_item_id'] ?? '',
            'restaurantId': '',
            'name': row['name'] as String? ?? 'Item',
            'description': '',
            'imageUrl': '',
            'price': price,
            'category': '',
            'isAvailable': true,
            'tags': [],
            'preparationTime': 15,
            'isVegetarian': false,
            'isSpicy': false,
          },
        });
      } else if (row['grocery_item_id'] != null) {
        result.add({
          'type': 'grocery',
          'quantity': quantity,
          'options': mergedOptions,
          'groceryItem': {
            'id': row['grocery_item_id'] ?? '',
            'supermarketId': '',
            'name': row['name'] as String? ?? 'Item',
            'description': '',
            'imageUrl': '',
            'price': price,
            'category': 'vegetables',
            'unit': 'piece',
            'isOrganic': false,
            'isAvailable': true,
          },
        });
      }
    }

    return result;
  }
}
