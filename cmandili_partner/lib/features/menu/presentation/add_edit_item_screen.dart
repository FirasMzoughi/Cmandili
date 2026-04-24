import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/food_item.dart';
import '../data/models/grocery_item.dart';
import '../data/models/grocery_category.dart';

class AddEditItemScreen extends ConsumerStatefulWidget {
  final FoodItem? existingFoodItem;
  final GroceryItem? existingGroceryItem;
  final String partnerType;

  const AddEditItemScreen({
    super.key,
    this.existingFoodItem,
    this.existingGroceryItem,
    required this.partnerType,
  });

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _imageUrlController;
  late TextEditingController _prepTimeController;
  late TextEditingController _unitController;

  bool _isAvailable = true;
  bool _isVegetarian = false;
  bool _isSpicy = false;
  bool _isOrganic = false;
  bool _isLoading = false;
  GroceryCategory _selectedGroceryCategory = GroceryCategory.vegetables;

  File? _imageFile;
  final _picker = ImagePicker();

  bool get _isRestaurant => widget.partnerType == 'restaurant';
  bool get _isEditing =>
      widget.existingFoodItem != null || widget.existingGroceryItem != null;

  @override
  void initState() {
    super.initState();
    final fi = widget.existingFoodItem;
    final gi = widget.existingGroceryItem;

    _nameController = TextEditingController(text: fi?.name ?? gi?.name ?? '');
    _descController =
        TextEditingController(text: fi?.description ?? gi?.description ?? '');
    _priceController = TextEditingController(
        text: (fi?.price ?? gi?.price)?.toStringAsFixed(2) ?? '');
    _categoryController =
        TextEditingController(text: fi?.category ?? '');
    _imageUrlController =
        TextEditingController(text: fi?.imageUrl ?? gi?.imageUrl ?? '');
    _prepTimeController = TextEditingController(
        text: fi?.preparationTime.toString() ?? '15');
    _unitController = TextEditingController(text: gi?.unit ?? 'piece');

    _isAvailable = fi?.isAvailable ?? gi?.isAvailable ?? true;
    _isVegetarian = fi?.isVegetarian ?? false;
    _isSpicy = fi?.isSpicy ?? false;
    _isOrganic = gi?.isOrganic ?? false;

    if (gi != null) _selectedGroceryCategory = gi.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      if (mounted) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRestaurant && _categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify a category.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error)
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(menuRepositoryProvider);
    final profile = await ref.read(partnerProfileProvider.future);
    bool ok = false;
    
    // Upload Image if selected
    if (_imageFile != null) {
      final ext = _imageFile!.path.split('.').last;
      String path = '${const Uuid().v4()}.$ext';
      final url = await repo.uploadItemImage(path, _imageFile!);
      if (url != null) {
        _imageUrlController.text = url;
      }
    }

