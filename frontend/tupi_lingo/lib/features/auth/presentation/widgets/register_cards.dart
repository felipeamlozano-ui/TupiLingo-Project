import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Embrulha o conteúdo de cada passo do cadastro garantindo margens e rolagem suave se o teclado subir.
class StepContainer extends StatelessWidget {
  final Widget child;
  const StepContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: child,
      ),
    );
  }
}

// Renderiza a opção selecionável na pesquisa de origem com feedback tátil e destaque na cor ancestral.
class SelectableSourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const SelectableSourceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.primaryColor = const Color(0xFFD08A45),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : AppTheme.border(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF1C2723) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? primaryColor : AppTheme.textSecondary(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryColor : AppTheme.textPrimary(context),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : AppTheme.border(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Monta o card de autoavaliação de proficiência com badge colorido e resumo pro aluno saber seu ponto de partida.
class LevelOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const LevelOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.12) : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.border(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.8)
                          : AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : AppTheme.border(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
