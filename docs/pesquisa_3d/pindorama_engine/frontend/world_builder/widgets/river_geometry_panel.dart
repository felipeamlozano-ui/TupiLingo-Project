import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'entity_property_helpers.dart';

// Painel dedicado à customização vetorial profunda de rios (curvas Bézier, rotação, vazão e presets).
class RiverGeometryPanel extends StatefulWidget {
  final Map<String, dynamic> entity;
  final ValueChanged<Map<String, dynamic>> onEntityChanged;
  final void Function(double targetAngle)? onRotateRiver;

  const RiverGeometryPanel({
    super.key,
    required this.entity,
    required this.onEntityChanged,
    this.onRotateRiver,
  });

  // Gera coordenadas cartesianas paramétricas de acordo com a forma hidrográfico selecionada.
  static List<List<double>> generateRiverPoints(String preset, Offset center, [double size = 150.0]) {
    final cx = center.dx;
    final cy = center.dy;
    switch (preset) {
      case 'l_curve':
        return [
          [cx - size * 0.8, cy - size * 0.8],
          [cx, cy - size * 0.8],
          [cx, cy],
          [cx, cy + size * 0.8],
        ];
      case 's_curve':
        return [
          [cx - size, cy - size * 0.45],
          [cx - size * 0.35, cy + size * 0.45],
          [cx + size * 0.35, cy - size * 0.45],
          [cx + size, cy + size * 0.45],
        ];
      case 'circle':
        final r = size * 0.75;
        final pts = <List<double>>[];
        for (var i = 0; i <= 8; i++) {
          final angle = (i % 8) * 2 * pi / 8;
          pts.add([cx + r * cos(angle), cy + r * sin(angle)]);
        }
        return pts;
      case 'zigzag':
        return [
          [cx - size, cy - size * 0.4],
          [cx - size * 0.6, cy + size * 0.4],
          [cx - size * 0.2, cy - size * 0.4],
          [cx + size * 0.2, cy + size * 0.4],
          [cx + size * 0.6, cy - size * 0.4],
          [cx + size, cy + size * 0.4],
        ];
      case 'meander':
        return [
          [cx - size * 1.2, cy - size * 0.3],
          [cx - size * 0.8, cy + size * 0.5],
          [cx - size * 0.4, cy - size * 0.4],
          [cx, cy + size * 0.5],
          [cx + size * 0.4, cy - size * 0.4],
          [cx + size * 0.8, cy + size * 0.5],
          [cx + size * 1.2, cy - size * 0.3],
        ];
      case 'line':
      default:
        return [
          [cx - size, cy],
          [cx - size / 3, cy],
          [cx + size / 3, cy],
          [cx + size, cy],
        ];
    }
  }

  @override
  State<RiverGeometryPanel> createState() => _RiverGeometryPanelState();
}

class _RiverGeometryPanelState extends State<RiverGeometryPanel> {

