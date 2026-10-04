import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';
import '../widgets/chapter_banner_card.dart';
import '../widgets/trail_canvas_view.dart';

/// Aba principal com o caminho serpenteante da trilha e navegação de capítulos.
class TrailTabView extends StatelessWidget {
  final List<CapituloMapData> capitulos;
  final int selectedCapituloIndex;
  final ValueChanged<int> onSelectCapituloIndex;
  final AnimationController? pulseController;
  final AnimationController? floatController;
  final VoidCallback onReloadTrail;
  final ValueChanged<CapituloMapData> onCulturalGuideTap;
  final ValueChanged<LicaoMapData> onLessonTap;
  final void Function(CapituloMapData, ChestRewardMapData) onChestTap;
  final void Function(CapituloMapData, ChestRewardMapData?) onCollectedChestTap;

  const TrailTabView({
    super.key,
    required this.capitulos,
    required this.selectedCapituloIndex,
    required this.onSelectCapituloIndex,
    required this.pulseController,
    required this.floatController,
    required this.onReloadTrail,
    required this.onCulturalGuideTap,
    required this.onLessonTap,
    required this.onChestTap,
    required this.onCollectedChestTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD08A45);

    if (capitulos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Nenhum capítulo publicado para esta variante.',
              style: TextStyle(color: Color(0xFF565D6D)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReloadTrail,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Recarregar Trilha'),
            ),
          ],
        ),
      );
    }

    final safeIndex = (selectedCapituloIndex >= 0 && selectedCapituloIndex < capitulos.length)
        ? selectedCapituloIndex
        : 0;
    final cap = capitulos[safeIndex];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Seletor de Capítulos
            _buildChapterTabsHeader(context),
            const SizedBox(height: 14),

            // Card Principal da Unidade / Capítulo
            ChapterBannerCard(
              cap: cap,
              onCulturalGuideTap: () => onCulturalGuideTap(cap),
            ),
            const SizedBox(height: 24),

            // O Caminho de Lições
            TrailCanvasView(
              cap: cap,
              isCurrentActiveChapter: (safeIndex < capitulos.length && capitulos[safeIndex].id == cap.id),
              pulseController: pulseController,
              floatController: floatController,
              onLessonTap: onLessonTap,
              onChestTap: onChestTap,
              onCollectedChestTap: onCollectedChestTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterTabsHeader(BuildContext context) {
    const primaryColor = Color(0xFFD08A45);

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: capitulos.length,
        itemBuilder: (context, i) {
          final isSelected = i == selectedCapituloIndex;
          final cap = capitulos[i];
          return GestureDetector(
            onTap: () => onSelectCapituloIndex(i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected ? primaryColor : AppTheme.border(context),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Capítulo ${cap.numero}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
