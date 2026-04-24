# Food Delivery App 🍕

A premium Flutter food delivery mobile application with real-time order tracking, social authentication, and beautiful Material 3 design.

## Features ✨

### Authentication
- 🔐 Email/Password sign up and sign in
- 🔑 Google Sign-In integration
- 🍎 Apple Sign-In integration
- 🔄 Automatic session management

### Restaurant Browsing
- 🏪 Beautiful restaurant cards with images
- ⭐ Ratings and reviews
- 🔍 Search functionality
- 🏷️ Category filters
- ⏱️ Delivery time estimates
- 💰 All prices in DT (Tunisian Dinar)

### Menu & Ordering
- 📋 Detailed menu with categories
- 🖼️ High-quality food images
- 🌱 Dietary indicators (vegetarian, etc.)
- ➕ Add to cart with quantity selector
- 🛒 Shopping cart with item management

### Checkout
- 📍 GPS-based current location
- 🏠 Saved addresses management
- ➕ Add new addresses manually
- 💵 Cash on Delivery payment
- 📝 Order notes

### Order Tracking
- 🗺️ Real-time Google Maps integration
- 📍 Live driver location tracking
- 📊 Order status timeline
- 👤 Driver information
- ⏰ Estimated delivery time
- 📱 Contact driver option

## Setup Instructions 🚀

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode
- Firebase account
- Google Maps API key

### 1. Clone and Install Dependencies

```bash
cd cmandili_mobile
flutter pub get
```

### 2. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication with Email/Password, Google, and Apple
3. Enable Cloud Firestore
4. Run FlutterFire CLI:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

This will create `firebase_options.dart` automatically.

### 3. Google Maps Setup

#### Android
1. Get an API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Maps SDK for Android
3. Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
    </application>
</manifest>
```

#### iOS
1. Enable Maps SDK for iOS
2. Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

3. Add to `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

### 4. Google Sign-In Setup

#### Android
- Download `google-services.json` from Firebase Console
- Place in `android/app/`

#### iOS
- Download `GoogleService-Info.plist` from Firebase Console
- Add to `ios/Runner/` via Xcode

### 5. Apple Sign-In Setup (iOS only)

1. Enable Sign in with Apple in Xcode capabilities
2. Configure in Firebase Console

### 6. Run the App

```bash
# Run on Android
flutter run

# Run on iOS
flutter run -d ios

# Build release
flutter build apk  # Android
flutter build ios  # iOS
```

## Project Structure 📁

```
lib/
├── core/
│   ├── theme/              # App theme and colors
│   ├── router/             # Navigation
│   └── utils/              # Utilities (currency, location)
├── features/
│   ├── auth/               # Authentication
│   ├── home/               # Restaurant listing
│   ├── restaurant/         # Restaurant details & menu
│   ├── cart/               # Shopping cart
│   ├── checkout/           # Checkout & address
│   └── orders/             # Order tracking
└── main.dart
```

## Technologies Used 🛠️

- **Flutter** - UI framework
- **Riverpod** - State management
- **Firebase Auth** - Authentication
- **Cloud Firestore** - Database
- **Google Maps** - Maps integration
- **Geolocator** - Location services
- **Cached Network Image** - Image optimization
- **Material 3** - Design system

## Currency 💵

All prices are displayed in **DT (Tunisian Dinar)** using proper formatting.

## Screenshots 📱

The app features:
- Vibrant orange/red food-themed color palette
- Smooth animations and transitions
- Premium Material 3 design
- Dark mode support
- Responsive layouts

## Notes 📝

- Mock data is used for restaurants and menu items
- Real-time order tracking simulates driver movement
- Firebase configuration required for authentication
- Google Maps API key required for map features

## Future Enhancements 🚧

- Order history screen
- User profile management
- Push notifications
- Multiple payment methods
- Restaurant reviews
- Favorites/Wishlist
- Promo codes and discounts

## License 📄

This project is created for demonstration purposes.
