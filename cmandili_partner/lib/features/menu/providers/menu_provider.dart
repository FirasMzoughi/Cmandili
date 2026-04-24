import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/menu_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/food_item.dart';
import '../data/models/grocery_item.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final menuItemsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final profile = await ref.watch(partnerProfileProvider.future);
  if (profile == null) return [];
  final repo = ref.read(menuRepositoryProvider);
  if (profile.partnerType == 'restaurant') {
    return repo.getFoodItems(profile.entityId);
  } else {
    return repo.getGroceryItems(profile.entityId);
  }
});

final filteredMenuItemsProvider = Provider.autoDispose<AsyncValue<List<dynamic>>>((ref) {
  final items = ref.watch(menuItemsProvider);
  final category = ref.watch(selectedCategoryProvider);
  return items.whenData((list) {
    if (category == null) return list;
    return list.where((item) {
      if (item is FoodItem) return item.category == category;
      if (item is GroceryItem) {
        return item.category.toString().split('.').last == category;
      }
      return true;
    }).toList();
  });
});