    if (_isRestaurant) {
      final item = FoodItem(
        id: widget.existingFoodItem?.id ?? const Uuid().v4(),
        restaurantId: profile?.entityId ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        price: double.parse(_priceController.text),
        category: _categoryController.text.trim(),
        isAvailable: _isAvailable,
        preparationTime: int.tryParse(_prepTimeController.text) ?? 15,
        isVegetarian: _isVegetarian,
        isSpicy: _isSpicy,
      );
      if (_isEditing) {
        ok = await repo.updateFoodItem(item);
      } else {
        final id = await repo.addFoodItem(item, profile?.entityId ?? '');
        ok = id != null;
      }
    } else {
      final item = GroceryItem(
        id: widget.existingGroceryItem?.id ?? const Uuid().v4(),
        supermarketId: profile?.entityId ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        price: double.parse(_priceController.text),
        category: _selectedGroceryCategory,
        unit: _unitController.text.trim(),
        isOrganic: _isOrganic,
        isAvailable: _isAvailable,
      );
      if (_isEditing) {
        ok = await repo.updateGroceryItem(item);
      } else {
        final id = await repo.addGroceryItem(item, profile?.entityId ?? '');
        ok = id != null;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ref.invalidate(menuItemsProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Item updated!' : 'Item added!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit ${_isRestaurant ? "Dish" : "Product"}'
            : 'Add ${_isRestaurant ? "Dish" : "Product"}'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Text('Save',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionLabel('Basic Information'),
            const SizedBox(height: 10),
            _field(_nameController, 'Name',
                Icons.label_outline_rounded, required: true),
            const SizedBox(height: 14),
            _field(_descController, 'Description',
                Icons.description_outlined,
                maxLines: 3, required: true),
            const SizedBox(height: 14),
            _field(_priceController, 'Price (DT)',
                Icons.payments_outlined,
                inputType: const TextInputType.numberWithOptions(decimal: true),
                required: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a price';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                }),
            const SizedBox(height: 14),
            _imagePickerCustom(),
            const SizedBox(height: 24),

            _sectionLabel('Category'),
            const SizedBox(height: 10),
            if (_isRestaurant)
              _buildCategorySelector()
            else
              _groceryCategoryDropdown(),

            const SizedBox(height: 24),
            _sectionLabel(_isRestaurant ? 'Dish Details' : 'Product Details'),
            const SizedBox(height: 10),

            if (_isRestaurant)
              _field(_prepTimeController, 'Preparation Time (minutes)',
                  Icons.timer_outlined,
                  inputType: TextInputType.number),

            if (!_isRestaurant) ...[
              _field(_unitController, 'Unit (kg, piece, liter…)',
                  Icons.scale_outlined),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 14),
            _switchTile('Available', 'Show this item to customers',
                Icons.visibility_outlined, _isAvailable,
                (v) => setState(() => _isAvailable = v)),

            if (_isRestaurant) ...[
              const Divider(height: 1),
              _switchTile('Vegetarian', 'Mark as vegetarian',
                  Icons.eco_outlined, _isVegetarian,
                  (v) => setState(() => _isVegetarian = v)),
              const Divider(height: 1),
              _switchTile('Spicy', 'Mark as spicy',
                  Icons.local_fire_department_outlined, _isSpicy,
                  (v) => setState(() => _isSpicy = v)),
            ],

            if (!_isRestaurant) ...[
              const Divider(height: 1),
              _switchTile('Organic', 'Mark as organic product',
                  Icons.eco_outlined, _isOrganic,
                  (v) => setState(() => _isOrganic = v)),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEditing ? 'Update Item' : 'Add Item',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool required = false,
    TextInputType? inputType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textLight.withOpacity(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null),
    );
  }

  // ── Default restaurant categories with emojis ──
  static const List<Map<String, String>> _defaultRestaurantCategories = [
    {'name': 'Starters', 'icon': '🥗'},
    {'name': 'Mains', 'icon': '🍽️'},
    {'name': 'Pizza', 'icon': '🍕'},
    {'name': 'Burgers', 'icon': '🍔'},
    {'name': 'Pasta', 'icon': '🍝'},
    {'name': 'Grills', 'icon': '🥩'},
    {'name': 'Seafood', 'icon': '🦐'},
    {'name': 'Salads', 'icon': '🥬'},
    {'name': 'Soups', 'icon': '🍲'},
    {'name': 'Sandwiches', 'icon': '🥪'},
    {'name': 'Desserts', 'icon': '🍰'},
    {'name': 'Drinks', 'icon': '🥤'},
    {'name': 'Breakfast', 'icon': '🍳'},
    {'name': 'Kids Menu', 'icon': '🧒'},
  ];

  // Keep track of user-created custom categories
  final List<Map<String, String>> _customCategories = [];
  String? _selectedCategoryIcon;

  Widget _buildCategorySelector() {
    final hasCategory = _categoryController.text.isNotEmpty;
    return GestureDetector(
      onTap: () => _showCategoryBottomSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCategory
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.textLight.withOpacity(0.15),
            width: hasCategory ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            if (hasCategory && _selectedCategoryIcon != null) ...[
              Text(_selectedCategoryIcon!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
            ] else ...[
              const Icon(Icons.category_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                hasCategory ? _categoryController.text : 'Tap to select a category',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasCategory ? FontWeight.w600 : FontWeight.w400,
                  color: hasCategory ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet() {
    // Build merged list: default + custom + any unique ones from existing items
    final itemsAsync = ref.read(menuItemsProvider);
    List<Map<String, String>> allCategories = [..._defaultRestaurantCategories, ..._customCategories];
    
    if (itemsAsync is AsyncData) {
      final items = itemsAsync.value ?? [];
      final existingNames = items
          .whereType<FoodItem>()
          .map((e) => e.category)
          .where((c) => c.isNotEmpty)
          .toSet();
      // Add any existing-in-DB categories that aren't in our list already
      for (final name in existingNames) {
        if (!allCategories.any((c) => c['name'] == name)) {
          allCategories.add({'name': name, 'icon': '📁'});
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: allCategories.length + 1, // +1 for "Add New"
                itemBuilder: (context, index) {
                  if (index == allCategories.length) {
                    // "Add New Category" card
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddCategoryDialog();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(height: 8),
                            const Text('Add New',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                    );
                  }

                  final cat = allCategories[index];
                  final isSelected = _categoryController.text == cat['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _categoryController.text = cat['name']!;
                        _selectedCategoryIcon = cat['icon'];
                      });
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.textLight.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            cat['name']!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 4),
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    
    // Emojis the user can pick for their new category
    const emojiOptions = ['🍽️', '🍕', '🍔', '🌮', '🍜', '🍣', '🥘', '🍱', '🧆', '🥙', '🍗', '🍖',
                          '🥐', '🍩', '🍦', '☕', '🧃', '🍹', '🥗', '🧁', '🫕', '🥨', '🌯', '📁'];
    String selectedEmoji = '🍽️';
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Category', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Tacos, Bowls…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choose an Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojiOptions.map((emoji) {
                  final isSelected = selectedEmoji == emoji;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedEmoji = emoji),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  _customCategories.add({'name': name, 'icon': selectedEmoji});
                  _categoryController.text = name;
                  _selectedCategoryIcon = selectedEmoji;
                });
                Navigator.pop(ctx);
                Navigator.pop(context); // close bottom sheet too
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerCustom() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textLight.withOpacity(0.15),
            width: 1.5,
          ),
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : (_imageUrlController.text.isNotEmpty && _imageUrlController.text.startsWith('http'))
                  ? DecorationImage(
                      image: NetworkImage(_imageUrlController.text),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: (_imageFile == null && _imageUrlController.text.isEmpty)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 40),
                  SizedBox(height: 8),
                  Text('Tap to upload dish picture', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _groceryCategoryDropdown() {
    return DropdownButtonFormField<GroceryCategory>(
      value: _selectedGroceryCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined,
            color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textLight.withOpacity(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: GroceryCategory.values
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.nameEn),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedGroceryCategory = v);
      },
    );
  }

  Widget _switchTile(String title, String subtitle, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      secondary: Icon(icon, color: AppColors.textSecondary, size: 22),
      contentPadding: EdgeInsets.zero,
    );
  }
}
