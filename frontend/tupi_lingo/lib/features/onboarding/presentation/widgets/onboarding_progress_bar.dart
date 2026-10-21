import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Barra superior de progresso suave para o fluxo de Onboarding e lição demo.
class OnboardingProgressBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? skipLabel;

  const OnboardingProgressBar({
    super.key,
    required this.progress,
    this.onBack,
    this.onSkip,
    this.skipLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.textPrimary(context),
                tooltip: 'Voltar',
                onPressed: onBack,
              )
            else
              const SizedBox(width: 8),

            // Barra de progresso animada
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222F2A) : const Color(0xFFE5E0D5),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      widthFactor: progress.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFD08A45),
                              Color(0xFFE8A866),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD08A45).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (onSkip != null) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary(context),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  skipLabel ?? 'PULAR',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ] else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
