import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class XpProgressBar extends StatelessWidget {
  final int xpTotal;

  const XpProgressBar({super.key, required this.xpTotal});

  // Tiers: Semente=0, Folha=500, Arco=1500, Guerreiro=4000, Pajé=8000, Guardião=15000
  (int, int, String) get nextTierInfo {
    if (xpTotal < 500) return (0, 500, 'Folha da Floresta (500 XP)');
    if (xpTotal < 1500) return (500, 1500, 'Arco Certeiro (1500 XP)');
    if (xpTotal < 4000) return (1500, 4000, 'Guerreiro Audaz (4000 XP)');
    if (xpTotal < 8000) return (4000, 8000, 'Pajé Sábio (8000 XP)');
    if (xpTotal < 15000) return (8000, 15000, 'Guardião da Terra (15000 XP)');
    return (15000, 20000, 'Grau Máximo de Mestria 👑');
  }

  @override
  Widget build(BuildContext context) {
    final (baseXp, targetXp, nextTitle) = nextTierInfo;
    final progress = ((xpTotal - baseXp) / (targetXp - baseXp)).clamp(0.0, 1.0);
    final falta = (targetXp - xpTotal).clamp(0, targetXp);
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Jornada de XP',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$xpTotal XP Total',
                style: const TextStyle(
                  color: Color(0xFFD08A45),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? const Color(0xFF1E2A25) : const Color(0xFFEAE7DC),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD08A45)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Próxima: $nextTitle',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (falta > 0) ...[
                const SizedBox(width: 8),
                Text(
                  'Faltam $falta XP',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
