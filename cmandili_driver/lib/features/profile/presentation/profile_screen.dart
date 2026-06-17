import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:cmandili_driver/l10n/app_localizations.dart';
import '../../../core/providers/localization_provider.dart';
import '../../../core/providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import '../../notifications/presentation/notification_screen.dart';
import 'vehicle_info_screen.dart';
import 'driver_payout_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localizationProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final displayName = currentUser?.displayName ?? currentUser?.email?.split('@').first ?? '';
    final displayEmail = currentUser?.email ?? '';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: screenHeight * 0.25,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.125,
                        backgroundColor: Colors.white,
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: screenWidth * 0.1,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        displayEmail,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader(context, AppLocalizations.of(context)!.account, screenWidth),
                _buildProfileItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: AppLocalizations.of(context)!.editProfile,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.two_wheeler_rounded,
                  title: AppLocalizations.of(context)!.vehicleInfo,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleInfoScreen()));
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.account_balance_outlined,
                  title: AppLocalizations.of(context)!.earningsAndPayout,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPayoutScreen()));
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.03),
                _buildSectionHeader(context, AppLocalizations.of(context)!.settings, screenWidth),
                _buildProfileItem(
                  context,
                  icon: Icons.notifications_outlined,
                  title: AppLocalizations.of(context)!.notifications,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.language_outlined,
                  title: AppLocalizations.of(context)!.language,
                  trailing: _getLanguageName(locale.languageCode),
                  onTap: () => _showLanguageBottomSheet(context, ref, screenWidth, screenHeight),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.brightness_6_outlined,
                  title: AppLocalizations.of(context)!.theme,
                  trailing: themeMode == ThemeMode.dark 
                      ? AppLocalizations.of(context)!.darkMode 
                      : AppLocalizations.of(context)!.lightMode,
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: AppLocalizations.of(context)!.helpSupport,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.03),
                _buildProfileItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: AppLocalizations.of(context)!.logout,
                  textColor: AppColors.error,
                  iconColor: AppColors.error,
                  showArrow: false,
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.12), // Bottom padding for nav bar
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'ar': return 'العربية';
      case 'fr': return 'Français';
      default: return 'English';
    }
  }

  void _showLanguageBottomSheet(BuildContext context, WidgetRef ref, double screenWidth, double screenHeight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(screenWidth * 0.06),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(screenWidth * 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.language,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.055,
                  ),
            ),
            SizedBox(height: screenHeight * 0.03),
            _buildLanguageOption(context, ref, 'English', 'en', screenWidth),
            _buildLanguageOption(context, ref, 'العربية', 'ar', screenWidth),
            _buildLanguageOption(context, ref, 'Français', 'fr', screenWidth),
            SizedBox(height: screenHeight * 0.03),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, WidgetRef ref, String name, String code, double screenWidth) {
    final isSelected = ref.watch(localizationProvider).languageCode == code;
    return ListTile(
      title: Text(
        name,
        style: TextStyle(fontSize: screenWidth * 0.04),
      ),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary, size: screenWidth * 0.06) : null,
      onTap: () {
        ref.read(localizationProvider.notifier).setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: screenWidth * 0.04,
        left: screenWidth * 0.01,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
    String? trailing,
    Color? textColor,
    Color? iconColor,
    bool showArrow = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.025),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppColors.primary,
                    size: screenWidth * 0.055,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.6),
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                if (showArrow) ...[
                  SizedBox(width: screenWidth * 0.02),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: screenWidth * 0.04,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
