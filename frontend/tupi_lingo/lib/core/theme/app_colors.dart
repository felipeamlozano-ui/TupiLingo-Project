import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppColors {
  static const Color background = Color(0xFFF3F2E8);
  static const Color subtitle = Color(0xFF565D6D);
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
  static const Color cardSurface = Colors.white;
  static const Color inputBorder = Color(0xFFD0D0D0);
  static const Color secondaryText = Color(0xFF0E5D4E);
  static const Color titleColor = Color(0xFFB8AF64);

  // Dynamic helpers based on active theme
  static Color dynamicBg(BuildContext context) => AppTheme.bg(context);
  static Color dynamicSurface(BuildContext context) => AppTheme.surface(context);
  static Color dynamicBorder(BuildContext context) => AppTheme.border(context);
  static Color dynamicTextPrimary(BuildContext context) => AppTheme.textPrimary(context);
  static Color dynamicTextSecondary(BuildContext context) => AppTheme.textSecondary(context);
}
