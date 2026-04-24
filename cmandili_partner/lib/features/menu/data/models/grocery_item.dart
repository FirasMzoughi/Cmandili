import 'grocery_category.dart';

class GroceryItem {
  final String id;
  final String supermarketId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final GroceryCategory category;
  final String unit;
  final bool isOrganic;
  final bool isAvailable;
  final double? discountPrice;
  final String? discountEndTime;
  final int? discountQuantity;

  GroceryItem({
    required this.id,
    required this.supermarketId,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    required this.price,
    required this.category,
    this.unit = 'piece',
    this.isOrganic = false,
    this.isAvailable = true,
    this.discountPrice,
    this.discountEndTime,
    this.discountQuantity,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'vegetables';
    final category = GroceryCategory.values.firstWhere(
      (c) => c.toString().split('.').last == categoryStr,
      orElse: () => GroceryCategory.vegetables,
    );
    return GroceryItem(
      id: json['id'] as String? ?? '',
      supermarketId: json['supermarketId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: category,
      unit: json['unit'] as String? ?? 'piece',
      isOrganic: json['isOrganic'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      discountEndTime: json['discountEndTime'] as String?,
      discountQuantity: json['discountQuantity'] as int?,
    );
  }
}
