import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF4338CA);
  static const primaryLight = Color(0xFF818CF8);
  
  static const secondary = Color(0xFFF59E0B);
  static const secondaryDark = Color(0xFFD97706);
  static const secondaryLight = Color(0xFFFBBF24);
  
  static const accent = Color(0xFF10B981);
  static const accentDark = Color(0xFF059669);
  static const accentLight = Color(0xFF34D399);
  
  static const background = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF111827);
  static const backgroundDark = Color(0xFF0B0F1A);
  
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textLight = Color(0xFF94A3B8);
  static const textWhite = Colors.white;
  
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
  
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
