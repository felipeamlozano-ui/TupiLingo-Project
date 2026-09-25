import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// Tela comemorativa de conclusão da rodada de prática com estatísticas consolidadas
class ThematicSummaryView extends StatelessWidget {
  final int accumulatedXp;
  final int accumulatedConchas;
  final int currentLevel;
  final VoidCallback onFinish;

  const ThematicSummaryView({
    super.key,
    required this.accumulatedXp,
    required this.accumulatedConchas,
    required this.currentLevel,
    required this.onFinish,
  });

  // Renderiza o troféu, resumo de pontuação e botão de retorno
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('🏆', style: TextStyle(fontSize: 46))),
                ),
                const SizedBox(height: 20),
                Text(
                  'Treino Temático Concluído!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seus ganhos e aprendizados foram consolidados com sucesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatCard(context, 'Experiência', '+$accumulatedXp XP', const Color(0xFFD08A45)),
                    const SizedBox(width: 14),
                    _buildStatCard(context, 'Conchas', '+$accumulatedConchas 🐚', const Color(0xFF0E5D4E)),
                    const SizedBox(width: 14),
                    _buildStatCard(context, 'Seu Nível', 'Nível $currentLevel', const Color(0xFF1EC9A5)),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E5D4E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('VOLTAR AO CENTRO DE PRÁTICA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Card individual com número em destaque e legenda descritiva
  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }
}
