import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/food_item.dart';
import '../data/models/grocery_item.dart';
import 'add_edit_item_screen.dart';
import 'happy_hour_setup_screen.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(partnerProfileProvider);
    final itemsAsync = ref.watch(filteredMenuItemsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isRestaurant = profileAsync.value?.partnerType == 'restaurant';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRestaurant ? 'Menu' : 'Products',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRestaurant
                              ? 'Manage your dishes and set happy hour deals'
                              : 'Manage your products and set happy hour deals',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search items…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Category filter chips
          itemsAsync.when(
            data: (items) {
              final categories = _extractCategories(items);
              if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _categoryChip(null, 'All', selectedCategory),
                        ...categories.map(
                            (c) => _categoryChip(c, c, selectedCategory)),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Items list
          itemsAsync.when(
            data: (items) {
              final filtered = _searchQuery.isEmpty
                  ? items
                  : items.where((item) {
                      final name = item is FoodItem
                          ? item.name.toLowerCase()
                          : (item as GroceryItem).name.toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRestaurant
                              ? Icons.restaurant_menu_rounded
                              : Icons.store_rounded,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No items match "$_searchQuery"'
                              : 'No items yet',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first item',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MenuItemCard(
                        item: filtered[index],
                        isRestaurant: isRestaurant,
                        partnerType: profileAsync.value?.partnerType ?? 'restaurant',
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  'Could not load items.\nCheck your connection.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goToAddEdit(context, ref,
            partnerType: profileAsync.value?.partnerType ?? 'restaurant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add ${profileAsync.value?.partnerType == "restaurant" ? "Dish" : "Product"}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _categoryChip(String? value, String label, String? selected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => ref.read(selectedCategoryProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  List<String> _extractCategories(List<dynamic> items) {
    final cats = <String>{};
    for (final item in items) {
      if (item is FoodItem && item.category.isNotEmpty) cats.add(item.category);
      if (item is GroceryItem) {
        cats.add(item.category.toString().split('.').last);
      }
    }
    return cats.toList()..sort();
  }

  void _goToAddEdit(BuildContext context, WidgetRef ref,
      {required String partnerType,
      FoodItem? foodItem,
      GroceryItem? groceryItem}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(
          partnerType: partnerType,
          existingFoodItem: foodItem,
          existingGroceryItem: groceryItem,
        ),
      ),
    ).then((_) => ref.invalidate(menuItemsProvider));
  }
}

class _MenuItemCard extends ConsumerWidget {
  final dynamic item;
  final bool isRestaurant;
  final String partnerType;

  const _MenuItemCard({
    required this.item,
    required this.isRestaurant,
    required this.partnerType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fi = item is FoodItem ? item as FoodItem : null;
    final gi = item is GroceryItem ? item as GroceryItem : null;

    final name = fi?.name ?? gi?.name ?? '';
    final price = fi?.price ?? gi?.price ?? 0.0;
    final imageUrl = fi?.imageUrl ?? gi?.imageUrl ?? '';
    final isAvailable = fi?.isAvailable ?? gi?.isAvailable ?? true;
    final category = fi?.category ??
        gi?.category.toString().split('.').last ??
        '';
    final hasHappyHour =
        (fi?.discountPrice != null && fi?.discountEndTime != null) ||
            (gi?.discountPrice != null && gi?.discountEndTime != null);
    final discountPrice = fi?.discountPrice ?? gi?.discountPrice;
    final discountEndTime = fi?.discountEndTime ?? gi?.discountEndTime;
    final discountQuantity = fi?.discountQuantity ?? gi?.discountQuantity;
    final itemId = fi?.id ?? gi?.id ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (hasHappyHour)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 11,
                                      color: AppColors.secondary),
                                  const SizedBox(width: 3),
                                  Text('HH',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(category,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            hasHappyHour
                                ? '${discountPrice!.toStringAsFixed(2)} DT'
                                : '${price.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: hasHappyHour
                                  ? AppColors.secondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (hasHappyHour) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${price.toStringAsFixed(2)} DT',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Availability switch
                Switch(
                  value: isAvailable,
                  activeColor: AppColors.primary,
                  onChanged: (v) async {
                    final repo = ref.read(menuRepositoryProvider);
                    if (isRestaurant) {
                      await repo.toggleFoodItemAvailability(itemId, v);
                    } else {
                      await repo.toggleGroceryItemAvailability(itemId, v);
                    }
                    ref.invalidate(menuItemsProvider);
                  },
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppColors.textLight.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                _actionButton(
                  context,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditItemScreen(
                        partnerType: partnerType,
                        existingFoodItem: fi,
                        existingGroceryItem: gi,
                      ),
                    ),
                  ).then((_) => ref.invalidate(menuItemsProvider)),
                ),
                _divider(),
                _actionButton(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  label: 'Happy Hour',
                  color: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HappyHourSetupScreen(
                        itemId: itemId,
                        itemName: name,
                        originalPrice: price,
                        isGrocery: !isRestaurant,
                        currentDiscountPrice: discountPrice,
                        currentEndTime: discountEndTime != null ? DateTime.tryParse(discountEndTime!) : null,
                        currentQuantity: discountQuantity,
                      ),
                    ),
                  ).then((_) => ref.invalidate(menuItemsProvider)),
                ),
                _divider(),
                _actionButton(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, itemId, isRestaurant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.background,
      child: const Icon(Icons.image_outlined,
          color: AppColors.textLight, size: 32),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.textLight.withOpacity(0.1));
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String itemId, bool isRestaurant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(menuRepositoryProvider);
              if (isRestaurant) {
                await repo.deleteFoodItem(itemId);
              } else {
                await repo.deleteGroceryItem(itemId);
              }
              ref.invalidate(menuItemsProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
