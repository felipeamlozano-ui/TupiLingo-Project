import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class TrailAppBar extends StatelessWidget {
  final String varianteNome;
  final int streakDays;
  final int conchas;
  final int xpTotal;
  final VoidCallback onLanguageTap;
  final VoidCallback onXpTap;
  final VoidCallback onThemeToggle;
  final VoidCallback onMapTap;

  const TrailAppBar({
    super.key,
    required this.varianteNome,
    required this.streakDays,
    required this.conchas,
    required this.xpTotal,
    required this.onLanguageTap,
    required this.onXpTap,
    required this.onThemeToggle,
    required this.onMapTap,
  });

  static const Color _accent = Color(0xFFD08A45);
  static const Color _streakColor = Color(0xFFE05638);
  static const Color _shellColor = Color(0xFF2E7D5E);
  static const Color _xpColor = Color(0xFFC48B28);

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const Text('🌿', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
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
                    const SizedBox(width: 2),
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
          const SizedBox(width: 6),

          // Métricas de Gamificação: Ofensiva, Conchas, XP + Atalhos Interativos
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopStat(context: context, icon: '🔥', label: '$streakDays', color: _streakColor),
              const SizedBox(width: 5),
              _buildTopStat(
                context: context,
                icon: '🐚',
                label: '$conchas',
                color: isDark ? const Color(0xFF1EC9A5) : _shellColor,
              ),
              const SizedBox(width: 5),
              // Toque no XP abre o Dashboard de Progresso
              GestureDetector(
                onTap: onXpTap,
                child: _buildTopStat(context: context, icon: '⭐', label: '$xpTotal', color: _xpColor),
              ),
              const SizedBox(width: 5),
              // Botão de alternância rápida de Tema Ancestral (Sol / Lua)
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
                  child: Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 5),
              // Botão do Mapa Interativo de Aldeias
              GestureDetector(
                onTap: onMapTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1EC9A5) : _accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF1EC9A5) : _accent).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text('🗺️', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({
    required BuildContext context,
    required String icon,
    required String label,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Text(icon, style: const TextStyle(fontSize: 13)),
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
