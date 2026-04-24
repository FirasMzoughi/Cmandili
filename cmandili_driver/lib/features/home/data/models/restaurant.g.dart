// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RestaurantImpl _$$RestaurantImplFromJson(Map<String, dynamic> json) =>
    _$RestaurantImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      deliveryTime: (json['delivery_time_min'] as num?)?.toInt() ?? 30,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      minimumOrder: (json['min_order'] as num?)?.toDouble() ?? 0.0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isOpen: json['is_open'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$RestaurantImplToJson(_$RestaurantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'rating': instance.rating,
      'review_count': instance.reviewCount,
      'delivery_time_min': instance.deliveryTime,
      'delivery_fee': instance.deliveryFee,
      'min_order': instance.minimumOrder,
      'categories': instance.categories,
      'is_open': instance.isOpen,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
