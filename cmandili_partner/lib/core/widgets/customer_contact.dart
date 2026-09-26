import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Normalises a Tunisian number into the `216XXXXXXXX` form WhatsApp expects.
///
/// Numbers reach us in every shape users type them: `21698123456`,
/// `+216 98 123 456`, `98123456`, `98-123-456`. wa.me accepts digits only,
/// with the country code and no `+`, so anything else silently opens a
/// "phone number shared via url is invalid" page instead of the chat.
String? whatsappNumber(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  // Already carries the country code.
  if (digits.startsWith('216') && digits.length == 11) return digits;
  // Local 8-digit mobile — prefix Tunisia.
  if (digits.length == 8) return '216$digits';
  // 00216… international prefix.
  if (digits.startsWith('00216') && digits.length == 13) {
    return digits.substring(2);
  }
  // Anything else (a foreign number, or something malformed): hand it over
  // as-is rather than guessing wrong and opening the wrong chat.
  return digits.length >= 8 ? digits : null;
}

/// Customer contact row: the number, a call button and a WhatsApp button.
///
/// Both matter operationally — a driver at a closed gate needs to reach the
/// customer immediately, and WhatsApp works when the customer has no credit
/// or is on data only, which is common here.
class CustomerContact extends StatelessWidget {
  final String phone;

  /// Shown above the buttons when there is room; omitted in tight rows.
  final String? label;

  /// Pre-filled WhatsApp message, so the driver does not have to type while
  /// on a scooter. Null sends an empty chat.
  final String? whatsappMessage;

  /// Compact renders a single inline row for list tiles; the full form is a
  /// bordered card for detail screens.
  final bool compact;

  const CustomerContact({
    super.key,
    required this.phone,
    this.label,
    this.whatsappMessage,
    this.compact = false,
  });

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _toast(context, 'Impossible de lancer l\'appel');
    }
  }

  Future<void> _whatsapp(BuildContext context) async {
    final number = whatsappNumber(phone);
    if (number == null) {
      if (context.mounted) _toast(context, 'Numéro invalide');
      return;
    }
    final text = whatsappMessage == null
        ? ''
        : '?text=${Uri.encodeComponent(whatsappMessage!)}';
    final uri = Uri.parse('https://wa.me/$number$text');
    // externalApplication opens the installed WhatsApp app; without it the
    // link can be captured by an in-app webview that cannot start a chat.
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) _toast(context, 'WhatsApp introuvable');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              phone,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _IconAction(
            icon: Icons.phone_rounded,
            color: AppColors.success,
            tooltip: 'Appeler',
            onTap: () => _call(context),
          ),
          const SizedBox(width: 4),
          _IconAction(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366), // WhatsApp brand green
            tooltip: 'WhatsApp',
            onTap: () => _whatsapp(context),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  // Long-press copies, for pasting into a dispatch note.
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    _toast(context, 'Numéro copié');
                  },
                  child: Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              _ContactButton(
                icon: Icons.phone_rounded,
                label: 'Appeler',
                color: AppColors.success,
                onTap: () => _call(context),
              ),
              const SizedBox(width: 8),
              _ContactButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _whatsapp(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
