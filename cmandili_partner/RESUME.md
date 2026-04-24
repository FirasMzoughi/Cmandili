# Project Resume: Cmandili Mobile

This document provides a comprehensive overview of the `cmandili_mobile` project, detailing every file, class, and function within the `lib` directory.

## Directory Structure

- `lib/`
    - `main.dart`: Entry point of the application.
    - `core/`: Core utilities, configurations, and shared logic.
    - `features/`: Feature-specific modules.
    - `l10n/`: Localization files.

---

## Detailed File Analysis

### `lib/main.dart`
**Description**: Entry point of the application.
**Key Components**:
- `main()`: Initializes Supabase, waits for 1 second (mock init), and runs `MyApp`.
- `MyApp`: The root widget.
    - Sets up `ProviderScope` for Riverpod.
    - Configures `MaterialApp` with `AppTheme`, `AppLocalizations`, and routing.
    - Monitors `authStateProvider` to decide between `HomeScreen` and `AuthScreen`.

---

## Directory: `lib/core/`

### `core/config/`
- **`supabase_config.dart`**:
  - `SupabaseConfig`: Static class holding Supabase URL and Anonymous Key.

### `core/models/`
- **`service_category.dart`**:
  - `ServiceType`: Enum for service types (foodDelivery, supermarket, bills, courier).
  - `ServiceCategory`: Model class defining a service category with localized names, icon, and color.
  - Contains a static list `categories` with predefined services.

### `core/providers/`
- **`localization_provider.dart`**:
  - `localizationProvider`: StateNotifierProvider for managing app locale.
  - `LocalizationNotifier`: Persists language selection to SharedPreferences.
- **`service_provider.dart`**:
  - `selectedServiceProvider`: StateNotifierProvider for managing the currently selected `ServiceType`.
- **`theme_provider.dart`**:
  - `themeProvider`: StateNotifierProvider for managing `ThemeMode` (light/dark).
  - `ThemeNotifier`: Persists theme selection to SharedPreferences.

### `core/router/`
- **`app_router.dart`**:
  - `AppRouter`: Configures `GoRouter` with routes:
    - `/auth`: `AuthScreen`
    - `/home`: `HomeScreen`
    - `/cart`: `CartScreen`

### `core/theme/`
- **`app_colors.dart`**:
  - `AppColors`: Defines the application's color palette (primary, secondary, gradients, etc.).
- **`app_theme.dart`**:
  - `AppTheme`: Defines `lightTheme` and `darkTheme` `ThemeData` configurations.

### `core/utils/`
- **`currency_formatter.dart`**:
  - `CurrencyFormatter`: Static methods to format prices (`formatPrice`, `formatPriceCompact`).
- **`location_service.dart`**:
  - `LocationService`: Wrapper around `geolocator` and `geocoding` packages.
    - `getCurrentPosition`: Gets current coordinates.
    - `getAddressFromCoordinates`: Reverse geocoding.
    - `getCoordinatesFromAddress`: Forward geocoding.
    - `calculateDistance`: Calculates distance between points.
    - `_AddAddressSheet`: Form to add a new address manually.

### `features/orders/`
#### `data/`
- **`order_repository.dart`**:
  - `OrderRepository`: Manages order lifecycle.
    - `createOrder`: Transactional creation of order and order items in Supabase.
    - `streamOrder`: Streams real-time order updates by ID.
    - `getUserOrders`: Fetches history.
    - `updateOrderStatus`: Updates status (e.g., pending -> confirmed).
- **`models/`**:
  - `order.dart`: Comprehensive `Order` model.
    - Enums: `OrderStatus` (pending, onTheWay, delivered, etc.), `OrderType` (food, supermarket, courier).
    - Properties for driver info, tracking coordinates, and recipient details (for courier).

#### `presentation/`
- **`order_tracking_screen.dart`**:
  - `OrderTrackingScreen`: Real-time order tracking UI.
  - Features:
    - `GoogleMap` displaying delivery path, driver location, and pickup point.
    - Simulation logic (`_simulateOrderProgress`) to update status and mock driver movement.
    - Draggable bottom sheet with order status timeline (`_OrderTimeline`) and driver details.
    - Courier specific: "Simulate Recipient Acceptance" button.

#### `providers/`
- **`order_provider.dart`**:
  - `orderStreamProvider`: StreamProvider for a specific order.
  - `userOrdersProvider`: FutureProvider for order history.

### `features/profile/`
#### `presentation/`
- **`profile_screen.dart`**:
  - `ProfileScreen`: Main user hub.
  - Navigation to: Edit Profile, Addresses, Payment, Notifications, Language, Theme, Help.
