import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../widgets/register_cards.dart';
import '../widgets/register_text_field.dart';

// Coleta as credenciais de acesso por email/senha e dispara a finalização do onboarding.
class StepCredentialsWidget extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final bool isLoading;

  const StepCredentialsWidget({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.isLoading,
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
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFD08A45).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔐', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Quase lá!',
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
              'Crie suas credenciais para salvar seu progresso.',
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
            controller: emailController,
            label: 'E-mail',
            hint: 'seuemail@exemplo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          RegisterTextField(
            controller: passwordController,
            label: 'Senha',
            hint: 'Mínimo 6 caracteres',
            icon: Icons.lock_outline_rounded,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textSecondary(context),
                size: 20,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'FINALIZAR E FAZER TESTE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
