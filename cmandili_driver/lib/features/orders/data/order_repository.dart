import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/order.dart';

class OrderRepository {
  final _supabase = Supabase.instance.client;

  // Fetch user's orders
  Future<List<Order>> getUserOrders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Order.fromJson(_mapOrderFromDb(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase.from('orders').update({
        'status': status.toString().split('.').last,
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  // Stream order updates. We subscribe to the `orders` realtime channel for
  // change events, but pull the resolved customer fields from
  // orders_with_customer on each update so the driver always has a phone to
  // call.
  Stream<Order> streamOrder(String orderId) async* {
    Map<String, dynamic>? customer;
    Future<void> refreshCustomer() async {
      try {
        final row = await _supabase
            .from('orders_with_customer')
            .select('customer_name, customer_phone')
            .eq('id', orderId)
            .maybeSingle();
        customer = row;
      } catch (_) {
        customer = null;
      }
    }

    await refreshCustomer();
    await for (final event in _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)) {
      if (event.isEmpty) {
        throw Exception('Order not found');
      }
      final mapped = _mapOrderFromDb(event.first);
      mapped['customerName'] = customer?['customer_name'];
      mapped['customerPhone'] = customer?['customer_phone'];
      yield Order.fromJson(mapped);
    }
  }

  Map<String, dynamic> _mapOrderFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'userId': dbJson['user_id'],
      'restaurantId': dbJson['restaurant_id'] ?? '',
      'restaurantName': '', // Would need to join with restaurants table
      'items': [], // Would need to join with order_items table
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
      'senderPhone': dbJson['sender_phone'],
      'packageDescription': dbJson['package_description'],
      'packagePhotoUrl': dbJson['package_photo_url'],
      'isRecipientAccepted': false,
      'customerName': dbJson['customer_name'],
      'customerPhone': dbJson['customer_phone'],
      'billType': dbJson['bill_type'],
      'billReference': dbJson['bill_reference'],
      'billAmount': dbJson['bill_amount'] != null ? (dbJson['bill_amount'] as num).toDouble() : null,
      'billPhotoUrl': dbJson['bill_photo_url'],
      'receiptPhotoUrl': dbJson['bill_receipt_url'],
    };
  }
}