- **`edit_profile_screen.dart`**:
  - `EditProfileScreen`: Form to edit name, phone, bio. (Mock implementation).
- **`saved_addresses_screen.dart`**:
  - `SavedAddressesScreen`: List of `DeliveryAddress`. Supports Add/Delete/Set Default.
- **`payment_methods_screen.dart`**:
  - `PaymentMethodsScreen`: Manages credit cards. UI for adding/removing cards.
- **`help_support_screen.dart`**:
  - `HelpSupportScreen`: Form to submit support tickets.

### `features/favorites/`
#### `presentation/`
- **`favorites_screen.dart`**:
  - `FavoritesScreen`: Displays list of favorite restaurants.
#### `providers/`
- **`favorites_provider.dart`**:
  - `FavoritesNotifier`: StateNotifier for managing favorite list (in-memory).

### `features/notifications/`
#### `data/models/`
- **`notification.dart`**:
  - `AppNotification`: Model for system/order notifications.
#### `presentation/`
- **`notification_screen.dart`**:
  - `NotificationScreen`: Lists notifications grouped by date (Today, Yesterday, etc.).
  - Supports "Mark all as read" and swipe-to-dismiss.

### `l10n/`
- Contains ARB files (`app_en.arb`, `app_ar.arb`, `app_fr.arb`) and generated localization classes for English, Arabic, and French support.

---

## Directory: `lib/features/`

### `features/auth/`
#### `data/`
- **`auth_repository.dart`**:
  - `User`: Custom user class adapting Supabase user.
  - `AuthRepository`: Handles authentication via Supabase and Google Sign-In.
    - `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signOut`.
    - Exposes `authStateChanges` stream.
  - **Note**: `features/auth/data/models/user_model.dart` appears to be missing, despite generated files existing. The repository uses an internal `User` class.

#### `presentation/`
- **`auth_screen.dart`**:
  - `AuthScreen`: Login/Signup screen with complex animations (fade, slide, rotate).
  - Features a tab view for Sign In vs Sign Up.
  - Handles social login (Google/Apple) and email/password authentication.
  - Includes language switcher and animated background.

#### `providers/`
- **`auth_provider.dart`**:
  - `authRepositoryProvider`: Provides `AuthRepository`.
  - `authStateProvider`: Stream provider for current user state.

### `features/home/`
#### `presentation/`
- **`home_screen.dart`**:
  - `HomeScreen`: Main dashboard with `IndexedStack` for bottom navigation (Home, Favorites, Cart, Profile).
  - `_buildHomeContent`: Displays content based on selected service (`ServiceType`).
    - **Food Delivery**: Shows horizontal categories and popular restaurants list.
    - **Supermarket**: Shows `SupermarketListScreen`.
    - **Bills**: Shows `BillPaymentScreen` (or placeholder).
    - **Courier**: Shows `CourierScreen`.
  - Includes "Happy Hour" banner and notification badge logic.
- **`widgets/service_selector.dart`**:
  - `ServiceSelector`: Widget to select between services (Food, Supermarket, etc.).
  - Uses `ServiceCategory.categories` to render cards with icons and labels.
  - Handles selection via `selectedServiceProvider`.
- **`widgets/bills_placeholder.dart`**:
  - `BillsPlaceholder`: "Coming Soon" placeholder for bill payments.
- **`widgets/supermarket_placeholder.dart`**:
  - `SupermarketPlaceholder`: "Coming Soon" placeholder for supermarket (though `home_screen.dart` seems to use `SupermarketListScreen` now).

#### `data/models/`
- **`restaurant.dart`**:
  - `Restaurant`: Data model for a restaurant.
  - Fields: `id`, `name`, `description`, `imageUrl`, `rating`, `reviewCount`, `deliveryTime`, `deliveryFee`, `minimumOrder`, `categories`, `isOpen`, `latitude`, `longitude`.
  - Includes `fromJson` and `toJson`.

### `features/supermarket/`
#### `data/`
- **`supermarket_repository.dart`**:
  - `SupermarketRepository`: Fetches supermarkets and grocery items from Supabase.
    - `getSupermarkets`: Selects all supermarkets, ordered by creation date.
    - `getGroceryItems`: Selects items for a supermarket.
    - Maps DB JSON to domain models.
- **`models/`**:
  - `grocery_category.dart`: Enum `GroceryCategory` with localized names (English, Arabic, French) and icons.
  - `grocery_item.dart`: Model for grocery items (price, discount, organic status, unit, etc.).
  - `supermarket.dart`: Model for supermarket entity (delivery time, rating, location).

