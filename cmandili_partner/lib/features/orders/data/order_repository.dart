import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../data/models/order.dart';
import '../../restaurant/data/models/food_item.dart';
import '../../supermarket/data/models/grocery_item.dart';
import '../../supermarket/data/models/grocery_category.dart';

class OrderRepository {
  final _supabase = Supabase.instance.client;

  Future<String?> createOrder({
    required List<CartItem> items,
    required DeliveryAddress deliveryAddress,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required OrderType orderType,
    String? restaurantId,
    String? supermarketId,
    String? notes,
    String paymentMethod = 'cash',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final orderResponse = await _supabase.from('orders').insert({
        'user_id': userId,
        'restaurant_id': restaurantId,
        'supermarket_id': supermarketId,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod,
        'notes': notes,
        'delivery_address': deliveryAddress.toJson(),
        'order_type': orderType.toString().split('.').last,
      }).select().single();

      final orderId = orderResponse['id'];

      for (final item in items) {
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'food_item_id': item.type == CartItemType.restaurant ? item.foodItem?.id : null,
          'grocery_item_id': item.type == CartItemType.grocery ? item.groceryItem?.id : null,
          'quantity': item.quantity,
          'price': item.price,
          'special_instructions': item.specialInstructions,
          'options': item.customization != null ? item.customization!.toJson() : {},
        });
      }

      return orderId;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  Future<List<Order>> getUserOrders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items (
              id,
              food_item_id,
              grocery_item_id,
              quantity,
              price,
              special_instructions,
              options,
              food_items (id, name, description, image_url, price, category, is_vegetarian, is_spicy, preparation_time, discount_price, discount_end_time),
              grocery_items (id, name, description, image_url, price, category, unit, is_organic, discount_price, discount_end_time)
            ),
            restaurants (name),
            supermarkets (name)
          ''')
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

  Stream<Order> streamOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((event) {
          if (event.isEmpty) {
            throw Exception('Order not found');
          }
          return Order.fromJson(_mapOrderFromDb(event.first));
        });
  }

  List<CartItem> _mapOrderItems(List<dynamic> dbItems) {
    return dbItems.map((item) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final specialInstructions = item['special_instructions'] as String?;

      if (item['food_item_id'] != null) {
        final foodData = item['food_items'];
        if (foodData != null) {
          return CartItem.restaurant(
            foodItem: FoodItem(
              id: foodData['id'] ?? '',
              restaurantId: '',
              name: foodData['name'] ?? '',
              description: foodData['description'] ?? '',
              imageUrl: foodData['image_url'] ?? '',
              price: (foodData['price'] ?? 0).toDouble(),
              category: foodData['category'] ?? '',
              isVegetarian: foodData['is_vegetarian'] ?? false,
              isSpicy: foodData['is_spicy'] ?? false,
              preparationTime: foodData['preparation_time'] ?? 15,
              discountPrice: foodData['discount_price']?.toDouble(),
              discountEndTime: foodData['discount_end_time'] != null
                  ? DateTime.tryParse(foodData['discount_end_time'])
                  : null,
            ),
            quantity: quantity,
            specialInstructions: specialInstructions,
          );
        }
      } else if (item['grocery_item_id'] != null) {
        final groceryData = item['grocery_items'];
        if (groceryData != null) {
          return CartItem.grocery(
            groceryItem: GroceryItem(
              id: groceryData['id'] ?? '',
              supermarketId: '',
              name: groceryData['name'] ?? '',
              description: groceryData['description'] ?? '',
              imageUrl: groceryData['image_url'] ?? '',
              price: (groceryData['price'] ?? 0).toDouble(),
              category: _parseGroceryCategory(groceryData['category']),
              unit: groceryData['unit'] ?? 'piece',
              isOrganic: groceryData['is_organic'] ?? false,
              discountPrice: groceryData['discount_price']?.toDouble(),
              discountEndTime: groceryData['discount_end_time'] != null
                  ? DateTime.tryParse(groceryData['discount_end_time'])
                  : null,
            ),
            quantity: quantity,
          );
        }
      }

      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      return CartItem.restaurant(
        foodItem: FoodItem(
          id: item['food_item_id'] ?? item['grocery_item_id'] ?? 'unknown',
          restaurantId: '',
          name: 'Item',
          description: '',
          imageUrl: '',
          price: price,
          category: '',
        ),
        quantity: quantity,
        specialInstructions: specialInstructions,
      );
    }).toList();
  }

  GroceryCategory _parseGroceryCategory(String? category) {
    if (category == null) return GroceryCategory.vegetables;
    try {
      return GroceryCategory.values.firstWhere(
        (e) => e.toString() == 'GroceryCategory.$category',
        orElse: () => GroceryCategory.vegetables,
      );
    } catch (e) {
      return GroceryCategory.vegetables;
    }
  }

  Map<String, dynamic> _mapOrderFromDb(Map<String, dynamic> dbJson) {
    final restaurantId = dbJson['restaurant_id'] ?? '';
    final supermarketId = dbJson['supermarket_id'] ?? '';
    final orderType = dbJson['order_type'] ?? 'food';

    String restaurantName = '';
    if (restaurantId.isNotEmpty) {
      final restaurantData = dbJson['restaurants'];
      if (restaurantData != null) {
        restaurantName = restaurantData['name'] ?? '';
      }
    } else if (supermarketId.isNotEmpty) {
      final supermarketData = dbJson['supermarkets'];
      if (supermarketData != null) {
        restaurantName = supermarketData['name'] ?? '';
      }
    }

    List<dynamic> orderItemsData = dbJson['order_items'] ?? [];
    final items = _mapOrderItems(orderItemsData);

    return {
      'id': dbJson['id'],
      'userId': dbJson['user_id'],
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((item) => item.toJson()).toList(),
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
      'type': orderType,
      'pickupAddress': dbJson['pickup_address'],
      'recipientName': dbJson['recipient_name'],
      'recipientPhone': dbJson['recipient_phone'],
      'packageDescription': dbJson['package_description'],
      'isRecipientAccepted': false,
    };
  }
}
