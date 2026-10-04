import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/trail_map_models.dart';

/// Modal inferior com resumo da lição, recompensas previstas e botão de ação.
/// Apresenta visual limpo, acolhedor e humanizado para o aluno.
class LessonStartModal extends StatelessWidget {
  final LicaoMapData licao;
  final VoidCallback onStart;

  const LessonStartModal({
    super.key,
    required this.licao,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = licao.status == LicaoStatus.concluida;
    final isDark = AppTheme.isDark(context);

    final primaryActionColor = isCompleted ? const Color(0xFF0E5D4E) : const Color(0xFFD08A45);
    final shadowActionColor = isCompleted ? const Color(0xFF094137) : const Color(0xFFA56627);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrasto superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Cabeçalho da lição com ícone temático
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: primaryActionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryActionColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                      color: primaryActionColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIÇÃO ${licao.numero}',
                          style: TextStyle(
                            color: primaryActionColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          licao.titulo,
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Descrição pedagógica
              Text(
                licao.descricao,
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Recompensas da lição
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF182420) : const Color(0xFFF3F0E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Color(0xFFD08A45), size: 20),
                        SizedBox(width: 6),
                        Text(
                          '+15 XP',
                          style: TextStyle(
                            color: Color(0xFFD08A45),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.spa_rounded, color: Color(0xFF0E5D4E), size: 18),
                        SizedBox(width: 6),
                        Text(
                          '+10 Conchas',
                          style: TextStyle(
                            color: Color(0xFF0E5D4E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botão tátil 3D (estilo Duolingo)
              Container(
                decoration: BoxDecoration(
                  color: shadowActionColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryActionColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCompleted
                              ? 'REVISAR LIÇÃO'
                              : licao.status == LicaoStatus.emAndamento
                                  ? 'CONTINUAR'
                                  : 'COMEÇAR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
