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

  @override
  String get savedAddresses => 'العناوين المحفوظة';

  @override
  String get noAddressesSaved => 'لا توجد عناوين محفوظة';

  @override
  String get addressRemoved => 'تم حذف العنوان';

  @override
  String get setDefault => 'تعيين كافتراضي';

  @override
  String get addNewAddress => 'إضافة عنوان جديد';

  @override
  String get labelHint => 'التسمية (مثال: المنزل، العمل)';

  @override
  String get fullAddressLabel => 'العنوان الكامل';

  @override
  String get defaultLabel => 'افتراضي';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get noPaymentMethods => 'لا توجد طرق دفع محفوظة';

  @override
  String get addNewCard => 'إضافة بطاقة جديدة';

  @override
  String get cardholderName => 'اسم حامل البطاقة';

  @override
  String get cardNumber => 'رقم البطاقة';

  @override
  String get expiryDate => 'تاريخ الانتهاء (MM/YY)';

  @override
  String get vehicleInfoSaved => 'تم حفظ معلومات المركبة';

  @override
  String get vehicleInfo => 'معلومات المركبة';

  @override
  String get vehicleType => 'نوع المركبة';

  @override
  String get vehicleMakeHint => 'الصانع (مثال: Yamaha)';

  @override
  String get required => 'مطلوب';

  @override
  String get vehicleModelHint => 'الطراز (مثال: NMAX)';

  @override
  String get licensePlate => 'لوحة الترخيص';

  @override
  String get color => 'اللون';

  @override
  String get saveVehicleInfo => 'حفظ معلومات المركبة';

  @override
  String get pleaseSignInFirst => 'يرجى تسجيل الدخول أولاً.';

  @override
  String get supportTicketSent => 'تم إرسال تذكرة الدعم! سنتصل بك قريباً.';

  @override
  String get helpSupport => 'المساعدة والدعم';

  @override
  String get howCanWeHelp => 'كيف يمكننا مساعدتك؟';

  @override
  String get fillFormDescription =>
      'املأ النموذج أدناه وسيتواصل معك فريقنا خلال 24 ساعة.';

  @override
  String get subject => 'الموضوع';

  @override
  String get pleaseEnterSubject => 'يرجى إدخال موضوع';

  @override
  String get message => 'الرسالة';

  @override
  String get pleaseEnterMessage => 'يرجى إدخال رسالتك';

  @override
  String get submitTicket => 'إرسال التذكرة';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح!';

  @override
  String get failedToUpdateProfile => 'فشل تحديث الملف الشخصي.';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get bio => 'نبذة';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get pleaseEnterName => 'يرجى إدخال اسمك';

  @override
  String get payoutInfoSaved => 'تم حفظ معلومات الدفع';

  @override
  String get earningsAndStatus => 'الأرباح والحالة';

  @override
  String get youAreOnline => 'أنت متصل';

  @override
  String get youAreOffline => 'أنت غير متصل';

  @override
  String get canReceiveOrders => 'يمكنك استقبال طلبات جديدة';

  @override
  String get turnOnToReceive => 'فعّل لاستقبال الطلبات';

  @override
  String get bankPayoutInfo => 'معلومات الدفع البنكي';

  @override
  String get payoutsWeekly => 'يتم إرسال المدفوعات أسبوعياً إلى حسابك البنكي.';

  @override
  String get accountHolderName => 'اسم صاحب الحساب';

  @override
  String get bankName => 'اسم البنك';

  @override
  String get ibanRib => 'IBAN / RIB';

  @override
  String get enterValidIban => 'أدخل IBAN/RIB صحيحاً';

  @override
  String get savePayoutInfo => 'حفظ معلومات الدفع';

  @override
  String get account => 'الحساب';

  @override
  String get earningsAndPayout => 'الأرباح والدفع';

  @override
  String get delivery => 'التوصيل';

  @override
  String get you => 'أنت';

  @override
  String get deliveryAddress => 'عنوان التسليم';

  @override
  String get customer => 'العميل';

  @override
  String get deliveryHistory => 'سجل التوصيل';

  @override
  String get completedDeliveriesAppearHere => 'ستظهر التوصيلات المكتملة هنا';

  @override
  String get delivered => 'تم التسليم';

  @override
  String get today => 'اليوم';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get locationOff => 'خدمة الموقع متوقفة. شغّلها من إعدادات الهاتف.';

  @override
  String get locationDeniedSettings =>
      'تم رفض إذن الموقع. امنحه من إعدادات التطبيق.';

  @override
  String get driverDashboard => 'لوحة السائق';

  @override
  String get youHaveActiveDelivery => 'لديك توصيل نشط';

  @override
  String get readyForOrders => 'جاهز للطلبات';

  @override
  String get youreOfflineFlip => 'أنت غير متصل — فعّل المفتاح للبدء';

  @override
  String get available => 'متاح';

  @override
  String get active => 'نشط';

  @override
  String get activeDelivery => 'توصيل نشط';

  @override
  String get yourLocation => 'موقعك';

  @override
  String get expand => 'توسيع';

  @override
  String get ordersWaitingForDriver => 'طلب (طلبات) في انتظار سائق';

  @override
  String get viewAvailableOrders => 'عرض الطلبات المتاحة';

  @override
  String get onTheWay => 'في الطريق';

  @override
  String get noActiveDelivery => 'لا يوجد توصيل نشط';

  @override
  String get acceptOrderToStart => 'اقبل طلباً لبدء التوصيل';

  @override
  String get browseAvailableOrders => 'تصفح الطلبات المتاحة';

  @override
  String get orders => 'الطلبات';
}
