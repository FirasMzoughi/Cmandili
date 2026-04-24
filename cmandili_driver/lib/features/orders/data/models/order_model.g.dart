// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      restaurantId: json['restaurant_id'] as String,
      driverId: json['driver_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      totalAmount: (json['total_amount'] as num).toDouble(),
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      deliveryAddress: json['delivery_address'] as Map<String, dynamic>,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'restaurant_id': instance.restaurantId,
      'driver_id': instance.driverId,
      'status': instance.status,
      'total_amount': instance.totalAmount,
      'delivery_fee': instance.deliveryFee,
      'payment_method': instance.paymentMethod,
      'payment_status': instance.paymentStatus,
      'delivery_address': instance.deliveryAddress,
      'created_at': instance.createdAt?.toIso8601String(),
    };
