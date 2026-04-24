class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? specialInstructions;
  
  CartItem({
      required this.id,
      required this.name,
      required this.price,
      required this.quantity,
      required this.imageUrl,
      this.specialInstructions,
  });

  double get totalPrice => price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type == 'grocery') {
        final grocery = json['groceryItem'] ?? {};
        return CartItem(
            id: grocery['id'] ?? '',
            name: grocery['name'] ?? '',
            price: (grocery['price'] ?? 0).toDouble(),
            quantity: json['quantity'] ?? 1,
            imageUrl: grocery['image_url'] ?? '',
        );
    } else {
        final food = json['foodItem'] ?? {};
        return CartItem(
            id: food['id'] ?? '',
            name: food['name'] ?? '',
            price: (food['price'] ?? 0).toDouble(),
            quantity: json['quantity'] ?? 1,
            imageUrl: food['image_url'] ?? '',
            specialInstructions: json['specialInstructions'],
        );
    }
  }

  Map<String, dynamic> toJson() {
    return {};
  }
}
