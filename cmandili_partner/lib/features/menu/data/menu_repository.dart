import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/food_item.dart';
import 'models/grocery_item.dart';

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
      }).eq('id', item.id);
      return true;
    } catch (e) {
      debugPrint('Error updating food item: $e');
      return false;
    }
  }

  Future<bool> toggleFoodItemAvailability(String itemId, bool isAvailable) async {
    try {
      await _supabase
          .from('food_items')
          .update({'is_available': isAvailable})
          .eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error toggling food item: $e');
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

  Future<bool> toggleGroceryItemAvailability(String itemId, bool isAvailable) async {
    try {
      await _supabase
          .from('grocery_items')
          .update({'is_available': isAvailable})
          .eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error toggling grocery item: $e');
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
