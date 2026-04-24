class Restaurant {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int deliveryTime; // in minutes
  final double deliveryFee;
  final double minimumOrder;
  final List<String> categories;
  final bool isOpen;
  final double latitude;
  final double longitude;

  Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.categories,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      deliveryTime: json['deliveryTime'] ?? 30,
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      minimumOrder: (json['minimumOrder'] ?? 0).toDouble(),
      categories: List<String>.from(json['categories'] ?? []),
      isOpen: json['isOpen'] ?? true,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'minimumOrder': minimumOrder,
      'categories': categories,
      'isOpen': isOpen,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
