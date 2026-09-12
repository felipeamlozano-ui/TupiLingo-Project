import 'package:flutter/material.dart';
import '../../domain/entities/historical_region.dart';
import 'render_brazil_tupi_map.dart';
import 'historical_region_detail_sheet.dart';
import '../../../../core/theme/app_theme.dart';

class InteractiveBrazilTupiMap extends StatefulWidget {
  final List<HistoricalRegion> regions;
  final VoidCallback? onRefresh;

  const InteractiveBrazilTupiMap({
    super.key,
    required this.regions,
    this.onRefresh,
  });

  @override
  State<InteractiveBrazilTupiMap> createState() => _InteractiveBrazilTupiMapState();
}

class _InteractiveBrazilTupiMapState extends State<InteractiveBrazilTupiMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onRegionSelected(HistoricalRegion region) {
    HistoricalRegionDetailSheet.show(
      context,
      region,
      onExplore: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0E5D4E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text(
              '🌿 Iniciando jornada em: ${region.name}!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = widget.regions.where((r) => r.isUnlocked).length;
    final isDark = AppTheme.isDark(context);
    final accentColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Top Bar do Mapa
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pindorama Histórico',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unlockedCount/${widget.regions.length} Aldeias',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mapa Vetorial com Zoom/Pan e RenderBox Direto
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(40),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return BrazilTupiMapRenderWidget(
                            regions: widget.regions,
                            pulseValue: _pulseController.value,
                            onRegionTapped: _onRegionSelected,
                          );
                        },
                      ),
                    ),
                  ),

                  // Botão de Reset de Zoom / Pan
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'reset_zoom_fab',
                      backgroundColor: AppTheme.surface(context),
                      elevation: 2,
                      tooltip: 'Centralizar Mapa',
                      onPressed: () {
                        _transformController.value = Matrix4.identity();
                      },
                      child: Icon(Icons.my_location_rounded, color: accentColor, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
