import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFF60A5FA);
  
  static const secondary = Color(0xFF14B8A6);
  static const secondaryDark = Color(0xFF0D9488);
  static const secondaryLight = Color(0xFF5EEAD4);
  
  static const accent = Color(0xFFF97316);
  static const accentDark = Color(0xFFEA580C);
  static const accentLight = Color(0xFFFB923C);
  
  static const background = Color(0xFFF5F7FB);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF0F172A);
  static const backgroundDark = Color(0xFF0B1020);
  
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textLight = Color(0xFF94A3B8);
  static const textWhite = Colors.white;
  
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF38BDF8);
  
  static const star = Color(0xFFFACC15);
  
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
