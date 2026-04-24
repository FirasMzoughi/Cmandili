// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Cmandili';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get or => 'أو';

  @override
  String pleaseEnter(Object field) {
    return 'الرجاء إدخال $field';
  }

  @override
  String get validEmail => 'الرجاء إدخال بريد إلكتروني صحيح';

  @override
  String get passwordLength => 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get home => 'الرئيسية';

  @override
  String get welcome => 'مرحباً';

  @override
  String get search => 'بحث...';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get notificationsWillAppearHere => 'ستظهر الإشعارات هنا';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get availableOrders => 'الطلبات المتاحة';

  @override
  String get noOrdersAvailable => 'لا توجد طلبات متاحة الآن';

  @override
  String get pullDownToRefresh => 'اسحب للأسفل للتحديث';

  @override
  String get acceptOrder => 'قبول الطلب';

  @override
  String get failedToAcceptOrder => 'فشل قبول الطلب';

  @override
  String get markPickedUp => 'تحديد كمستلم';

  @override
  String get startDelivery => 'بدء التوصيل (في الطريق)';

  @override
  String get confirmDelivery => 'تأكيد التوصيل';

  @override
  String get deliveryCompleted => 'اكتمل التوصيل!';

  @override
  String get deliveringOrder => 'جاري توصيل الطلب';

  @override
  String get deliveryLocation => 'موقع التسليم';

  @override
  String get orderMarkedPickedUp => 'تم تحديد الطلب كمستلم!';

  @override
  String get deliveryStarted => 'بدأ التوصيل!';

  @override
  String get deliveryConfirmed => 'تم تأكيد التوصيل!';

  @override
  String get earnings => 'الأرباح';

  @override
  String get totalEarnings => 'إجمالي الأرباح';

  @override
  String get deliveriesCompleted => 'توصيلات مكتملة';

  @override
  String get recentDeliveries => 'التوصيلات الأخيرة';

  @override
  String get noDeliveriesYet => 'لا توجد توصيلات بعد';

  @override
  String get couldNotLoadEarnings => 'تعذر تحميل الأرباح';

  @override
  String get couldNotLoadHistory => 'تعذر تحميل السجل';

  @override
  String get driverProfileNotFound => 'لم يتم العثور على ملف السائق';

  @override
  String get locationPermissionDenied => 'تم رفض إذن الموقع';
}
