// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cmandili';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get or => 'OR';

  @override
  String pleaseEnter(Object field) {
    return 'Please enter your $field';
  }

  @override
  String get validEmail => 'Please enter a valid email';

  @override
  String get passwordLength => 'Password must be at least 6 characters';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get home => 'Home';

  @override
  String get welcome => 'Welcome';

  @override
  String get search => 'Search...';

  @override
  String get seeAll => 'See All';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get notificationsWillAppearHere => 'Notifications will appear here';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get availableOrders => 'Available Orders';

  @override
  String get noOrdersAvailable => 'No orders available right now';

  @override
  String get pullDownToRefresh => 'Pull down to refresh';

  @override
  String get acceptOrder => 'Accept Order';

  @override
  String get failedToAcceptOrder => 'Failed to accept order';

  @override
  String get markPickedUp => 'Mark as Picked Up';

  @override
  String get startDelivery => 'Start Delivery (On the Way)';

  @override
  String get confirmDelivery => 'Confirm Delivery';

  @override
  String get deliveryCompleted => 'Delivery Completed!';

  @override
  String get deliveringOrder => 'Delivering Order';

  @override
  String get deliveryLocation => 'Delivery Location';

  @override
  String get orderMarkedPickedUp => 'Order marked as picked up!';

  @override
  String get deliveryStarted => 'Delivery started!';

  @override
  String get deliveryConfirmed => 'Delivery confirmed!';

  @override
  String get earnings => 'Earnings';

  @override
  String get totalEarnings => 'Total Earnings';

  @override
  String get deliveriesCompleted => 'deliveries completed';

  @override
  String get recentDeliveries => 'Recent Deliveries';

  @override
  String get noDeliveriesYet => 'No deliveries yet';

  @override
  String get couldNotLoadEarnings => 'Could not load earnings';

  @override
  String get couldNotLoadHistory => 'Could not load history';

  @override
  String get driverProfileNotFound => 'Driver profile not found';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get savedAddresses => 'Saved Addresses';

  @override
  String get noAddressesSaved => 'No addresses saved';

  @override
  String get addressRemoved => 'Address removed';

  @override
  String get setDefault => 'Set Default';

  @override
  String get addNewAddress => 'Add New Address';

  @override
  String get labelHint => 'Label (e.g., Home, Work)';

  @override
  String get fullAddressLabel => 'Full Address';

  @override
  String get defaultLabel => 'Default';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get noPaymentMethods => 'No payment methods saved';

  @override
  String get addNewCard => 'Add New Card';

  @override
  String get cardholderName => 'Cardholder Name';

  @override
  String get cardNumber => 'Card Number';

  @override
  String get expiryDate => 'Expiry Date (MM/YY)';

  @override
  String get vehicleInfoSaved => 'Vehicle info saved';

  @override
  String get vehicleInfo => 'Vehicle Info';

  @override
  String get vehicleType => 'Vehicle Type';

  @override
  String get vehicleMakeHint => 'Make (e.g. Yamaha)';

  @override
  String get required => 'Required';

  @override
  String get vehicleModelHint => 'Model (e.g. NMAX)';

  @override
  String get licensePlate => 'License Plate';

  @override
  String get color => 'Color';

  @override
  String get saveVehicleInfo => 'Save Vehicle Info';

  @override
  String get pleaseSignInFirst => 'Please sign in first.';

  @override
  String get supportTicketSent =>
      'Support ticket sent! We will contact you soon.';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get howCanWeHelp => 'How can we help you?';

  @override
  String get fillFormDescription =>
      'Fill out the form below and our team will get back to you within 24 hours.';

  @override
  String get subject => 'Subject';

  @override
  String get pleaseEnterSubject => 'Please enter a subject';

  @override
  String get message => 'Message';

  @override
  String get pleaseEnterMessage => 'Please enter your message';

  @override
  String get submitTicket => 'Submit Ticket';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get failedToUpdateProfile => 'Failed to update profile.';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get phoneNumberLabel => 'Phone Number';

  @override
  String get bio => 'Bio';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get pleaseEnterName => 'Please enter your name';

  @override
  String get payoutInfoSaved => 'Payout info saved';

  @override
  String get earningsAndStatus => 'Earnings & Status';

  @override
  String get youAreOnline => 'You are Online';

  @override
  String get youAreOffline => 'You are Offline';

  @override
  String get canReceiveOrders => 'You can receive new orders';

  @override
  String get turnOnToReceive => 'Turn on to receive orders';

  @override
  String get bankPayoutInfo => 'Bank Payout Info';

  @override
  String get payoutsWeekly => 'Payouts are sent weekly to your bank account.';

  @override
  String get accountHolderName => 'Account Holder Name';

  @override
  String get bankName => 'Bank Name';

  @override
  String get ibanRib => 'IBAN / RIB';

  @override
  String get enterValidIban => 'Enter a valid IBAN/RIB';

  @override
  String get savePayoutInfo => 'Save Payout Info';

  @override
  String get account => 'Account';

  @override
  String get earningsAndPayout => 'Earnings & Payout';

  @override
  String get delivery => 'Delivery';

  @override
  String get you => 'You';

  @override
  String get deliveryAddress => 'Delivery Address';

  @override
  String get customer => 'Customer';

  @override
  String get deliveryHistory => 'Delivery History';

  @override
  String get completedDeliveriesAppearHere =>
      'Completed deliveries will appear here';

  @override
  String get delivered => 'Delivered';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get locationOff =>
      'Location is off. Turn on Location in your phone settings.';

  @override
  String get locationDeniedSettings =>
      'Location permission denied. Grant it in app settings.';

  @override
  String get driverDashboard => 'Driver Dashboard';

  @override
  String get youHaveActiveDelivery => 'You have an active delivery';

  @override
  String get readyForOrders => 'Ready for orders';

  @override
  String get youreOfflineFlip => 'You\'re offline — flip the switch to start';

  @override
  String get available => 'Available';

  @override
  String get active => 'Active';

  @override
  String get activeDelivery => 'Active Delivery';

  @override
  String get yourLocation => 'Your Location';

  @override
  String get expand => 'Expand';

  @override
  String get ordersWaitingForDriver => 'order(s) waiting for a driver';

  @override
  String get viewAvailableOrders => 'View Available Orders';

  @override
  String get onTheWay => 'On the Way';

  @override
  String get noActiveDelivery => 'No active delivery';

  @override
  String get acceptOrderToStart => 'Accept an order to start delivering';

  @override
  String get browseAvailableOrders => 'Browse Available Orders';

  @override
  String get orders => 'Orders';
}
