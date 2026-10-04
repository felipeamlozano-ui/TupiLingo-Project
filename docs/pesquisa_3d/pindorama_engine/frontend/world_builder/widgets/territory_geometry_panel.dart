import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'entity_property_helpers.dart';

// Painel dedicado à customização poligonal de demarcações territoriais indígenas e tribais.
class TerritoryGeometryPanel extends StatelessWidget {
  final Map<String, dynamic> entity;
  final ValueChanged<Map<String, dynamic>> onEntityChanged;

  const TerritoryGeometryPanel({
    super.key,
    required this.entity,
    required this.onEntityChanged,
  });

  // Calcula a malha de pontos do polígono para círculos, retângulos, hexágonos ou formas livres.
  static List<List<double>> generateTerritoryPoints(String preset, Offset center, [double size = 180.0]) {
    final cx = center.dx;
    final cy = center.dy;
    switch (preset) {
      case 'circle':
        final pts = <List<double>>[];
        for (var i = 0; i < 12; i++) {
          final angle = i * 2 * pi / 12;
          pts.add([cx + size * cos(angle), cy + size * sin(angle)]);
        }
        return pts;
      case 'rect':
        return [
          [cx - size, cy - size * 0.7],
          [cx + size, cy - size * 0.7],
          [cx + size, cy + size * 0.7],
          [cx - size, cy + size * 0.7],
        ];
      case 'hex':
        final pts = <List<double>>[];
        for (var i = 0; i < 6; i++) {
          final angle = i * 2 * pi / 6;
          pts.add([cx + size * cos(angle), cy + size * sin(angle)]);
        }
        return pts;
      case 'free':
      default:
        return [
          [cx - size, cy - size * 0.65],
          [cx + size * 0.85, cy - size * 0.8],
          [cx + size * 1.1, cy + size * 0.55],
          [cx + size * 0.1, cy + size],
          [cx - size * 0.9, cy + size * 0.65],
        ];
    }
  }

  // Aplica o molde geométrico selecionado recalculando os vértices em torno do centro do território.
  void _applyTerritoryShapePreset(String preset) {
    final cx = (entity['center_x'] as num?)?.toDouble() ?? 2000.0;
    final cy = (entity['center_y'] as num?)?.toDouble() ?? 2000.0;
    entity['shape_preset'] = preset;
    entity['polygon_coordinates'] = generateTerritoryPoints(preset, Offset(cx, cy));
    onEntityChanged(entity);
  }

  // Chip de seleção de formato predefinido de território com badge comemorativo.
  Widget _buildTerritoryPresetChip(BuildContext context, String presetId, String label, IconData icon) {
    final currentPreset = entity['shape_preset'] ?? 'free';
    final isSelected = currentPreset == presetId;

    return InkWell(
      onTap: () => _applyTerritoryShapePreset(presetId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669).withValues(alpha: 0.25) : AppTheme.surfaceSubtle(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : AppTheme.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF10B981) : AppTheme.textSecondary(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF10B981) : AppTheme.textPrimary(context),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Monta a seção de geometria territorial com presets, transparência e largura de borda.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionDivider(context, 'GEOMETRIA DO TERRITÓRIO TRIBAL'),
        buildFieldLabel(context, 'Presets de Forma Territorial'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildTerritoryPresetChip(context, 'free', 'Livre', Icons.polyline),
            _buildTerritoryPresetChip(context, 'circle', 'Círculo Tribal', Icons.circle_outlined),
            _buildTerritoryPresetChip(context, 'rect', 'Retângulo', Icons.crop_square),
            _buildTerritoryPresetChip(context, 'hex', 'Hexágono', Icons.hexagon_outlined),
          ],
        ),
        const SizedBox(height: 14),

        buildFieldLabel(
          context,
          'Opacidade do Preenchimento: ${(((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25) * 100).toInt()}%',
        ),
        Slider(
          value: ((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25).clamp(0.05, 0.70),
          min: 0.05,
          max: 0.70,
          divisions: 13,
          activeColor: const Color(0xFF10B981),
          label: '${(((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25) * 100).toInt()}%',
          onChanged: (val) {
            entity['fill_opacity'] = val;
            onEntityChanged(entity);
          },
        ),
        const SizedBox(height: 10),

        buildFieldLabel(
          context,
          'Espessura da Fronteira: ${((entity['border_width'] as num?)?.toDouble() ?? 2.0).toStringAsFixed(1)}px',
        ),
        Slider(
          value: ((entity['border_width'] as num?)?.toDouble() ?? 2.0).clamp(1.0, 8.0),
          min: 1.0,
          max: 8.0,
          divisions: 14,
          activeColor: const Color(0xFF10B981),
          label: '${((entity['border_width'] as num?)?.toDouble() ?? 2.0).toStringAsFixed(1)}px',
          onChanged: (val) {
            entity['border_width'] = val;
            onEntityChanged(entity);
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
