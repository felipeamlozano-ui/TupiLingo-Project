import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Painel com D-Pad direcional para transladar qualquer entidade no mapa em passos customizáveis.
class UniversalMovementPanel extends StatefulWidget {
  final Map<String, dynamic> entity;
  final void Function(double dx, double dy) onTranslate;

  const UniversalMovementPanel({
    super.key,
    required this.entity,
    required this.onTranslate,
  });

  @override
  State<UniversalMovementPanel> createState() => _UniversalMovementPanelState();
}

class _UniversalMovementPanelState extends State<UniversalMovementPanel> {
  double _moveStep = 50.0;

  // Monta o resumo textual das coordenadas da entidade dependendo da sua geometria.
  String _getCoordinatesSummary() {
    final entity = widget.entity;
    if (entity.containsKey('x') && entity.containsKey('y')) {
      final x = (entity['x'] as num?)?.toDouble() ?? 0.0;
      final y = (entity['y'] as num?)?.toDouble() ?? 0.0;
      return 'Posição: (${x.toInt()}, ${y.toInt()})';
    } else if (entity.containsKey('bezier_points') && entity['bezier_points'] is List) {
      final pts = entity['bezier_points'] as List;
      return 'Curso Fluvial: ${pts.length} pontos de ancoragem';
    } else if (entity.containsKey('polygon_coords') && entity['polygon_coords'] is List) {
      final cx = (entity['center_x'] as num?)?.toInt() ?? 2000;
      final cy = (entity['center_y'] as num?)?.toInt() ?? 2000;
      return 'Centro do Território: ($cx, $cy)';
    } else if (entity.containsKey('waypoints') && entity['waypoints'] is List) {
      final pts = entity['waypoints'] as List;
      return 'Traçado da Trilha: ${pts.length} marcos';
    }
    return '';
  }

  // Chip para selecionar a resolução do deslocamento em pixels.
  Widget _buildStepSelectChip(double step, String label) {
    final isSelected = _moveStep == step;
    return InkWell(
      onTap: () => setState(() => _moveStep = step),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent(context) : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.accent(context) : AppTheme.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary(context),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Constrói o layout completo com indicador de posição, seletor de passos e botões cardeais.
  @override
  Widget build(BuildContext context) {
    final coordsInfo = _getCoordinatesSummary();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                coordsInfo,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                children: [
                  _buildStepSelectChip(10.0, '10px'),
                  const SizedBox(width: 4),
                  _buildStepSelectChip(50.0, '50px'),
                  const SizedBox(width: 4),
                  _buildStepSelectChip(100.0, '100px'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // D-Pad Direcional
          Column(
            children: [
              // Cima
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.border(context)),
                  ),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                tooltip: 'Mover para Cima (${_moveStep.toInt()}px)',
                onPressed: () => widget.onTranslate(0, -_moveStep),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Esquerda
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.border(context)),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    tooltip: 'Mover para Esquerda (${_moveStep.toInt()}px)',
                    onPressed: () => widget.onTranslate(-_moveStep, 0),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent(context).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '±${_moveStep.toInt()}px',
                      style: TextStyle(
                        color: AppTheme.accent(context),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Direita
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.border(context)),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    tooltip: 'Mover para Direita (${_moveStep.toInt()}px)',
                    onPressed: () => widget.onTranslate(_moveStep, 0),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Baixo
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.border(context)),
                  ),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                tooltip: 'Mover para Baixo (${_moveStep.toInt()}px)',
                onPressed: () => widget.onTranslate(0, _moveStep),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
