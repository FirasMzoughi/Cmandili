class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? specialInstructions;
  // Voice note from order_items.options JSON blob (type == 'voice')
  final String? voiceNoteContent;
  final int? voiceNoteDurationSeconds;

  CartItem({
      required this.id,
      required this.name,
      required this.price,
      required this.quantity,
      required this.imageUrl,
      this.specialInstructions,
      this.voiceNoteContent,
      this.voiceNoteDurationSeconds,
  });

  double get totalPrice => price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'];

    // Parse voice note from the options blob (set by mobile cart)
    String? voiceContent;
    int? voiceDuration;
    final options = json['options'];
    if (options is Map) {
      if (options['type'] == 'voice') {
        voiceContent = options['content'] as String?;
        voiceDuration = (options['durationSeconds'] as num?)?.toInt();
      }
    }

    if (type == 'grocery') {
        final grocery = json['groceryItem'] ?? {};
        return CartItem(
            id: grocery['id'] ?? '',
            name: grocery['name'] ?? '',
            price: (grocery['price'] ?? 0).toDouble(),
            quantity: json['quantity'] ?? 1,
            imageUrl: grocery['image_url'] ?? '',
            voiceNoteContent: voiceContent,
            voiceNoteDurationSeconds: voiceDuration,
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
            voiceNoteContent: voiceContent,
            voiceNoteDurationSeconds: voiceDuration,
        );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'unknown',
      'quantity': quantity,
      'specialInstructions': specialInstructions,
    };
  }
}
