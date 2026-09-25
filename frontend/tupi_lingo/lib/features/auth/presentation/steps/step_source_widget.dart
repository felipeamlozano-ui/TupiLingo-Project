import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../widgets/register_cards.dart';

// Mapeia por onde o usuário descobriu o app para métricas de aquisição no onboarding.
class StepSourceWidget extends StatelessWidget {
  final List<Map<String, dynamic>> sourceOptions;
  final String? selectedSource;
  final ValueChanged<String> onSelectSource;
  final Widget continueButton;

  const StepSourceWidget({
    super.key,
    required this.sourceOptions,
    required this.selectedSource,
    required this.onSelectSource,
    required this.continueButton,
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
                child: Text('🧭', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Como nos encontrou?',
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
              'Queremos saber como você conheceu o TupiLingo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sourceOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final option = sourceOptions[index];
              final isSelected = selectedSource == option['value'];
              return SelectableSourceCard(
                icon: option['icon'] as IconData,
                label: option['label'] as String,
                isSelected: isSelected,
                onTap: () => onSelectSource(option['value'] as String),
              );
            },
          ),
          const SizedBox(height: 32),
          continueButton,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
