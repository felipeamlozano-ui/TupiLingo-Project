import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class RecentLessonsList extends StatelessWidget {
  final List<Map<String, dynamic>> historico;

  const RecentLessonsList({super.key, required this.historico});

  @override
  Widget build(BuildContext context) {
    if (historico.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
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
            children: [
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Últimas Lições Concluídas',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...historico.take(5).map((l) {
            final titulo = l['titulo'] ?? 'Lição';
            final capTitulo = l['capitulo_titulo'] ?? '';
            final accuracyPercent = (l['accuracy_percent'] as num?)?.toInt() ?? 0;
            final earnedXp = (l['earned_xp'] as num?)?.toInt() ?? 0;

            final isPerfect = accuracyPercent == 100;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2621) : const Color(0xFFFAF9F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPerfect
                      ? (isDark ? const Color(0xFF1EC9A5).withValues(alpha: 0.5) : const Color(0xFF0E5D4E).withValues(alpha: 0.3))
                      : AppTheme.border(context),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPerfect
                          ? (isDark ? const Color(0xFF1EC9A5).withValues(alpha: 0.2) : const Color(0xFF0E5D4E).withValues(alpha: 0.15))
                          : const Color(0xFFD08A45).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isPerfect ? '💎' : '🏹',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (capTitulo.isNotEmpty)
                          Text(
                            capTitulo,
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPerfect
                              ? (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E))
                              : const Color(0xFFD08A45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$accuracyPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+$earnedXp XP',
                        style: const TextStyle(
                          color: Color(0xFFD08A45),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
