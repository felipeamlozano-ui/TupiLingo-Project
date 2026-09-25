import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../widgets/register_cards.dart';

// Permite ao aluno autoavaliar sua bagagem prévia no idioma pra calibrar o ponto de partida na trilha.
class StepLevelWidget extends StatelessWidget {
  final List<Map<String, dynamic>> levelOptions;
  final String? selectedLevel;
  final ValueChanged<String> onSelectLevel;
  final Widget actionButton;

  const StepLevelWidget({
    super.key,
    required this.levelOptions,
    required this.selectedLevel,
    required this.onSelectLevel,
    required this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: const Center(
                child: Text('🌱', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Qual seu nível em Tupi?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Isso nos ajuda a preparar uma experiência personalizada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),

          ...List.generate(levelOptions.length, (index) {
            final option = levelOptions[index];
            final isSelected = selectedLevel == option['value'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LevelOptionCard(
                icon: option['icon'] as IconData,
                label: option['label'] as String,
                description: option['description'] as String,
                accentColor: option['color'] as Color,
                isSelected: isSelected,
                onTap: () => onSelectLevel(option['value'] as String),
              ),
            );
          }),

          const SizedBox(height: 32),
          actionButton,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
