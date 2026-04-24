enum GroceryCategory {
  vegetables,
  fruits,
  dairy,
  meat,
  seafood,
  bakery,
  frozen,
  beverages,
  snacks,
  condiments,
  grains,
  cleaning,
  personalCare,
  babyProducts,
  other;

  String get nameEn {
    switch (this) {
      case GroceryCategory.vegetables: return 'Vegetables';
      case GroceryCategory.fruits: return 'Fruits';
      case GroceryCategory.dairy: return 'Dairy';
      case GroceryCategory.meat: return 'Meat';
      case GroceryCategory.seafood: return 'Seafood';
      case GroceryCategory.bakery: return 'Bakery';
      case GroceryCategory.frozen: return 'Frozen';
      case GroceryCategory.beverages: return 'Beverages';
      case GroceryCategory.snacks: return 'Snacks';
      case GroceryCategory.condiments: return 'Condiments';
      case GroceryCategory.grains: return 'Grains';
      case GroceryCategory.cleaning: return 'Cleaning';
      case GroceryCategory.personalCare: return 'Personal Care';
      case GroceryCategory.babyProducts: return 'Baby Products';
      case GroceryCategory.other: return 'Other';
    }
  }
}
