import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetOtp(_emailController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResetPasswordScreen(email: _emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFF7931E), Color(0xFFFFB800)],
              ),
            ),
          ),
          Positioned(
              top: -sh * 0.12,
              right: -sw * 0.2,
              child: _circle(sw * 0.6, Colors.white.withOpacity(0.12))),
          Positioned(
              bottom: -sh * 0.08,
              left: -sw * 0.15,
              child: _circle(sw * 0.5, Colors.white.withOpacity(0.10))),
          SafeArea(
            child: Column(
              children: [
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
                              Container(
                                padding: EdgeInsets.all(sw * 0.05),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.lock_reset_rounded,
                                    size: sw * 0.14, color: Colors.white),
                              ),
                              SizedBox(height: sh * 0.025),
                              Text('Forgot Password?',
                                  style: TextStyle(
                                      fontSize: sw * 0.07,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              SizedBox(height: sh * 0.01),
                              Text(
                                "Enter your email and we'll send\nyou a 6-digit reset code.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: sw * 0.038,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.5),
                              ),
                              SizedBox(height: sh * 0.04),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(sw * 0.07),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    padding: EdgeInsets.all(sw * 0.06),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius:
                                          BorderRadius.circular(sw * 0.07),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.12),
                                            blurRadius: sw * 0.07,
                                            offset: Offset(0, sh * 0.012))
                                      ],
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildField(
                                            controller: _emailController,
                                            label: 'Email address',
                                            icon: Icons.email_outlined,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            sw: sw,
                                            sh: sh,
                                            validator: (v) {
                                              if (v == null || v.isEmpty) {
                                                return 'Please enter your email';
                                              }
                                              if (!v.contains('@')) {
                                                return 'Enter a valid email';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: sh * 0.025),
                                          SizedBox(
                                            height: sh * 0.065,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _isLoading ? null : _sendCode,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 8,
                                                shadowColor: AppColors.primary
                                                    .withOpacity(0.4),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            sw * 0.04)),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                              color: Colors.white,
                                                              strokeWidth: 2.5))
                                                  : Text('Send Reset Code',
                                                      style: TextStyle(
                                                          fontSize: sw * 0.042,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: sh * 0.025),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResetPasswordScreen(
                                        email: _emailController.text.trim()),
                                  ),
                                ),
                                child: Text(
                                  'Already have a code? Enter it →',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: sw * 0.037),
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

  Widget _circle(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double sw,
    required double sh,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontSize: sw * 0.04),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.8),
            fontSize: sw * 0.038),
        prefixIcon: Icon(icon,
            color: AppColors.primary.withOpacity(0.7), size: sw * 0.06),
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
}
