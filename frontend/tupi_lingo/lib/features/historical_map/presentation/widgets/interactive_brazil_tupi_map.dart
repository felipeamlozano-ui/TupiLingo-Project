import 'package:flutter/material.dart';
import '../../domain/entities/historical_region.dart';
import 'render_brazil_tupi_map.dart';
import 'historical_region_detail_sheet.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8F3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD0D0D0).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5D4E).withValues(alpha: 0.08),
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
                  const Expanded(
                    child: Text(
                      'Pindorama Histórico',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unlockedCount/${widget.regions.length} Aldeias',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E5D4E),
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
                      backgroundColor: Colors.white,
                      elevation: 2,
                      tooltip: 'Centralizar Mapa',
                      onPressed: () {
                        _transformController.value = Matrix4.identity();
                      },
                      child: const Icon(Icons.my_location_rounded, color: Color(0xFF0E5D4E), size: 18),
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
