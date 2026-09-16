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
  // Selected option-group add-ons, formatted for a fast rush-hour read, e.g.
  // "Sauce: Harissa, Mayonnaise · Suppléments: Gruyère (+6.00 DT)". Pulled
  // from options.optionGroups[].{groupName,selections[].{name,price}}.
  final String? optionsSummary;

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
      this.optionsSummary,
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
    String? optionsSummary;
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
      optionsSummary = _formatOptionGroups(options['optionGroups']);
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
            optionsSummary: optionsSummary,
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
            optionsSummary: optionsSummary,
        );
    }
  }

  /// Groups selected add-ons by their option group for a fast rush-hour
  /// read, e.g. "Sauce: Harissa, Mayonnaise · Suppléments: Gruyère (+6.00 DT)".
  /// Null when nothing was selected.
  static String? _formatOptionGroups(dynamic optionGroups) {
    if (optionGroups is! List || optionGroups.isEmpty) return null;
    final parts = <String>[];
    for (final group in optionGroups) {
      if (group is! Map) continue;
      final groupName = group['groupName'] as String?;
      final selections = group['selections'];
      if (groupName == null || groupName.isEmpty || selections is! List) continue;
      final labels = selections
          .whereType<Map>()
          .map((s) {
            final name = s['name'] as String?;
            if (name == null || name.isEmpty) return null;
            final price = (s['price'] as num?)?.toDouble() ?? 0.0;
            return price > 0 ? '$name (+${price.toStringAsFixed(2)} DT)' : name;
          })
          .whereType<String>()
          .join(', ');
      if (labels.isEmpty) continue;
      parts.add('$groupName: $labels');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'unknown',
      'quantity': quantity,
      'specialInstructions': specialInstructions,
    };
  }
}
