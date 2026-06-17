import 'cart_item.dart';
import 'delivery_address.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
}

enum OrderType {
  food,
  supermarket,
  courier,
  billPayment,
}

class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final List<CartItem> items;
  final DeliveryAddress deliveryAddress;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final String paymentMethod;
  final String? notes;
  
  // New fields for Courier/P2P
  final OrderType type;
  final DeliveryAddress? pickupAddress;
  final String? recipientName;
  final String? recipientPhone;
  final String? packageDescription;
  final bool isRecipientAccepted;

  // Resolved customer display name + phone, sourced from the
  // orders_with_customer view (delivery_address.recipientName/phone first,
  // then profiles.full_name/phone). Empty string when unknown.
  final String? customerName;
  final String? customerPhone;

  Order({
    required this.id,
    required this.userId,
    this.restaurantId = '',
    this.restaurantName = '',
    this.items = const [],
    required this.deliveryAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.status,
    required this.createdAt,
    this.estimatedDeliveryTime,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    this.paymentMethod = 'Cash on Delivery',
    this.notes,
    this.type = OrderType.food,
    this.pickupAddress,
    this.recipientName,
    this.recipientPhone,
    this.packageDescription,
    this.isRecipientAccepted = false,
    this.customerName,
    this.customerPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      items: (json['items'] as List?)
              ?.map((item) => CartItem.fromJson(item))
              .toList() ??
          [],
      deliveryAddress: DeliveryAddress.fromJson(json['deliveryAddress'] ?? {}),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == 'OrderStatus.${json['status']}',
        orElse: () => OrderStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      estimatedDeliveryTime: json['estimatedDeliveryTime'] != null
          ? DateTime.parse(json['estimatedDeliveryTime'])
          : null,
      driverId: json['driverId'],
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      driverLatitude: json['driverLatitude']?.toDouble(),
      driverLongitude: json['driverLongitude']?.toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'Cash on Delivery',
      notes: json['notes'],
      type: OrderType.values.firstWhere(
        (e) => e.toString() == 'OrderType.${json['type']}',
        orElse: () => OrderType.food,
      ),
      pickupAddress: json['pickupAddress'] != null 
          ? DeliveryAddress.fromJson(json['pickupAddress']) 
          : null,
      recipientName: json['recipientName'],
      recipientPhone: json['recipientPhone'],
      packageDescription: json['packageDescription'],
      isRecipientAccepted: json['isRecipientAccepted'] ?? false,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((item) => item.toJson()).toList(),
      'deliveryAddress': deliveryAddress.toJson(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverLatitude': driverLatitude,
      'driverLongitude': driverLongitude,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'type': type.toString().split('.').last,
      'pickupAddress': pickupAddress?.toJson(),
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'packageDescription': packageDescription,
      'isRecipientAccepted': isRecipientAccepted,
    };
  }

  String getStatusText() {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onTheWay:
        return 'On the Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
