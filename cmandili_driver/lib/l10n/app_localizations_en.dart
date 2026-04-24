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
}