#### `presentation/`
- **`supermarket_list_screen.dart`**:
  - `SupermarketListScreen`: Displays a list of supermarkets using a `FutureProvider`.
  - `_SupermarketCard`: Visual card with image, delivery time, rating, and status.
- **`supermarket_detail_screen.dart`**:
  - `SupermarketDetailScreen`: Detailed view of a supermarket.
  - Features:
    - SilverAppBar with image.
    - Horizontal category filter chip list.
    - Grid of grocery items.
    - `_ProductCard`: Shows item image, organic badge, price, and add-to-cart button.
    - Shopping cart floating action button.

#### `providers/`
- **`supermarket_provider.dart`**:
  - `supermarketRepositoryProvider`: Provider for the repository.
  - `supermarketsProvider`: FutureProvider for fetching all supermarkets.
  - `groceryItemsProvider`: Family FutureProvider for fetching items by supermarket ID.

### `features/cart/`
#### `data/models/`
- **`cart_item.dart`**:
  - `CartItem`: Wrapper model that can hold either a `FoodItem` (restaurant) or `GroceryItem` (supermarket).
  - Handles quantity, special instructions, and `OrderCustomization`.
  - Calculates `totalPrice` based on type and discounts.
- **`order_customization.dart`**:
  - `OrderCustomization`: Model for voice or text instructions (`CustomizationType`).
  - Stores content (text or audio path) and formatted duration.

#### `presentation/`
- **`cart_screen.dart`**:
  - `CartScreen`: Displays items in the cart.
  - `_CartItemCard`: Shows item image, details, quantity controls, and customization button.
  - `_SummaryRow`: Displays subtotal, delivery fee, and total.
  - `Checkout` button navigates to `CheckoutScreen`.
  - `_EmptyCart`: UI for empty state.
- **`widgets/order_customization_widget.dart`**:
  - `OrderCustomizationWidget`: Modal bottom sheet for adding instructions.
  - Supports Text input.
  - Supports Voice recording using `flutter_sound`.
  - Handles permissions and audio playback/recording UI with animations.

#### `providers/`
- **`cart_provider.dart`**:
  - `CartNotifier`: StateNotifier managing list of `CartItem`.
    - `addItem`: Adds item or updates quantity if exists.
    - `removeItem`: Removes item by ID.
    - `updateQuantity`: Updates quantity or removes if <= 0.
    - `clearCart`: Clears all items.
  - `cartProvider`: Exposes the item list.
  - `cartSubtotalProvider`, `cartItemCountProvider`, `cartTotalProvider`: Derived providers for calculations.

### `features/restaurant/`
#### `data/`
- **`restaurant_repository.dart`**:
  - `RestaurantRepository`: Fetches `restaurants` and `food_items` from Supabase.
    - `getRestaurants`: Returns list of restaurants.
    - `getFoodItems`: Returns menu items for a specific restaurant.
- **`models/`**:
  - `food_item.dart`: Model for menu items (`FoodItem`). Includes attributes like `isVegetarian`, `isSpicy`, `preparationTime`.

#### `presentation/`
- **`restaurant_detail_screen.dart`**:
  - `RestaurantDetailScreen`: Comprehensive restaurant view.
  - Features:
    - Parallax header with restaurant image and gradient overlay.
    - Sticky header for category navigation (e.g., Pizza, Salads).
    - `_FoodItemCard`: Displays food item with image, description, price, and add button.
    - `_FoodItemDialog`: Bottom sheet to select quantity and add to cart.
    - Floating action button showing cart total and item count, linking to `CartScreen`.

#### `providers/`
- **`restaurant_provider.dart`**:
  - `restaurantsProvider`: FutureProvider for all restaurants.
  - `foodItemsProvider`: Family FutureProvider for fetching menu by restaurant ID.

### `features/checkout/`
#### `data/models/`
- **`delivery_address.dart`**:
  - `DeliveryAddress`: Model for user addresses (label, coordinates, defaults).

#### `presentation/`
- **`checkout_screen.dart`**:
  - `CheckoutScreen`: Final step before placing an order.
  - Features:
    - Address selection via `AddressSelectionScreen`.
    - Payment method selection (currently Mocked/Cash on Delivery).
    - Order notes text field.
    - Order summary (subtotal, fee, total).
    - `_placeOrder`: Creates `Order` object, clears cart, and navigates to `OrderTrackingScreen`.
- **`address_selection_screen.dart`**:
  - `AddressSelectionScreen`: Manages delivery addresses.
  - Features:
    - Lists saved addresses (Mocked list `_savedAddresses`).
    - `_useCurrentLocation`: Uses `LocationService` to get current position.
    - `_AddAddressSheet`: Form to add a new address manually.
