import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/home/data/models/chapter_cultural_guides.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';

/// Diálogo com contexto cultural, saberes ancestrais e curiosidades linguísticas do capítulo.
class CulturalGuideDialog extends StatelessWidget {
  final CapituloMapData cap;

  const CulturalGuideDialog({super.key, required this.cap});

  static Future<void> show(BuildContext context, CapituloMapData cap) {
    return showDialog(
      context: context,
      builder: (ctx) => CulturalGuideDialog(cap: cap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guide = ChapterCulturalGuide.getForChapter(cap.numero, defaultTitulo: cap.titulo);
    final isDark = AppTheme.isDark(context);
    final primaryColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFFD08A45);

    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_stories_rounded, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guia do Capítulo ${guide.numero}',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  guide.subtitulo,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.titulo,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_edu_rounded, color: AppTheme.accent(context), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        guide.saberesAncestrais,
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD08A45).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD08A45).withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_rounded, color: Color(0xFFD08A45), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Curiosidade Linguística',
                          style: TextStyle(
                            color: Color(0xFFD08A45),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.curiosidadeLinguistica,
                      style: TextStyle(
                        color: AppTheme.textPrimary(context).withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expressão em Destaque:',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.expressaoDestaque,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      guide.expressaoTraducao,
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'Entendido',
            style: TextStyle(
              color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
