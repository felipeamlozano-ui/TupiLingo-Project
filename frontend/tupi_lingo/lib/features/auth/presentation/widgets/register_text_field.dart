import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Padroniza a caixa de texto do onboarding com borda ativa terracota e suporte nativo ao modo escuro.
class RegisterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final Color primaryColor;

  const RegisterTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.primaryColor = const Color(0xFFD08A45),
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 16, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: AppTheme.textSecondary(context),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.surface(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
