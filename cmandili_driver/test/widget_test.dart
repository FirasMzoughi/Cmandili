import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_driver/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formatPrice renders DT suffix', () {
      expect(CurrencyFormatter.formatPrice(0), endsWith('DT'));
      expect(CurrencyFormatter.formatPrice(12.5), contains('12'));
    });

    test('formatPriceCompact uses K suffix above 1000', () {
      expect(CurrencyFormatter.formatPriceCompact(1500), '1.5K DT');
      expect(CurrencyFormatter.formatPriceCompact(999), '999 DT');
    });
  });
}