  // Aplica uma geometria predefinida ao rio preservando seu ponto central na tela.
  void _applyRiverShapePreset(String preset) {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    double cx = 2000.0, cy = 2000.0;
    if (rawPts.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final p in rawPts) {
        sumX += (p[0] as num).toDouble();
        sumY += (p[1] as num).toDouble();
      }
      cx = sumX / rawPts.length;
      cy = sumY / rawPts.length;
    }
    entity['shape_preset'] = preset;
    entity['is_closed'] = (preset == 'circle');
    entity['bezier_points'] = RiverGeometryPanel.generateRiverPoints(preset, Offset(cx, cy));
    widget.onEntityChanged(entity);
    setState(() {});
  }

  // Redimensiona uniformemente a escala dos pontos do rio em relação ao seu centroide.
  void _scaleRiverPoints(double scaleFactor) {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.isEmpty) return;
    double sumX = 0, sumY = 0;
    for (final p in rawPts) {
      sumX += (p[0] as num).toDouble();
      sumY += (p[1] as num).toDouble();
    }
    final cx = sumX / rawPts.length;
    final cy = sumY / rawPts.length;
    final updated = <List<double>>[];
    for (final p in rawPts) {
      final px = (p[0] as num).toDouble();
      final py = (p[1] as num).toDouble();
      final nx = cx + (px - cx) * scaleFactor;
      final ny = cy + (py - cy) * scaleFactor;
      updated.add([nx.clamp(50.0, 3950.0), ny.clamp(50.0, 3950.0)]);
    }
    entity['bezier_points'] = updated;
    widget.onEntityChanged(entity);
    setState(() {});
  }

  // Inverte a sequência dos pontos para inverter a direção visual de fluxo da correnteza.
  void _invertRiverDirection() {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.length < 2) return;
    entity['bezier_points'] = rawPts.reversed.toList();
    widget.onEntityChanged(entity);
    setState(() {});
  }

  // Adiciona um novo vértice de ancoragem ao final da lista estendendo o leito do rio.
  void _addRiverControlPoint() {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.isEmpty) return;
    final last = rawPts.last as List;
    final secondLast = rawPts.length > 1 ? rawPts[rawPts.length - 2] as List : last;
    final dx = (last[0] as num).toDouble() - (secondLast[0] as num).toDouble();
    final dy = (last[1] as num).toDouble() - (secondLast[1] as num).toDouble();
    final step = (dx == 0 && dy == 0) ? const Offset(60.0, 40.0) : Offset(dx, dy);
    final newX = ((last[0] as num).toDouble() + step.dx).clamp(50.0, 3950.0);
    final newY = ((last[1] as num).toDouble() + step.dy).clamp(50.0, 3950.0);
    final updated = List<List<double>>.from(
      rawPts.map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]),
    );
    updated.add([newX, newY]);
    entity['bezier_points'] = updated;
    widget.onEntityChanged(entity);
    setState(() {});
  }

  // Remove um ponto de controle assegurando que o rio mantenha o mínimo de dois vértices.
  void _removeRiverControlPoint([int? index]) {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.length <= 2) return;
    final updated = List<List<double>>.from(
      rawPts.map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]),
    );
    if (index != null && index >= 0 && index < updated.length) {
      updated.removeAt(index);
    } else {
      updated.removeLast();
    }
    entity['bezier_points'] = updated;
    widget.onEntityChanged(entity);
    setState(() {});
  }

  // Incrementa ou decrementa a rotação do rio em graus relativos à sua orientação atual.
  void _applyAngleDelta(double deltaDegrees) {
    final entity = widget.entity;
    final current = (entity['angle_degrees'] as num?)?.toDouble() ?? 0.0;
    var target = (current + deltaDegrees) % 360.0;
    if (target < 0) target += 360.0;
    if (widget.onRotateRiver != null) {
      widget.onRotateRiver!(target);
    } else {
      _rotateRiverLocally(target);
      widget.onEntityChanged(entity);
    }
    setState(() {});
  }

  // Aplica matriz de rotação 2D em torno do baricentro do rio quando não há callback global.
  void _rotateRiverLocally(double targetAngleDegrees) {
    final entity = widget.entity;
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    for (final p in rawPts) {
      sumX += (p[0] as num).toDouble();
      sumY += (p[1] as num).toDouble();
    }
    final cx = sumX / rawPts.length;
    final cy = sumY / rawPts.length;

    final currentAngle = (entity['angle_degrees'] as num?)?.toDouble() ?? 0.0;
    final deltaRad = (targetAngleDegrees - currentAngle) * (pi / 180.0);
    final cosT = cos(deltaRad);
    final sinT = sin(deltaRad);

    final updatedPts = <List<double>>[];
    for (final p in rawPts) {
      final px = (p[0] as num).toDouble() - cx;
      final py = (p[1] as num).toDouble() - cy;
      final rx = cx + (px * cosT - py * sinT);
      final ry = cy + (px * sinT + py * cosT);
      updatedPts.add([rx.clamp(50.0, 3950.0), ry.clamp(50.0, 3950.0)]);
    }

    entity['bezier_points'] = updatedPts;
    entity['angle_degrees'] = targetAngleDegrees % 360.0;
  }

  // Chip de seleção de formato predefinido de rio com feedback visual ativo.
  Widget _buildRiverPresetChip(String presetId, String label, IconData icon) {
    final currentPreset = widget.entity['shape_preset'] ?? 'line';
    final isSelected = currentPreset == presetId;

    return InkWell(
      onTap: () => _applyRiverShapePreset(presetId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.25) : AppTheme.surfaceSubtle(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : AppTheme.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF38BDF8) : AppTheme.textSecondary(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF38BDF8) : AppTheme.textPrimary(context),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chip de atalho para multiplicador de escala da geometria fluvial.
  Widget _buildScaleStepChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Chip de botão para acréscimo rápido de ângulo de rotação.
  Widget _buildAngleStepChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Chip para apontar a orientação fluvial diretamente para um ponto cardeal predeterminado.
  Widget _buildCardinalPresetChip(String label, double angle) {
    final current = (widget.entity['angle_degrees'] as num?)?.toDouble() ?? 0.0;
    final isSelected = (current - angle).abs() < 2.0;

    return InkWell(
      onTap: () {
        if (widget.onRotateRiver != null) {
          widget.onRotateRiver!(angle);
        } else {
          _rotateRiverLocally(angle);
          widget.onEntityChanged(widget.entity);
        }
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.2) : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : AppTheme.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : AppTheme.textSecondary(context),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Constrói todas as seções de edição do rio: formato, vazão, cor, vértices Bézier e rotação.
  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionDivider(context, 'PERSONALIZAÇÃO DO CURSO DE RIO'),

        // Presets Geométricos Paramétricos do Rio
        buildFieldLabel(context, 'Formato Geométrico Pré-definido'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildRiverPresetChip('line', 'Reta', Icons.horizontal_rule),
            _buildRiverPresetChip('l_curve', 'Curva L', Icons.turn_right),
            _buildRiverPresetChip('s_curve', 'Curva S', Icons.waves),
            _buildRiverPresetChip('circle', 'Lago / Círculo', Icons.circle_outlined),
            _buildRiverPresetChip('zigzag', 'Zigue-Zague', Icons.ssid_chart),
            _buildRiverPresetChip('meander', 'Meandro', Icons.water),
          ],
        ),
        const SizedBox(height: 14),

        buildFieldLabel(
          context,
          'Largura / Vazão do Rio: ${((entity['river_width'] as num?)?.toDouble() ?? 4.0).toStringAsFixed(1)}px',
        ),
        Slider(
          value: ((entity['river_width'] as num?)?.toDouble() ?? 4.0).clamp(2.0, 24.0),
          min: 2.0,
          max: 24.0,
          divisions: 22,
          activeColor: const Color(0xFF38BDF8),
          label: '${((entity['river_width'] as num?)?.toDouble() ?? 4.0).toStringAsFixed(1)}px',
          onChanged: (val) {
            entity['river_width'] = val;
            widget.onEntityChanged(entity);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),

        buildFieldLabel(
          context,
          'Opacidade da Água: ${(((entity['water_opacity'] as num?)?.toDouble() ?? 0.85) * 100).toInt()}%',
        ),
        Slider(
          value: ((entity['water_opacity'] as num?)?.toDouble() ?? 0.85).clamp(0.2, 1.0),
          min: 0.2,
          max: 1.0,
          divisions: 16,
          activeColor: const Color(0xFF38BDF8),
          label: '${(((entity['water_opacity'] as num?)?.toDouble() ?? 0.85) * 100).toInt()}%',
          onChanged: (val) {
            entity['water_opacity'] = val;
            widget.onEntityChanged(entity);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),

        buildFieldLabel(context, 'Tipo de Água & Bacia'),
        buildColorPicker(
          context: context,
          currentHex: entity['water_color'] ?? '#38BDF8',
          options: const [
            {'name': 'Águas Claras', 'hex': '#38BDF8', 'color': Color(0xFF38BDF8)},
            {'name': 'Rio Negro', 'hex': '#0F172A', 'color': Color(0xFF0F172A)},
            {'name': 'Águas Barrentas', 'hex': '#B45309', 'color': Color(0xFFB45309)},
            {'name': 'Igarapé Selva', 'hex': '#059669', 'color': Color(0xFF059669)},
            {'name': 'Rio Sagrado', 'hex': '#EAB308', 'color': Color(0xFFEAB308)},
            {'name': 'Oceano / Mar', 'hex': '#1E40AF', 'color': Color(0xFF1E40AF)},
            {'name': 'Lagoa Argila', 'hex': '#DC2626', 'color': Color(0xFFDC2626)},
          ],
          onSelect: (hex) {
            entity['water_color'] = hex;
            widget.onEntityChanged(entity);
            setState(() {});
          },
        ),
        const SizedBox(height: 14),

        buildFieldLabel(context, 'Estilo do Fluxo Hidrográfico'),
        DropdownButtonFormField<String>(
          initialValue: entity['flow_style'] ?? 'solid',
          dropdownColor: AppTheme.surface(context),
          style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
          decoration: entityInputDecoration(context, ''),
          items: const [
            DropdownMenuItem(value: 'solid', child: Text('🌊 Contínuo (Perene)')),
            DropdownMenuItem(value: 'dashed', child: Text('╌ Intermitente / Estiagem')),
            DropdownMenuItem(value: 'currents', child: Text('≈ Correnteza Ondulada Suave')),
            DropdownMenuItem(value: 'wave_particles', child: Text('⚡ Corredeira Espumante')),
          ],
          onChanged: (val) {
            if (val != null) {
              entity['flow_style'] = val;
              widget.onEntityChanged(entity);
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 14),

        // Editor de Vértices Bézier
        buildSectionDivider(context, 'VÉRTICES & ESCALA DO CURSO (3D-LIKE)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Vértice', style: TextStyle(fontSize: 11)),
                onPressed: _addRiverControlPoint,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Rem. Último', style: TextStyle(fontSize: 11)),
                onPressed: _removeRiverControlPoint,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF38BDF8)),
              tooltip: 'Inverter Sentido da Correnteza',
              onPressed: _invertRiverDirection,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Escala Proporcional Rápida
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Redimensionar Curso:', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 11)),
            Row(
              children: [
                _buildScaleStepChip('0.75x', () => _scaleRiverPoints(0.75)),
                const SizedBox(width: 4),
                _buildScaleStepChip('1.25x', () => _scaleRiverPoints(1.25)),
                const SizedBox(width: 4),
                _buildScaleStepChip('1.5x', () => _scaleRiverPoints(1.5)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Angulação e Rotação do Rio
        buildSectionDivider(context, 'ANGULAÇÃO & ROTAÇÃO HIDROGRÁFICA'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Orientação do Rio:',
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
              ),
              child: Text(
                '${((entity['angle_degrees'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: ((entity['angle_degrees'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 360.0),
          min: 0.0,
          max: 360.0,
          divisions: 72,
          activeColor: const Color(0xFF38BDF8),
          label: '${((entity['angle_degrees'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}°',
          onChanged: (val) {
            if (widget.onRotateRiver != null) {
              widget.onRotateRiver!(val);
            } else {
              _rotateRiverLocally(val);
              widget.onEntityChanged(entity);
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 6),

        // Passos Rápidos de Rotação
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildAngleStepChip('-45°', () => _applyAngleDelta(-45.0)),
            _buildAngleStepChip('-15°', () => _applyAngleDelta(-15.0)),
            _buildAngleStepChip('+15°', () => _applyAngleDelta(15.0)),
            _buildAngleStepChip('+45°', () => _applyAngleDelta(45.0)),
            _buildAngleStepChip('180° Inverter', () => _applyAngleDelta(180.0)),
          ],
        ),
        const SizedBox(height: 10),

        // Presets Cardeais
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildCardinalPresetChip('Norte (0°)', 0.0),
            _buildCardinalPresetChip('Nordeste (45°)', 45.0),
            _buildCardinalPresetChip('Leste (90°)', 90.0),
            _buildCardinalPresetChip('Sudeste (135°)', 135.0),
            _buildCardinalPresetChip('Sul (180°)', 180.0),
            _buildCardinalPresetChip('Oeste (270°)', 270.0),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
