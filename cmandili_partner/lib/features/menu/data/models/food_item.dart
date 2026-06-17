class FoodItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String category;
  final bool isAvailable;
  final List<String> tags;
  final int preparationTime;
  final bool isVegetarian;
  final bool isSpicy;
  final double? discountPrice;
  final String? discountEndTime;
  final int? discountQuantity;
  
  // Happy Hour
  final bool isHappyHour;
  final double? happyHourPrice;
  final String? happyHourStart;
  final String? happyHourEnd;

  FoodItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.tags = const [],
    this.preparationTime = 15,
    this.isVegetarian = false,
    this.isSpicy = false,
    this.discountPrice,
    this.discountEndTime,
    this.discountQuantity,
    this.isHappyHour = false,
    this.happyHourPrice,
    this.happyHourStart,
    this.happyHourEnd,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String? ?? '',
      restaurantId: json['restaurantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      preparationTime: json['preparationTime'] as int? ?? 15,
      isVegetarian: json['isVegetarian'] as bool? ?? false,
      isSpicy: json['isSpicy'] as bool? ?? false,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      discountEndTime: json['discountEndTime'] as String?,
      discountQuantity: json['discountQuantity'] as int?,
      isHappyHour: json['isHappyHour'] as bool? ?? false,
      happyHourPrice: (json['happyHourPrice'] as num?)?.toDouble(),
      happyHourStart: json['happyHourStart'] as String?,
      happyHourEnd: json['happyHourEnd'] as String?,
    );
  }
}
