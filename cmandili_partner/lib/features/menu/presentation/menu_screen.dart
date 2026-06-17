import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/food_item.dart';
import '../data/models/grocery_item.dart';
import 'add_edit_item_screen.dart';
import 'happy_hour_setup_screen.dart';
import '../providers/menu_scanner_provider.dart';
import 'package:image_picker/image_picker.dart';

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
    final l = AppLocalizations.of(context)!;

    ref.listen<MenuScannerState>(menuScannerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.scanMenuError}: ${next.error}'), backgroundColor: AppColors.error),
        );
      } else if (next.itemsAddedCount != null && next.itemsAddedCount != previous?.itemsAddedCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.scanMenuSuccess} (${next.itemsAddedCount} items)'), backgroundColor: Colors.green),
        );
      }
    });

    final scannerState = ref.watch(menuScannerProvider);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                tooltip: l.scanMenu,
                onPressed: scannerState.isLoading
                    ? null
                    : () => _showImageSourceBottomSheet(context, ref),
              ),
              const SizedBox(width: 8),
            ],
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
                          isRestaurant ? l.menu : l.products,
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
                              ? l.manageDishesHappyHour
                              : l.manageProductsHappyHour,
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
                  hintText: l.searchItems,
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
                        _categoryChip(null, l.all, selectedCategory),
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
                              ? '${l.noItemsMatch} "$_searchQuery"'
                              : l.noItemsYet,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.tapToAddFirst,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: scannerState.isLoading
                                ? null
                                : () => _showImageSourceBottomSheet(context, ref),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text(l.scanMenuEmptyState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
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
                  l.couldNotLoadItems,
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
      if (scannerState.isLoading)
        Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    l.scanMenuLoading,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
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
          'Add ${profileAsync.value?.partnerType == "restaurant" ? l.addDish : l.addProduct}',
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

  void _showImageSourceBottomSheet(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text(l.takePhoto, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(menuScannerProvider.notifier).scanPhysicalMenu(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                title: Text(l.chooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(menuScannerProvider.notifier).scanPhysicalMenu(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends ConsumerStatefulWidget {
  final dynamic item;
  final bool isRestaurant;
  final String partnerType;

  const _MenuItemCard({
    required this.item,
    required this.isRestaurant,
    required this.partnerType,
  });

  @override
  ConsumerState<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends ConsumerState<_MenuItemCard> {
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _initAvailability();
  }

  @override
  void didUpdateWidget(covariant _MenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _initAvailability();
    }
  }

  void _initAvailability() {
    final fi = widget.item is FoodItem ? widget.item as FoodItem : null;
    final gi = widget.item is GroceryItem ? widget.item as GroceryItem : null;
    _isAvailable = fi?.isAvailable ?? gi?.isAvailable ?? true;
  }

  Future<void> _toggleAvailability(bool value) async {
    final previousState = _isAvailable;
    
    // 1. Optimistic update
    setState(() => _isAvailable = value);

    final isFood = widget.item is FoodItem;
    final isGrocery = widget.item is GroceryItem;
    
    final itemId = isFood ? (widget.item as FoodItem).id : 
                   isGrocery ? (widget.item as GroceryItem).id : '';

    if (itemId.isEmpty) {
      if (mounted) {
        setState(() => _isAvailable = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur: ID introuvable', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // 2. Call backend
      final repo = ref.read(menuRepositoryProvider);
      final success = await repo.updateItemAvailability(
        itemId, 
        value, 
        isGrocery: isGrocery,
      );

      // 3. Handle failure (Rollback)
      if (!success) {
        if (mounted) {
          setState(() => _isAvailable = previousState);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur: Impossible de mettre à jour la disponibilité', style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else {
        // Background silent refresh for global state
        ref.invalidate(menuItemsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAvailable = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fi = widget.item is FoodItem ? widget.item as FoodItem : null;
    final gi = widget.item is GroceryItem ? widget.item as GroceryItem : null;

    final name = fi?.name ?? gi?.name ?? '';
    final price = fi?.price ?? gi?.price ?? 0.0;
    final imageUrl = fi?.imageUrl ?? gi?.imageUrl ?? '';
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
                                  Text(l.happyHourBadge,
                                      style: const TextStyle(
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
                  value: _isAvailable,
                  activeColor: AppColors.primary,
                  onChanged: _toggleAvailability,
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
                  label: l.edit,
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditItemScreen(
                        partnerType: widget.partnerType,
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
                  label: l.happyHour,
                  color: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HappyHourSetupScreen(
                        itemId: itemId,
                        itemName: name,
                        originalPrice: price,
                        isGrocery: !widget.isRestaurant,
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
                  label: l.deleteAction,
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, itemId, widget.isRestaurant),
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
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.deleteItem,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(l.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
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
            child: Text(l.deleteAction,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
