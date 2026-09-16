import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Cmandili operates only in Tunisia, so the country code is never something
/// the user types or picks: `+216` is rendered as a fixed, non-editable prefix
/// and the field itself holds exactly the 8 local digits.
///
/// Use [normalize] when saving so the value persisted is always full E.164
/// (`+216XXXXXXXX`), and [toLocalDigits] when loading an existing value, which
/// may have been stored in any of the older free-text formats.
class TunisiaPhoneField extends StatelessWidget {
  static const countryCode = '+216';

  const TunisiaPhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.invalidMessage,
    this.enabled = true,
    this.autofocus = false,
    this.required = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;

  /// Shown when the field does not hold exactly 8 digits. When null the field
  /// is not validated (used where the surrounding form has no validation).
  final String? invalidMessage;

  final bool enabled;
  final bool autofocus;

  /// When false an empty field is accepted; a partially typed one still isn't.
  final bool required;

  final VoidCallback? onSubmitted;

  /// The 8 local digits held by [controller], stripped of display spaces.
  static String digitsOf(TextEditingController c) =>
      c.text.replaceAll(RegExp(r'[^0-9]'), '');

  /// Full E.164 for saving, or empty string when nothing was entered.
  static String normalize(TextEditingController c) {
    final d = digitsOf(c);
    return d.isEmpty ? '' : '$countryCode$d';
  }

  /// Strips any stored prefix down to the 8 local digits for display.
  /// Handles the legacy formats already in the database: `+216 12 345 678`,
  /// `0021612345678`, `21612345678` and bare `12345678`.
  static String toLocalDigits(String? stored) {
    var d = (stored ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00216')) {
      d = d.substring(5);
    } else if (d.length > 8 && d.startsWith('216')) {
      d = d.substring(3);
    }
    return d.length > 8 ? d.substring(d.length - 8) : d;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // The number is always LTR, even in Arabic, so the +216 prefix stays
      // glued to the left of the digits instead of flipping sides.
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => onSubmitted?.call(),
        maxLength: 10, // 8 digits + the 2 spaces the formatter inserts
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: AppColors.textPrimary,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _TunisianPhoneFormatter(),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: '12 345 678',
          counterText: '',
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          floatingLabelStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
          ),
          prefixIcon: const _CountryPrefix(),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          border: _border(Colors.grey.shade300),
          enabledBorder: _border(Colors.grey.shade300),
          disabledBorder: _border(Colors.grey.shade300),
          focusedBorder: _border(AppColors.primary, width: 2),
          errorBorder: _border(Colors.red.shade400),
          focusedErrorBorder: _border(Colors.red.shade400, width: 2),
        ),
        validator: invalidMessage == null
            ? null
            : (_) {
                final d = digitsOf(controller);
                if (d.isEmpty && !required) return null;
                if (d.length != 8) return invalidMessage;
                return null;
              },
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇹🇳', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 7),
          const Text(
            TunisiaPhoneField.countryCode,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
        ],
      ),
    );
  }
}

/// Formats 8 local Tunisian digits as `XX XXX XXX` while typing, and caps the
/// input at 8 digits so the field can never hold more than a valid number.
class _TunisianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      // Group as 2-3-3: a space goes before the 3rd and 6th digit.
      if (i == 2 || i == 5) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
