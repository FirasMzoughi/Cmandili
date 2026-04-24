import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';

class PartnerOrderRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch all orders for a partner, with items joined.
  Future<List<Order>> getPartnerOrders(
      String entityId, String partnerType) async {
    final filterColumn =
        partnerType == 'restaurant' ? 'restaurant_id' : 'supermarket_id';
    final rows = await _supabase
        .from('orders')
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
  /// every change.
  Stream<List<Order>> streamPartnerOrders(
      String entityId, String partnerType) {
    final controller = StreamController<List<Order>>();

    // Push an initial load immediately.
    getPartnerOrders(entityId, partnerType).then((orders) {
      if (!controller.isClosed) controller.add(orders);
    });

    // Subscribe to any INSERT / UPDATE / DELETE on the orders table for this partner.
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
          callback: (_) {
            // Re-fetch on any change so items are always included.
            getPartnerOrders(entityId, partnerType).then((orders) {
              if (!controller.isClosed) controller.add(orders);
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Update the status of an order.
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase.from('orders').update({
        'status': newStatus.toString().split('.').last,
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
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
    };
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
      // options contains voice/text customization set by the mobile client
      final options = row['options'];

      // Food item (restaurant order)
      final foodData = row['food_items'] as Map<String, dynamic>?;
      if (foodData != null) {
        result.add({
          'type': 'restaurant',
          'quantity': quantity,
          'specialInstructions': specialInstructions,
          'options': options,
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
          'options': options,
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
          'options': options,
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
