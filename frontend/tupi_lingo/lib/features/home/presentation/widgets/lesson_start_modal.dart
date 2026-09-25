import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/trail_map_models.dart';

// Modal inferior com resumo da lição, recompensas previstas e botão de ação
class LessonStartModal extends StatelessWidget {
  final LicaoMapData licao;
  final VoidCallback onStart;

  const LessonStartModal({
    super.key,
    required this.licao,
    required this.onStart,
  });

  // Renderiza os detalhes da lição em folha de ação arredondada
  @override
  Widget build(BuildContext context) {
    final isCompleted = licao.status == LicaoStatus.concluida;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(isCompleted ? '👑' : '🏹', style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIÇÃO ${licao.numero}',
                          style: const TextStyle(
                            color: Color(0xFFD08A45),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          licao.titulo,
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                licao.descricao,
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF182420) : const Color(0xFFEAE7DC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        Text('⭐', style: TextStyle(fontSize: 16)),
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
                        Text('🐚', style: TextStyle(fontSize: 16)),
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
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? const Color(0xFF0E5D4E) : const Color(0xFFD08A45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                ),
                child: Text(
                  isCompleted
                      ? 'REVISAR LIÇÃO'
                      : licao.status == LicaoStatus.emAndamento
                          ? 'CONTINUAR LIÇÃO'
                          : 'COMEÇAR LIÇÃO',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
