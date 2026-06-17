import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/openrouter_config.dart';
import 'models/food_item.dart';
import 'models/grocery_category.dart';
import 'models/grocery_item.dart';
import 'models/item_variant.dart';

class MenuRepository {
  final _supabase = Supabase.instance.client;

  // ─── Food Items (Restaurant) ────────────────────────────────────────────────

  Future<List<FoodItem>> getFoodItems(String restaurantId) async {
    try {
      final response = await _supabase
          .from('food_items')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('category');
      return (response as List)
          .map((json) => FoodItem.fromJson(_mapFoodItemFromDb(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching food items: $e');
      return [];
    }
  }

  Future<String?> addFoodItem(FoodItem item, String restaurantId) async {
    try {
      final response = await _supabase.from('food_items').insert({
        'restaurant_id': restaurantId,
        'name': item.name,
        'description': item.description,
        'image_url': item.imageUrl,
        'price': item.price,
        'category': item.category,
        'is_available': item.isAvailable,
        'preparation_time': item.preparationTime,
        'is_vegetarian': item.isVegetarian,
        'is_spicy': item.isSpicy,
        'is_happy_hour': item.isHappyHour,
        'happy_hour_price': item.happyHourPrice,
        'happy_hour_start': item.happyHourStart,
        'happy_hour_end': item.happyHourEnd,
      }).select().single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error adding food item: $e');
      return null;
    }
  }

  Future<bool> updateFoodItem(FoodItem item) async {
    try {
      await _supabase.from('food_items').update({
        'name': item.name,
        'description': item.description,
        'image_url': item.imageUrl,
        'price': item.price,
        'category': item.category,
        'is_available': item.isAvailable,
        'preparation_time': item.preparationTime,
        'is_vegetarian': item.isVegetarian,
        'is_spicy': item.isSpicy,
        'is_happy_hour': item.isHappyHour,
        'happy_hour_price': item.happyHourPrice,
        'happy_hour_start': item.happyHourStart,
        'happy_hour_end': item.happyHourEnd,
      }).eq('id', item.id);
      return true;
    } catch (e) {
      debugPrint('Error updating food item: $e');
      return false;
    }
  }

  Future<bool> updateItemAvailability(String itemId, bool isAvailable, {required bool isGrocery}) async {
    try {
      final table = isGrocery ? 'grocery_items' : 'food_items';
      await _supabase
          .from(table)
          .update({'is_available': isAvailable})
          .eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error toggling item availability: $e');
      return false;
    }
  }

  Future<bool> deleteFoodItem(String itemId) async {
    try {
      await _supabase.from('food_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error deleting food item: $e');
      return false;
    }
  }

  // ─── Grocery Items (Supermarket) ────────────────────────────────────────────

  Future<List<GroceryItem>> getGroceryItems(String supermarketId) async {
    try {
      final response = await _supabase
          .from('grocery_items')
          .select()
          .eq('supermarket_id', supermarketId)
          .order('category');
      return (response as List)
          .map((json) => GroceryItem.fromJson(_mapGroceryItemFromDb(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching grocery items: $e');
      return [];
    }
  }

  Future<String?> addGroceryItem(GroceryItem item, String supermarketId) async {
    try {
      final response = await _supabase.from('grocery_items').insert({
        'supermarket_id': supermarketId,
        'name': item.name,
        'description': item.description,
        'image_url': item.imageUrl,
        'price': item.price,
        'category': item.category.toString().split('.').last,
        'unit': item.unit,
        'is_organic': item.isOrganic,
        'is_available': item.isAvailable,
      }).select().single();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error adding grocery item: $e');
      return null;
    }
  }

  Future<bool> updateGroceryItem(GroceryItem item) async {
    try {
      await _supabase.from('grocery_items').update({
        'name': item.name,
        'description': item.description,
        'image_url': item.imageUrl,
        'price': item.price,
        'category': item.category.toString().split('.').last,
        'unit': item.unit,
        'is_organic': item.isOrganic,
        'is_available': item.isAvailable,
      }).eq('id', item.id);
      return true;
    } catch (e) {
      debugPrint('Error updating grocery item: $e');
      return false;
    }
  }

  Future<bool> deleteGroceryItem(String itemId) async {
    try {
      await _supabase.from('grocery_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error deleting grocery item: $e');
      return false;
    }
  }

  // ─── Happy Hour (cross-app) ──────────────────────────────────────────────────

  /// Sets happy hour discount on a food_item or grocery_item.
  /// When this writes discount_price + discount_end_time,
  /// cmandili_mobile's happyHourRestaurantsProvider picks it up automatically.
  Future<bool> setHappyHour({
    required String itemId,
    required bool isGrocery,
    required double discountPrice,
    required DateTime endTime,
    int? quantity,
  }) async {
    try {
      final table = isGrocery ? 'grocery_items' : 'food_items';
      await _supabase.from(table).update({
        'discount_price': discountPrice,
        'discount_end_time': endTime.toIso8601String(),
        'discount_quantity': quantity,
      }).eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error setting happy hour: $e');
      return false;
    }
  }

  /// Clears happy hour — item disappears from mobile's happy hour list.
  Future<bool> clearHappyHour(String itemId, bool isGrocery) async {
    try {
      final table = isGrocery ? 'grocery_items' : 'food_items';
      await _supabase.from(table).update({
        'discount_price': null,
        'discount_end_time': null,
        'discount_quantity': null,
      }).eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error clearing happy hour: $e');
      return false;
    }
  }

  // ─── Item Variants (cross-app) ─────────────────────────────────────────────

  /// Loads variants for one food/grocery item, ordered by sort_order.
  /// Returns [] when the item has none — caller falls back to base price.
  Future<List<ItemVariant>> getVariants({
    required String itemId,
    required bool isGrocery,
  }) async {
    try {
      final table = isGrocery ? 'grocery_item_variants' : 'food_item_variants';
      final fk = isGrocery ? 'grocery_item_id' : 'food_item_id';
      final response = await _supabase
          .from(table)
          .select()
          .eq(fk, itemId)
          .order('sort_order');
      return (response as List).map((r) => ItemVariant.fromDb(r)).toList();
    } catch (e) {
      debugPrint('Error fetching variants: $e');
      return [];
    }
  }

  /// Replaces the full variant set for an item — simplest UX: partner edits
  /// the list as a whole, we delete-all + insert-all in one call. Avoids the
  /// complexity of diffing deletes/updates/inserts client-side.
  Future<bool> replaceVariants({
    required String itemId,
    required bool isGrocery,
    required List<ItemVariant> variants,
  }) async {
    try {
      final table = isGrocery ? 'grocery_item_variants' : 'food_item_variants';
      final fk = isGrocery ? 'grocery_item_id' : 'food_item_id';
      await _supabase.from(table).delete().eq(fk, itemId);
      if (variants.isEmpty) return true;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < variants.length; i++) {
        final v = variants[i].copyWith(sortOrder: i);
        rows.add(v.toInsert(fk, itemId));
      }
      await _supabase.from(table).insert(rows);
      return true;
    } catch (e) {
      debugPrint('Error replacing variants: $e');
      return false;
    }
  }

  // ─── AI Menu Scanner ───────────────────────────────────────────────────────

  /// Scans a photo of a physical menu / price list and inserts the detected
  /// items straight into the partner's catalog.
  ///
  /// This calls the OpenRouter vision API directly from the app (no Edge
  /// Function hop) for speed. The model is asked for strict JSON; we parse it,
  /// then fan out the DB inserts in parallel. Returns the number of items
  /// actually inserted.
  Future<int> scanMenu({
    required String base64Image,
    required String partnerId,
    required String partnerType,
  }) async {
    if (!OpenRouterConfig.isConfigured) {
      throw Exception('OpenRouter API key is missing — check your .env file.');
    }

    final isGrocery = partnerType != 'restaurant';
    final items = await _extractItemsFromImage(
      base64Image: base64Image,
      isGrocery: isGrocery,
    );

    if (items.isEmpty) {
      throw Exception('No menu items could be detected in that photo.');
    }

    // Fan out the inserts in parallel — much faster than awaiting each one.
    final results = await Future.wait(
      items.map((raw) => _insertScannedItem(
            raw: raw,
            partnerId: partnerId,
            isGrocery: isGrocery,
          )),
    );

    final count = results.where((ok) => ok).length;
    if (count == 0) {
      throw Exception('Detected ${items.length} items but none could be saved.');
    }
    return count;
  }

  /// Sends the image to OpenRouter and returns the raw parsed item maps.
  Future<List<Map<String, dynamic>>> _extractItemsFromImage({
    required String base64Image,
    required bool isGrocery,
  }) async {
    final categoryHint = isGrocery
        ? 'category must be one of: ${GroceryCategory.values.map((c) => c.name).join(', ')}'
        : 'category is a short food category like "Starters", "Main", "Drinks", "Desserts"';

    final prompt =
        'You are reading a photo of a ${isGrocery ? 'grocery price list' : 'restaurant menu'}. '
        'Extract every item you can see. Respond with ONLY a JSON array, no markdown, '
        'no commentary. Each element must be an object with these keys: '
        '"name" (string), "description" (string, "" if none), '
        '"price" (number, 0 if unreadable), "category" (string). '
        'For category, $categoryHint. If a price has currency symbols or text, '
        'return just the number.';

    final body = jsonEncode({
      'model': OpenRouterConfig.model,
      // Nudges compatible models to emit valid JSON.
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
          ],
        },
      ],
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(OpenRouterConfig.endpoint),
            headers: {
              'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
              'Content-Type': 'application/json',
              // Optional but recommended by OpenRouter for attribution.
              'HTTP-Referer': 'https://partner.cmandili.com',
              'X-Title': 'Cmandili Partner',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('OpenRouter request failed: $e');
      throw Exception('Could not reach the AI service. Check your connection.');
    }

    if (response.statusCode != 200) {
      debugPrint('OpenRouter error ${response.statusCode}: ${response.body}');
      throw Exception('AI service error (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('The AI returned an empty response.');
    }

    return _parseItemsJson(content);
  }

  /// The model may wrap the JSON in markdown fences or return an object that
  /// holds the array under a key — this digs the list out either way.
  List<Map<String, dynamic>> _parseItemsJson(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```(json)?'), '').replaceAll('```', '').trim();
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      // Last resort: grab the first [...] block out of the text.
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (match == null) {
        throw Exception('The AI response was not valid JSON.');
      }
      parsed = jsonDecode(match.group(0)!);
    }

    List<dynamic> list;
    if (parsed is List) {
      list = parsed;
    } else if (parsed is Map) {
      // e.g. {"items": [...]} — take the first List value we find.
      final listValue = parsed.values.firstWhere(
        (v) => v is List,
        orElse: () => null,
      );
      list = listValue is List ? listValue : const [];
    } else {
      list = const [];
    }

    return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// Maps one raw model item to a FoodItem/GroceryItem and inserts it.
  Future<bool> _insertScannedItem({
    required Map<String, dynamic> raw,
    required String partnerId,
    required bool isGrocery,
  }) async {
    final name = (raw['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return false;

    final description = (raw['description'] as String?)?.trim() ?? '';
    final price = (raw['price'] as num?)?.toDouble() ??
        double.tryParse('${raw['price']}'.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    final categoryStr = (raw['category'] as String?)?.trim() ?? '';

    if (isGrocery) {
      final category = GroceryCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == categoryStr.toLowerCase(),
        orElse: () => GroceryCategory.other,
      );
      final id = await addGroceryItem(
        GroceryItem(
          id: '',
          supermarketId: partnerId,
          name: name,
          description: description,
          price: price,
          category: category,
        ),
        partnerId,
      );
      return id != null;
    } else {
      final id = await addFoodItem(
        FoodItem(
          id: '',
          restaurantId: partnerId,
          name: name,
          description: description,
          price: price,
          category: categoryStr.isEmpty ? 'Other' : categoryStr,
        ),
        partnerId,
      );
      return id != null;
    }
  }

  // ─── Storage ─────────────────────────────────────────────────────────────────
  
  Future<String?> uploadItemImage(String path, dynamic fileBytesOrFile) async {
    try {
      // Depending on platform, fileBytesOrFile could be a File or Uint8List
      // Using universal put
      await _supabase.storage.from('items').upload(
            path,
            fileBytesOrFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      final url = _supabase.storage.from('items').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> _mapFoodItemFromDb(Map<String, dynamic> db) {
    return {
      'id': db['id'],
      'restaurantId': db['restaurant_id'],
      'name': db['name'],
      'description': db['description'],
      'imageUrl': db['image_url'],
      'price': db['price'],
      'category': db['category'],
      'isAvailable': db['is_available'],
      'tags': [],
      'preparationTime': db['preparation_time'],
      'isVegetarian': db['is_vegetarian'],
      'isSpicy': db['is_spicy'],
      'discountPrice': db['discount_price'],
      'discountEndTime': db['discount_end_time'],
      'discountQuantity': db['discount_quantity'],
      'isHappyHour': db['is_happy_hour'] ?? false,
      'happyHourPrice': db['happy_hour_price'],
      'happyHourStart': db['happy_hour_start'],
      'happyHourEnd': db['happy_hour_end'],
    };
  }

  Map<String, dynamic> _mapGroceryItemFromDb(Map<String, dynamic> db) {
    return {
      'id': db['id'],
      'supermarketId': db['supermarket_id'],
      'name': db['name'],
      'description': db['description'],
      'imageUrl': db['image_url'],
      'price': db['price'],
      'category': db['category'],
      'unit': db['unit'],
      'isOrganic': db['is_organic'],
      'isAvailable': db['is_available'],
      'discountPrice': db['discount_price'],
      'discountEndTime': db['discount_end_time'],
      'discountQuantity': db['discount_quantity'],
    };
  }
}
