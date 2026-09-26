/// A catalogue line for the generic vendor categories — bakery, flowers, pets,
/// gifts, electronics.
///
/// Restaurants keep [FoodItem] (`food_items`) and supermarkets keep
/// [GroceryItem] (`grocery_items`); both of those tables are category-filtered
/// views, so a florist writing through them inserts a row its own catalogue
/// query then filters straight back out. Everything else lives in
/// `vendor_items`, which is category-agnostic.
///
/// Restaurant-only concepts (prep time, vegetarian, happy hour, variants) are
/// deliberately absent: they are meaningless for a bouquet or a phone case.
class VendorItem {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;

  /// Free-text section within the shop's own catalogue ("Coffrets",
  /// "Bouquets"). Unlike the restaurant path this is not constrained to an
  /// enum, because each category names its sections differently.
  final String category;

  /// Optional selling unit ("bouquet", "kg", "piece").
  final String? unit;
  final bool isAvailable;
  final int sortOrder;

  const VendorItem({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    this.category = '',
    this.unit,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  factory VendorItem.fromJson(Map<String, dynamic> json) {
    return VendorItem(
      id: json['id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      // Numeric comes back as num (or as a string through some drivers), so
      // normalise rather than casting straight to double.
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse('${json['price']}') ??
          0,
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Only the columns the partner app owns — `id`, `vendor_id` and
  /// `created_at` are left to the database.
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'category': category,
      'unit': unit,
      'is_available': isAvailable,
    };
  }

  VendorItem copyWith({
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    String? category,
    String? unit,
    bool? isAvailable,
    int? sortOrder,
  }) {
    return VendorItem(
      id: id,
      vendorId: vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
