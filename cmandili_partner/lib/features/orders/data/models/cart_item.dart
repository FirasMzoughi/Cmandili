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
  // Selected variant name when the customer picked an option
  // (e.g. "Chocolate"). Pulled from options.variant.name.
  final String? variantName;

  CartItem({
      required this.id,
      required this.name,
      required this.price,
      required this.quantity,
      required this.imageUrl,
      this.specialInstructions,
      this.voiceNoteContent,
      this.voiceNoteDurationSeconds,
      this.variantName,
  });

  double get totalPrice => price * quantity;

  /// Display name with the variant suffixed when present, so the partner sees
  /// the exact option the customer ordered without expanding details.
  String get displayName => variantName != null ? '$name — $variantName' : name;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'];

    // Parse voice note + variant from the options blob (set by mobile cart)
    String? voiceContent;
    int? voiceDuration;
    String? variantName;
    final options = json['options'];
    if (options is Map) {
      if (options['type'] == 'voice') {
        voiceContent = options['content'] as String?;
        voiceDuration = (options['durationSeconds'] as num?)?.toInt();
      }
      final variant = options['variant'];
      if (variant is Map) {
        variantName = variant['name'] as String?;
      }
    }

    if (type == 'grocery') {
        final grocery = json['groceryItem'] ?? {};
        return CartItem(
            id: grocery['id'] ?? '',
            name: grocery['name'] ?? '',
            price: (grocery['price'] ?? 0).toDouble(),
            quantity: json['quantity'] ?? 1,
            // _parseOrderItems stores the key as camelCase 'imageUrl'.
            imageUrl: grocery['imageUrl'] as String? ?? '',
            voiceNoteContent: voiceContent,
            voiceNoteDurationSeconds: voiceDuration,
            variantName: variantName,
        );
    } else {
        final food = json['foodItem'] ?? {};
        return CartItem(
            id: food['id'] ?? '',
            name: food['name'] ?? '',
            price: (food['price'] ?? 0).toDouble(),
            quantity: json['quantity'] ?? 1,
            // _parseOrderItems stores the key as camelCase 'imageUrl'.
            imageUrl: food['imageUrl'] as String? ?? '',
            specialInstructions: json['specialInstructions'],
            voiceNoteContent: voiceContent,
            voiceNoteDurationSeconds: voiceDuration,
            variantName: variantName,
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
