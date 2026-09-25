import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Barra horizontal de seleção rápida de geometria predefinida ao desenhar novos cursos de rio.
class RiverShapeSelector extends StatelessWidget {
  final String selectedPreset;
  final ValueChanged<String> onPresetSelected;

  const RiverShapeSelector({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  // Renderiza a barra flutuante com chips para linha reta, curvas e meandros hidrográficos.
  @override
  Widget build(BuildContext context) {
    final presets = [
      {'id': 'line', 'label': 'Reta', 'icon': Icons.horizontal_rule},
      {'id': 'l_curve', 'label': 'Curva L', 'icon': Icons.turn_right},
      {'id': 's_curve', 'label': 'Curva S', 'icon': Icons.waves},
      {'id': 'circle', 'label': 'Lago / Círculo', 'icon': Icons.circle_outlined},
      {'id': 'zigzag', 'label': 'Zigue-Zague', 'icon': Icons.ssid_chart},
      {'id': 'meander', 'label': 'Meandro', 'icon': Icons.water},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Formato:',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...presets.map((p) {
              final isSel = selectedPreset == p['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(
                    p['icon'] as IconData,
                    size: 14,
                    color: isSel ? Colors.white : const Color(0xFF38BDF8),
                  ),
                  label: Text(p['label'] as String),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : AppTheme.textPrimary(context),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF0284C7),
                  backgroundColor: AppTheme.surfaceSubtle(context),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (val) {
                    if (val) onPresetSelected(p['id'] as String);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Barra horizontal de seleção de polígono ao criar novas demarcações de terras tribais.
class TerritoryShapeSelector extends StatelessWidget {
  final String selectedPreset;
  final ValueChanged<String> onPresetSelected;

  const TerritoryShapeSelector({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  // Renderiza as opções de contorno poligonal (livre, círculo, retângulo e hexágono).
  @override
  Widget build(BuildContext context) {
    final presets = [
      {'id': 'free', 'label': 'Livre', 'icon': Icons.polyline},
      {'id': 'circle', 'label': 'Círculo Tribal', 'icon': Icons.circle_outlined},
      {'id': 'rect', 'label': 'Retângulo', 'icon': Icons.crop_square},
      {'id': 'hex', 'label': 'Hexágono', 'icon': Icons.hexagon_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Polígono:',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...presets.map((p) {
              final isSel = selectedPreset == p['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(
                    p['icon'] as IconData,
                    size: 14,
                    color: isSel ? Colors.white : const Color(0xFF10B981),
                  ),
                  label: Text(p['label'] as String),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : AppTheme.textPrimary(context),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: AppTheme.surfaceSubtle(context),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (val) {
                    if (val) onPresetSelected(p['id'] as String);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
