import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cmandili Partner'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @pleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter your {field}'**
  String pleaseEnter(Object field);

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get validEmail;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordLength;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @notificationsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Notifications will appear here'**
  String get notificationsWillAppearHere;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// No description provided for @menuManagement.
  ///
  /// In en, this message translates to:
  /// **'Menu Management'**
  String get menuManagement;

  /// No description provided for @incomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming Orders'**
  String get incomingOrders;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @reportsAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Reports & Analytics'**
  String get reportsAnalytics;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @successRate.
  ///
  /// In en, this message translates to:
  /// **'Success Rate'**
  String get successRate;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @couldNotLoadReports.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports'**
  String get couldNotLoadReports;

  /// No description provided for @partnerOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Partner Onboarding'**
  String get partnerOnboarding;

  /// No description provided for @businessType.
  ///
  /// In en, this message translates to:
  /// **'Business Type'**
  String get businessType;

  /// No description provided for @restaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get restaurant;

  /// No description provided for @supermarket.
  ///
  /// In en, this message translates to:
  /// **'Supermarket'**
  String get supermarket;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @happyHour.
  ///
  /// In en, this message translates to:
  /// **'Happy Hour'**
  String get happyHour;

  /// No description provided for @setHappyHourPromotion.
  ///
  /// In en, this message translates to:
  /// **'Set Happy Hour Promotion'**
  String get setHappyHourPromotion;

  /// No description provided for @discountPercentage.
  ///
  /// In en, this message translates to:
  /// **'Discount Percentage'**
  String get discountPercentage;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @itemPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get itemPrice;

  /// No description provided for @itemCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get itemCategory;

  /// No description provided for @itemDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get itemDescription;

  /// No description provided for @isAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get isAvailable;

  /// No description provided for @itemImage.
  ///
  /// In en, this message translates to:
  /// **'Item Image'**
  String get itemImage;

  /// No description provided for @addToMenu.
  ///
  /// In en, this message translates to:
  /// **'Add to Menu'**
  String get addToMenu;

  /// No description provided for @updateItem.
  ///
  /// In en, this message translates to:
  /// **'Update Item'**
  String get updateItem;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get confirmDeleteMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @couldNotLoadMenu.
  ///
  /// In en, this message translates to:
  /// **'Could not load menu items'**
  String get couldNotLoadMenu;

  /// No description provided for @completeSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get completeSetup;

  /// No description provided for @welcomeExclamation.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeExclamation;

  /// No description provided for @provideBusinessDetails.
  ///
  /// In en, this message translates to:
  /// **'Please provide your business details to continue.'**
  String get provideBusinessDetails;

  /// No description provided for @revenueToday.
  ///
  /// In en, this message translates to:
  /// **'Revenue Today'**
  String get revenueToday;

  /// No description provided for @couldNotLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Could not load stats'**
  String get couldNotLoadStats;

  /// No description provided for @avgPrep.
  ///
  /// In en, this message translates to:
  /// **'Avg Prep'**
  String get avgPrep;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @shopOpen.
  ///
  /// In en, this message translates to:
  /// **'Shop is Open — accepting orders'**
  String get shopOpen;

  /// No description provided for @shopClosed.
  ///
  /// In en, this message translates to:
  /// **'Shop is Closed — not accepting orders'**
  String get shopClosed;

  /// No description provided for @activeOrders.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrders;

  /// No description provided for @noActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'No active orders'**
  String get noActiveOrders;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @newMenu.
  ///
  /// In en, this message translates to:
  /// **'New Menu'**
  String get newMenu;

  /// No description provided for @promos.
  ///
  /// In en, this message translates to:
  /// **'Promos'**
  String get promos;

  /// No description provided for @partnerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Partner Dashboard'**
  String get partnerDashboard;

  /// No description provided for @manageDishesHappyHour.
  ///
  /// In en, this message translates to:
  /// **'Manage your dishes and set happy hour deals'**
  String get manageDishesHappyHour;

  /// No description provided for @manageProductsHappyHour.
  ///
  /// In en, this message translates to:
  /// **'Manage your products and set happy hour deals'**
  String get manageProductsHappyHour;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items…'**
  String get searchItems;

  /// No description provided for @noItemsMatch.
  ///
  /// In en, this message translates to:
  /// **'No items match'**
  String get noItemsMatch;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get noItemsYet;

  /// No description provided for @tapToAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first item'**
  String get tapToAddFirst;

  /// No description provided for @couldNotLoadItems.
  ///
  /// In en, this message translates to:
  /// **'Could not load items.\nCheck your connection.'**
  String get couldNotLoadItems;

  /// No description provided for @addDish.
  ///
  /// In en, this message translates to:
  /// **'Add Dish'**
  String get addDish;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @happyHourBadge.
  ///
  /// In en, this message translates to:
  /// **'HH'**
  String get happyHourBadge;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @selectEndDateTime.
  ///
  /// In en, this message translates to:
  /// **'Please select an end date & time'**
  String get selectEndDateTime;

  /// No description provided for @happyHourActivated.
  ///
  /// In en, this message translates to:
  /// **'Happy Hour activated! Customers can now see this deal.'**
  String get happyHourActivated;

  /// No description provided for @happyHourFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to activate Happy Hour. Try again.'**
  String get happyHourFailed;

  /// No description provided for @happyHourCleared.
  ///
  /// In en, this message translates to:
  /// **'Happy Hour cleared.'**
  String get happyHourCleared;

  /// No description provided for @happyHourSetup.
  ///
  /// In en, this message translates to:
  /// **'Happy Hour Setup'**
  String get happyHourSetup;

  /// No description provided for @discountPriceDt.
  ///
  /// In en, this message translates to:
  /// **'Discount Price (DT)'**
  String get discountPriceDt;

  /// No description provided for @endDateTime.
  ///
  /// In en, this message translates to:
  /// **'End Date & Time'**
  String get endDateTime;

  /// No description provided for @tapSelectEndDateTime.
  ///
  /// In en, this message translates to:
  /// **'Tap to select end date & time'**
  String get tapSelectEndDateTime;

  /// No description provided for @availableUnitsOptional.
  ///
  /// In en, this message translates to:
  /// **'Available Units (optional)'**
  String get availableUnitsOptional;

  /// No description provided for @leaveBlankUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for unlimited'**
  String get leaveBlankUnlimited;

  /// No description provided for @activateHappyHour.
  ///
  /// In en, this message translates to:
  /// **'Activate Happy Hour'**
  String get activateHappyHour;

  /// No description provided for @clearHappyHour.
  ///
  /// In en, this message translates to:
  /// **'Clear Happy Hour'**
  String get clearHappyHour;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select or specify a category.'**
  String get selectCategory;

  /// No description provided for @itemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item updated!'**
  String get itemUpdated;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'Item added!'**
  String get itemAdded;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Try again.'**
  String get failedToSave;

  /// No description provided for @selectCategoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategoryHeader;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @createNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Create New Category'**
  String get createNewCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tacos, Bowls…'**
  String get categoryNameHint;

  /// No description provided for @chooseAnIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an Icon'**
  String get chooseAnIcon;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @tapUploadDishPicture.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload dish picture'**
  String get tapUploadDishPicture;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @noAddressesSaved.
  ///
  /// In en, this message translates to:
  /// **'No addresses saved'**
  String get noAddressesSaved;

  /// No description provided for @addressRemoved.
  ///
  /// In en, this message translates to:
  /// **'Address removed'**
  String get addressRemoved;

  /// No description provided for @setDefault.
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get setDefault;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @labelHint.
  ///
  /// In en, this message translates to:
  /// **'Label (e.g., Home, Work)'**
  String get labelHint;

  /// No description provided for @fullAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Address'**
  String get fullAddressLabel;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods saved'**
  String get noPaymentMethods;

  /// No description provided for @addNewCard.
  ///
  /// In en, this message translates to:
  /// **'Add New Card'**
  String get addNewCard;

  /// No description provided for @cardholderName.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get cardholderName;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date (MM/YY)'**
  String get expiryDate;

  /// No description provided for @warningAvatarFailed.
  ///
  /// In en, this message translates to:
  /// **'Warning: Failed to upload new avatar image.'**
  String get warningAvatarFailed;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get failedToUpdateProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @businessInfoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Business info updated'**
  String get businessInfoUpdated;

  /// No description provided for @businessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business Info'**
  String get businessInfo;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @payoutInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'Payout info saved'**
  String get payoutInfoSaved;

  /// No description provided for @payoutInfo.
  ///
  /// In en, this message translates to:
  /// **'Payout Info'**
  String get payoutInfo;

  /// No description provided for @payoutInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Payouts are processed every 7 days to your registered bank account.'**
  String get payoutInfoMessage;

  /// No description provided for @savePayoutInfo.
  ///
  /// In en, this message translates to:
  /// **'Save Payout Info'**
  String get savePayoutInfo;

  /// No description provided for @supportTicketSent.
  ///
  /// In en, this message translates to:
  /// **'Support ticket sent! We will contact you soon.'**
  String get supportTicketSent;

  /// No description provided for @failedToSendTicket.
  ///
  /// In en, this message translates to:
  /// **'Failed to send ticket. Please try again.'**
  String get failedToSendTicket;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @howCanWeHelp.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get howCanWeHelp;

  /// No description provided for @fillFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Fill out the form below and our team will get back to you within 24 hours.'**
  String get fillFormDescription;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicket;

  /// No description provided for @emailUs.
  ///
  /// In en, this message translates to:
  /// **'Email Us'**
  String get emailUs;

  /// No description provided for @callUs.
  ///
  /// In en, this message translates to:
  /// **'Call Us'**
  String get callUs;

  /// No description provided for @restaurantPartner.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Partner'**
  String get restaurantPartner;

  /// No description provided for @supermarketPartner.
  ///
  /// In en, this message translates to:
  /// **'Supermarket Partner'**
  String get supermarketPartner;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @manageOrdersRealtime.
  ///
  /// In en, this message translates to:
  /// **'Manage and update order status in real-time'**
  String get manageOrdersRealtime;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @filterNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get filterNew;

  /// No description provided for @confirmedFilter.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmedFilter;

  /// No description provided for @preparingFilter.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparingFilter;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @newOrdersAppearHere.
  ///
  /// In en, this message translates to:
  /// **'New orders will appear here in real-time'**
  String get newOrdersAppearHere;

  /// No description provided for @couldNotLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Could not load orders.\nCheck your connection.'**
  String get couldNotLoadOrders;

  /// No description provided for @updateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Status'**
  String get updateStatus;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @customerNotes.
  ///
  /// In en, this message translates to:
  /// **'Customer Notes'**
  String get customerNotes;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @priceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price Breakdown'**
  String get priceBreakdown;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @updateOrderStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Order Status'**
  String get updateOrderStatus;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @startPreparing.
  ///
  /// In en, this message translates to:
  /// **'Start Preparing'**
  String get startPreparing;

  /// No description provided for @markAsReady.
  ///
  /// In en, this message translates to:
  /// **'Mark as Ready'**
  String get markAsReady;

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get pickedUp;

  /// No description provided for @outForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get outForDelivery;

  /// No description provided for @markAsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Delivered'**
  String get markAsDelivered;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get callCustomer;

  /// No description provided for @recipientConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Recipient confirmed delivery! Order completed.'**
  String get recipientConfirmed;

  /// No description provided for @confirmRecipientAccepted.
  ///
  /// In en, this message translates to:
  /// **'Confirm Recipient Accepted'**
  String get confirmRecipientAccepted;

  /// No description provided for @recipientAccepted.
  ///
  /// In en, this message translates to:
  /// **'Recipient has accepted the package'**
  String get recipientAccepted;

  /// No description provided for @yourCourier.
  ///
  /// In en, this message translates to:
  /// **'Your Courier'**
  String get yourCourier;

  /// No description provided for @packageDetails.
  ///
  /// In en, this message translates to:
  /// **'Package Details'**
  String get packageDetails;

  /// No description provided for @orderDetailsHeader.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetailsHeader;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @package.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get package;

  /// No description provided for @driverPhoneNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Driver phone not available yet'**
  String get driverPhoneNotAvailable;

  /// No description provided for @unableToStartCall.
  ///
  /// In en, this message translates to:
  /// **'Unable to start phone call'**
  String get unableToStartCall;

  /// No description provided for @scanMenu.
  ///
  /// In en, this message translates to:
  /// **'Scan Menu'**
  String get scanMenu;

  /// No description provided for @scanMenuSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu scanned successfully!'**
  String get scanMenuSuccess;

  /// No description provided for @scanMenuError.
  ///
  /// In en, this message translates to:
  /// **'Failed to scan menu'**
  String get scanMenuError;

  /// No description provided for @scanMenuLoading.
  ///
  /// In en, this message translates to:
  /// **'Scanning menu with AI...'**
  String get scanMenuLoading;

  /// No description provided for @scanningMenu.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanningMenu;

  /// No description provided for @scanMenuEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Scan Physical Menu'**
  String get scanMenuEmptyState;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
