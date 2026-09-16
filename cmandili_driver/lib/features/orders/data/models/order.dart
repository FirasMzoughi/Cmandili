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
  facture,
}

class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final String supermarketId;
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
  final String? senderPhone;
  final String? packageDescription;
  final String? packagePhotoUrl;
  final bool isRecipientAccepted;

  // Bill payment (facture) fields
  final String? billType;
  final String? billReference;
  final double? billAmount;
  final String? billPhotoUrl;
  final String? receiptPhotoUrl;

  // Customer display info resolved by orders_with_customer view.
  final String? customerName;
  final String? customerPhone;

  // Loyalty milestone (5th order = half price, 10th = free), stamped by
  // apply_loyalty_at_checkout() at order creation — already set by the time
  // any driver sees this order, so it's safe to show before accepting.
  final String? loyaltyMilestoneType; // 'half' | 'free' | null
  final double loyaltyDiscountAmount;

  // "Pizza Margherita x2, et 3 autres" — food/supermarket orders only.
  // Null for courier/facture (use packageDescription/billType instead) or
  // when not yet loaded.
  final String? contentSummary;

  // Driver's settlements for this order (generate_settlements_on_delivery).
  // Null when no commission_deduction row exists yet -- non-cash orders
  // never get one, since that trigger is cash-only. commissionAmount is
  // stored/shown as a negative value; loyaltySubsidyAmount (positive) is
  // only set when this was a loyalty-milestone order.
  final double? commissionAmount;
  final double? loyaltySubsidyAmount;

  Order({
    required this.id,
    required this.userId,
    this.restaurantId = '',
    this.restaurantName = '',
    this.supermarketId = '',
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
    this.senderPhone,
    this.packageDescription,
    this.packagePhotoUrl,
    this.isRecipientAccepted = false,
    this.billType,
    this.billReference,
    this.billAmount,
    this.billPhotoUrl,
    this.receiptPhotoUrl,
    this.customerName,
    this.customerPhone,
    this.loyaltyMilestoneType,
    this.loyaltyDiscountAmount = 0,
    this.contentSummary,
    this.commissionAmount,
    this.loyaltySubsidyAmount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      supermarketId: json['supermarketId'] ?? '',
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
      senderPhone: json['senderPhone'],
      packageDescription: json['packageDescription'],
      packagePhotoUrl: json['packagePhotoUrl'],
      isRecipientAccepted: json['isRecipientAccepted'] ?? false,
      billType: json['billType'] as String?,
      billReference: json['billReference'] as String?,
      billAmount: (json['billAmount'] as num?)?.toDouble(),
      billPhotoUrl: json['billPhotoUrl'] as String?,
      receiptPhotoUrl: json['receiptPhotoUrl'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      loyaltyMilestoneType: json['loyaltyMilestoneType'] as String?,
      loyaltyDiscountAmount:
          (json['loyaltyDiscountAmount'] as num?)?.toDouble() ?? 0,
      contentSummary: json['contentSummary'] as String?,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
      loyaltySubsidyAmount: (json['loyaltySubsidyAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'supermarketId': supermarketId,
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
      'senderPhone': senderPhone,
      'packageDescription': packageDescription,
      'packagePhotoUrl': packagePhotoUrl,
      'isRecipientAccepted': isRecipientAccepted,
      'billType': billType,
      'billReference': billReference,
      'billAmount': billAmount,
      'billPhotoUrl': billPhotoUrl,
      'receiptPhotoUrl': receiptPhotoUrl,
      'loyaltyMilestoneType': loyaltyMilestoneType,
      'loyaltyDiscountAmount': loyaltyDiscountAmount,
      'contentSummary': contentSummary,
      'commissionAmount': commissionAmount,
      'loyaltySubsidyAmount': loyaltySubsidyAmount,
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
