import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatPrice(double price) {
    final formatter = NumberFormat('#,##0.00', 'fr_TN');
    return '${formatter.format(price)} DT';
  }
  
  static String formatPriceCompact(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K DT';
    }
    return '${price.toStringAsFixed(0)} DT';
  }
}
