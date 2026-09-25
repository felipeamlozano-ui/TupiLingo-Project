import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../widgets/register_cards.dart';
import '../widgets/register_text_field.dart';

// Apresenta o onboarding inicial e captura o nome de tratamento do novo aluno.
class StepNameWidget extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onContinue;
  final Widget continueButton;

  const StepNameWidget({
    super.key,
    required this.nameController,
    required this.onContinue,
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
                child: Text('🦜', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Bem-vindo ao TupiLingo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Para começar, nos diga como podemos te chamar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          RegisterTextField(
            controller: nameController,
            label: 'Seu nome',
            hint: 'Ex: Felipe',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
          ),
          const SizedBox(height: 32),
          continueButton,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
