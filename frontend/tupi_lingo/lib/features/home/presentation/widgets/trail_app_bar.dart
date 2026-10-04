import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Barra superior humanizada com indicadores de progresso, idioma e controles rápidos.
class TrailAppBar extends StatelessWidget {
  final String varianteNome;
  final int streakDays;
  final int conchas;
  final int xpTotal;
  final VoidCallback onLanguageTap;
  final VoidCallback onXpTap;
  final VoidCallback onThemeToggle;
  final VoidCallback? onMapTap;
  final VoidCallback? onConchasTap;

  final bool showThemeToggle;

  const TrailAppBar({
    super.key,
    required this.varianteNome,
    required this.streakDays,
    required this.conchas,
    required this.xpTotal,
    required this.onLanguageTap,
    required this.onXpTap,
    required this.onThemeToggle,
    this.onMapTap,
    this.onConchasTap,
    this.showThemeToggle = true,
  });

  static const Color _accent = Color(0xFFD08A45);
  static const Color _streakColor = Color(0xFFE05638);
  static const Color _shellColor = Color(0xFF0E5D4E);
  static const Color _xpColor = Color(0xFFC48B28);

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Variante Ativa Badge com Seletor de Idioma
          Flexible(
            child: GestureDetector(
              onTap: onLanguageTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      size: 14,
                      color: isDark ? const Color(0xFF1EC9A5) : _accent,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        varianteNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF1EC9A5) : _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF1EC9A5) : _accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Métricas de Gamificação: Ofensiva, Conchas, XP
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ofensiva diária (Streak)
                  _buildTopStat(
                    context: context,
                    iconData: Icons.local_fire_department_rounded,
                    label: '$streakDays',
                    color: _streakColor,
                  ),
                  const SizedBox(width: 6),

                  // Conchas
                  GestureDetector(
                    onTap: onConchasTap,
                    child: _buildTopStat(
                      context: context,
                      iconData: Icons.spa_rounded,
                      label: '$conchas',
                      color: isDark ? const Color(0xFF1EC9A5) : _shellColor,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // XP acumulado
                  GestureDetector(
                    onTap: onXpTap,
                    child: _buildTopStat(
                      context: context,
                      iconData: Icons.star_rounded,
                      label: '$xpTotal',
                      color: _xpColor,
                    ),
                  ),

                  if (showThemeToggle) ...[
                    const SizedBox(width: 6),
                    // Alternância Claro / Escuro
                    GestureDetector(
                      onTap: onThemeToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          size: 16,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({
    required BuildContext context,
    required IconData iconData,
    required String label,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
