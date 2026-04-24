// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderItemModelImpl _$$OrderItemModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemModelImpl(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      foodItemId: json['food_item_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$OrderItemModelImplToJson(
        _$OrderItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'food_item_id': instance.foodItemId,
      'name': instance.name,
      'price': instance.price,
      'quantity': instance.quantity,
      'options': instance.options,
    };
