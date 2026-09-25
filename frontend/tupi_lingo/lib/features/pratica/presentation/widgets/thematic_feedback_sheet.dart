import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// Modal inferior exibido após cada resposta com feedback visual, XP/conchas obtidos e explicação
class ThematicFeedbackSheet extends StatelessWidget {
  final bool isCorrect;
  final String status;
  final String message;
  final String explicacao;
  final int earnedXp;
  final int earnedConchas;
  final bool isLastItem;
  final VoidCallback onContinue;

  const ThematicFeedbackSheet({
    super.key,
    required this.isCorrect,
    required this.status,
    required this.message,
    required this.explicacao,
    required this.earnedXp,
    required this.earnedConchas,
    required this.isLastItem,
    required this.onContinue,
  });

  // Abre a folha modal de feedback na parte inferior da tela
  static void show({
    required BuildContext context,
    required bool isCorrect,
    required String status,
    required String message,
    required String explicacao,
    required int earnedXp,
    required int earnedConchas,
    required bool isLastItem,
    required VoidCallback onContinue,
  }) {
    final bool isAlmost = status == 'almost';
    final Color bgColor = isCorrect
        ? const Color(0xFFEAF3F1)
        : (isAlmost ? const Color(0xFFFFF9E6) : const Color(0xFFFDECEE));

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => ThematicFeedbackSheet(
        isCorrect: isCorrect,
        status: status,
        message: message,
        explicacao: explicacao,
        earnedXp: earnedXp,
        earnedConchas: earnedConchas,
        isLastItem: isLastItem,
        onContinue: () {
          Navigator.pop(ctx);
          onContinue();
        },
      ),
    );
  }

  // Renderiza o conteúdo do modal com ícone indicativo e botão de avanço
  @override
  Widget build(BuildContext context) {
    final bool isAlmost = status == 'almost';
    final Color accentColor = isCorrect
        ? const Color(0xFF0E5D4E)
        : (isAlmost ? const Color(0xFFD08A45) : const Color(0xFFE05638));

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : (isAlmost ? Icons.lightbulb_rounded : Icons.cancel_rounded),
                  color: accentColor,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCorrect ? 'Mandou bem!' : (isAlmost ? 'Quase lá!' : 'Ops!'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (earnedXp > 0 || earnedConchas > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (earnedXp > 0)
                          Text(
                            '+$earnedXp XP ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              fontSize: 13,
                            ),
                          ),
                        if (earnedConchas > 0)
                          Text(
                            '+$earnedConchas 🐚',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0E5D4E),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (explicacao.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                explicacao,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary(context),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                isLastItem ? 'VER RESULTADO CONSOLIDADO' : 'CONTINUAR',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
