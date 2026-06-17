import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Second step of the OTP-based password-reset flow.
///
/// Receives the [email] the user typed in [ForgotPasswordScreen] so it can
/// pass it to `verifyOtp`.  The screen collects:
///   1. The 8-digit code from the email.
///   2. The new password (+ confirmation).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Core logic ────────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = ref.read(authRepositoryProvider);

    try {
      // Step 2: verify OTP → establishes a recovery session in Supabase
      await repo.verifyPasswordResetOtp(
        email: widget.email,
        token: _otpController.text.trim(),
      );

      // Step 3: update password within that session
      await repo.updatePassword(_passwordController.text);

      if (!mounted) return;

      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps raw Supabase error strings to human-readable messages.
  String _friendlyError(String raw) {
    if (raw.contains('Token has expired') || raw.contains('invalid')) {
      return 'The code is invalid or has expired. Request a new one.';
    }
    if (raw.contains('Password should be')) {
      return 'Password must be at least 6 characters.';
    }
    return raw;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Password Updated!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your password has been changed successfully. Please sign in with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Pop both ResetPasswordScreen and ForgotPasswordScreen
                // back to the AuthScreen (the route that predates them).
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Sign In',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFF7931E), Color(0xFFFFB800)],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -sh * 0.12,
            right: -sw * 0.2,
            child: _circle(sw * 0.6, Colors.white.withOpacity(0.12)),
          ),
          Positioned(
            bottom: -sh * 0.08,
            left: -sw * 0.15,
            child: _circle(sw * 0.5, Colors.white.withOpacity(0.10)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: sw * 0.06),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
                              // Icon
                              Container(
                                padding: EdgeInsets.all(sw * 0.05),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.shield_rounded,
                                    size: sw * 0.14, color: Colors.white),
                              ),
                              SizedBox(height: sh * 0.02),

                              Text(
                                'Enter Reset Code',
                                style: TextStyle(
                                  fontSize: sw * 0.065,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: sh * 0.008),
                              // Show masked email for confirmation
                              Text(
                                'Code sent to  ${_maskEmail(widget.email)}',
                                style: TextStyle(
                                  fontSize: sw * 0.036,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),

                              SizedBox(height: sh * 0.035),

                              // ── Card ────────────────────────────────────
                              ClipRRect(
                                borderRadius: BorderRadius.circular(sw * 0.07),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    padding: EdgeInsets.all(sw * 0.06),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius:
                                          BorderRadius.circular(sw * 0.07),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: sw * 0.07,
                                          offset: Offset(0, sh * 0.012),
                                        ),
                                      ],
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // ── 8-digit OTP field ────────
                                          _buildOtpField(sw, sh),

                                          SizedBox(height: sh * 0.02),

                                          // ── New password ─────────────
                                          _buildField(
                                            controller: _passwordController,
                                            label: 'New password',
                                            icon: Icons.lock_outline_rounded,
                                            isPassword: true,
                                            isObscure: _obscurePassword,
                                            onToggle: () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                            sw: sw,
                                            sh: sh,
                                            validator: (v) {
                                              if (v == null || v.isEmpty) {
                                                return 'Please enter a password';
                                              }
                                              if (v.length < 8) {
                                                return 'Must be at least 6 characters';
                                              }
                                              return null;
                                            },
                                          ),

                                          SizedBox(height: sh * 0.02),

                                          // ── Confirm password ─────────
                                          _buildField(
                                            controller: _confirmController,
                                            label: 'Confirm password',
                                            icon: Icons.lock_outline_rounded,
                                            isPassword: true,
                                            isObscure: _obscureConfirm,
                                            onToggle: () => setState(() =>
                                                _obscureConfirm =
                                                    !_obscureConfirm),
                                            sw: sw,
                                            sh: sh,
                                            validator: (v) {
                                              if (v != _passwordController.text) {
                                                return 'Passwords do not match';
                                              }
                                              return null;
                                            },
                                          ),

                                          SizedBox(height: sh * 0.03),

                                          // ── Submit ────────────────────
                                          SizedBox(
                                            height: sh * 0.065,
                                            child: ElevatedButton(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _resetPassword,
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 8,
                                                shadowColor: AppColors.primary
                                                    .withOpacity(0.4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          sw * 0.04),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                    )
                                                  : Text(
                                                      'Reset Password',
                                                      style: TextStyle(
                                                        fontSize: sw * 0.042,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  /// Large, centered OTP input field styled to look like a code entry.
  Widget _buildOtpField(double sw, double sh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '8-digit code',
          style: TextStyle(
            fontSize: sw * 0.035,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: sh * 0.008),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: sw * 0.07,
            fontWeight: FontWeight.bold,
            letterSpacing: sw * 0.06,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            counterText: '', // hide the "0/6" counter
            filled: true,
            fillColor: AppColors.primary.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(sw * 0.04),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(sw * 0.04),
              borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.25), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(sw * 0.04),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(sw * 0.04),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(sw * 0.04),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding:
                EdgeInsets.symmetric(vertical: sh * 0.022),
          ),
          validator: (v) {
            if (v == null || v.trim().length != 8) {
              return 'Enter the 8-digit code from your email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double sw,
    required double sh,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontSize: sw * 0.04,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.8),
            fontSize: sw * 0.038),
        prefixIcon: Icon(icon,
            color: AppColors.primary.withOpacity(0.7), size: sw * 0.06),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary.withOpacity(0.5),
                  size: sw * 0.055,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(sw * 0.04),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: BorderSide(
              color: AppColors.textLight.withOpacity(0.1), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: sw * 0.05, vertical: sh * 0.02),
      ),
      validator: validator,
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  /// Shows a masked email like  u****@gmail.com
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '$name****'
        : '${name[0]}${'*' * (name.length - 1)}';
    return '$masked@${parts[1]}';
  }
}
