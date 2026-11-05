import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Palette - Perfume & Athar Aesthetic
  static const Color primary = Color(0xFFB8860B); // Dark Goldenrod
  static const Color primaryDark = Color(0xFF8B6508);
  static const Color primaryLight = Color(0xFFE6C875);
  static const Color primaryContainer = Color(0xFFF9F5EC);

  static const Color secondary = Color(0xFF1E293B); // Deep Slate
  static const Color secondaryLight = Color(0xFF334155);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBg = Colors.white;
  static const Color sidebarBg = Color(0xFF0F172A); // Rich dark slate sidebar

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;

  // Status & Financial Indicators
  static const Color cashGreen = Color(0xFF059669); // Cash income & positive stock
  static const Color cashGreenLight = Color(0xFFECFDF5);
  static const Color onlineBlue = Color(0xFF2563EB); // Online income
  static const Color onlineBlueLight = Color(0xFFEFF6FF);
  static const Color splitPurple = Color(0xFF7C3AED); // Split payment
  static const Color splitPurpleLight = Color(0xFFF5F3FF);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0284C7);

  // Common semantic aliases
  static const Color success = cashGreen;
  static const Color error = danger;
  static const Color accent = primary;

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
}

