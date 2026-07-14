import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';
import '../../../core/providers/localization_provider.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _backgroundAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _backgroundAnimationController,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _backgroundAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_tabController.index == 0) {
        await authRepo.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await authRepo.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
          _phoneController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSocialSignIn(Future<void> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      await signInMethod();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background with Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.primaryLight,
                ],
              ),
            ),
          ),

          // Animated Decorative Elements
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -screenHeight * 0.15,
                    right: -screenWidth * 0.2 + (_rotationAnimation.value * screenWidth * 0.1),
                    child: Container(
                      width: screenWidth * 0.6,
                      height: screenWidth * 0.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -screenHeight * 0.1,
                    left: -screenWidth * 0.15 - (_rotationAnimation.value * screenWidth * 0.1),
                    child: Container(
                      width: screenWidth * 0.5,
                      height: screenWidth * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.3,
                    left: -screenWidth * 0.1,
                    child: Container(
                      width: screenWidth * 0.3,
                      height: screenWidth * 0.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Language Switcher Button
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: screenHeight * 0.02,
                  right: screenWidth * 0.05,
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final locale = ref.watch(localizationProvider);
                    return IconButton(
                      onPressed: () {
                        // Cycle through languages: en -> ar -> fr -> en
                        String nextLang;
                        switch (locale.languageCode) {
                          case 'en':
                            nextLang = 'ar';
                            break;
                          case 'ar':
                            nextLang = 'fr';
                            break;
                          default:
                            nextLang = 'en';
                        }
                        ref.read(localizationProvider.notifier).setLocale(Locale(nextLang));
                      },
                      icon: Container(
                        padding: EdgeInsets.all(screenWidth * 0.025),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: screenWidth * 0.02,
                              offset: Offset(0, screenHeight * 0.005),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: Colors.white,
                          size: screenWidth * 0.06,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: screenWidth * 0.06,
                right: screenWidth * 0.06,
                top: screenHeight * 0.06, // Extra padding to avoid status bar
                bottom: screenHeight * 0.02,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo and Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Logo Container
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: screenWidth * 0.05,
                                  offset: Offset(0, screenHeight * 0.01),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: screenWidth * 0.15,
                              height: screenWidth * 0.15,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          
                          // App Title
                          Text(
                            AppLocalizations.of(context)!.appTitle,
                            style: TextStyle(
                              fontSize: screenWidth * 0.09,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          
                          // Welcome Text
                          Text(
                            AppLocalizations.of(context)!.welcome,
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Glassmorphic Form Container
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(screenWidth * 0.08),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.06),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(screenWidth * 0.08),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: screenWidth * 0.08,
                                  offset: Offset(0, screenHeight * 0.015),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Custom Tab Bar
                                Container(
                                  height: screenHeight * 0.055,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(screenWidth * 0.08),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    indicator: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B35),
                                          Color(0xFFF7931E),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(screenWidth * 0.08),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.4),
                                          blurRadius: screenWidth * 0.03,
                                          offset: Offset(0, screenHeight * 0.005),
                                        ),
                                      ],
                                    ),
                                    labelColor: Colors.white,
                                    unselectedLabelColor: AppColors.textSecondary,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.04,
                                    ),
                                    tabs: [
                                      Tab(text: AppLocalizations.of(context)!.signIn),
                                      Tab(text: AppLocalizations.of(context)!.signUp),
                                    ],
                                    onTap: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.025),

                                // Form
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      if (_tabController.index == 1) ...[
                                        _buildTextField(
                                          controller: _nameController,
                                          label: AppLocalizations.of(context)!.fullName,
                                          icon: Icons.person_outline_rounded,
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                        SizedBox(height: screenHeight * 0.015),
                                        _buildTextField(
                                          controller: _phoneController,
                                          label: AppLocalizations.of(context)!.phoneNumberLabel,
                                          icon: Icons.phone_outlined,
                                          keyboardType: TextInputType.phone,
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                        SizedBox(height: screenHeight * 0.015),
                                      ],
                                      _buildTextField(
                                        controller: _emailController,
                                        label: AppLocalizations.of(context)!.email,
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        screenWidth: screenWidth,
                                        screenHeight: screenHeight,
                                      ),
                                      SizedBox(height: screenHeight * 0.015),
                                      _buildTextField(
                                        controller: _passwordController,
                                        label: AppLocalizations.of(context)!.password,
                                        icon: Icons.lock_outline_rounded,
                                        isPassword: true,
                                        isObscure: _obscurePassword,
                                        onToggleObscure: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                        screenWidth: screenWidth,
                                        screenHeight: screenHeight,
                                      ),

                                      // "Forgot Password?" — only on Sign In tab
                                      if (_tabController.index == 0)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordScreen(),
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.01,
                                                vertical: screenHeight * 0.005,
                                              ),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.037,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),

                                      SizedBox(height: screenHeight * 0.015),

                                      // Main Action Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: screenHeight * 0.06,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _handleEmailAuth,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 8,
                                            shadowColor: AppColors.primary.withOpacity(0.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? SizedBox(
                                                  height: screenHeight * 0.025,
                                                  width: screenHeight * 0.025,
                                                  child: const CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Text(
                                                  _tabController.index == 0
                                                      ? AppLocalizations.of(context)!.signIn
                                                      : AppLocalizations.of(context)!.createAccount,
                                                  style: TextStyle(
                                                    fontSize: screenWidth * 0.042,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: screenHeight * 0.02),
                                
                                // Divider
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              AppColors.textLight.withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                                      child: Text(
                                        AppLocalizations.of(context)!.or,
                                        style: TextStyle(
                                          color: AppColors.textSecondary.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                          fontSize: screenWidth * 0.035,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.textLight.withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: screenHeight * 0.02),

                                // Social Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildSocialButton(
                                      icon: Icons.g_mobiledata_rounded,
                                      onPressed: () => _handleSocialSignIn(
                                        ref.read(authRepositoryProvider).signInWithGoogle,
                                      ),
                                      screenWidth: screenWidth,
                                      screenHeight: screenHeight,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.01),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double screenWidth,
    required double screenHeight,
    bool isPassword = false,
    bool? isObscure,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure ?? false,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontSize: screenWidth * 0.04,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.8),
          fontSize: screenWidth * 0.038,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary.withOpacity(0.7),
          size: screenWidth * 0.06,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure! ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary.withOpacity(0.5),
                  size: screenWidth * 0.055,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: BorderSide(
            color: AppColors.textLight.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.02,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.pleaseEnter(label);
        }
        if (label == AppLocalizations.of(context)!.email && !value.contains('@')) {
          return AppLocalizations.of(context)!.validEmail;
        }
        if (label == AppLocalizations.of(context)!.password && value.length < 6) {
          return AppLocalizations.of(context)!.passwordLength;
        }
        if (label == AppLocalizations.of(context)!.phoneNumberLabel) {
          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length < 8) return AppLocalizations.of(context)!.phoneInvalid;
        }
        return null;
      },
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double screenWidth,
    required double screenHeight,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.textLight.withOpacity(0.25),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: screenWidth * 0.02,
                offset: Offset(0, screenHeight * 0.005),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: screenWidth * 0.08,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
