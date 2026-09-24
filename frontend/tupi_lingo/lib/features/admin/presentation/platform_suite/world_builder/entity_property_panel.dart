import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Painel lateral/inferior de propriedades e customização total do World Builder CMS (RFC-013 Capítulo 19).
/// Suporta angulação e rotação de rios, movimentação universal de todos os elementos e vinculação pedagógica de atividades e exercícios em aldeias.
class EntityPropertyPanel extends StatefulWidget {
  final Map<String, dynamic>? selectedEntity;
  final String entityType;
  final ValueChanged<Map<String, dynamic>> onEntityChanged;
  final void Function(double dx, double dy)? onTranslate;
  final void Function(double targetAngle)? onRotateRiver;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final bool isBottomSheet;

  const EntityPropertyPanel({
    super.key,
    required this.selectedEntity,
    required this.entityType,
    required this.onEntityChanged,
    this.onTranslate,
    this.onRotateRiver,
    required this.onDelete,
    required this.onClose,
    this.isBottomSheet = false,
  });

  @override
  State<EntityPropertyPanel> createState() => _EntityPropertyPanelState();
}

class _EntityPropertyPanelState extends State<EntityPropertyPanel> {
  double _moveStep = 50.0;

  IconData _getEntityIcon(String type) {
    if (type.contains('Aldeia')) return Icons.holiday_village;
    if (type.contains('Território')) return Icons.polyline;
    if (type.contains('Rio')) return Icons.water;
    if (type.contains('Trilha') || type.contains('Conexão')) return Icons.route;
    if (type.contains('Quest') || type.contains('Ponto de Interesse')) return Icons.explore;
    return Icons.tune;
  }

  Color _getEntityColor(String type) {
    if (type.contains('Aldeia')) return const Color(0xFF10B981);
    if (type.contains('Território')) return const Color(0xFF059669);
    if (type.contains('Rio')) return const Color(0xFF0284C7);
    if (type.contains('Trilha') || type.contains('Conexão')) return const Color(0xFFD97706);
    if (type.contains('Quest') || type.contains('Ponto de Interesse')) return const Color(0xFFEAB308);
    return const Color(0xFF10B981);
  }

  void _applyAngleDelta(Map<String, dynamic> entity, double deltaDegrees) {
    final current = (entity['angle_degrees'] as num?)?.toDouble() ?? 0.0;
    var target = (current + deltaDegrees) % 360.0;
    if (target < 0) target += 360.0;
    if (widget.onRotateRiver != null) {
      widget.onRotateRiver!(target);
    } else {
      _rotateRiverLocally(entity, target);
      widget.onEntityChanged(entity);
    }
    setState(() {});
  }

  void _rotateRiverLocally(Map<String, dynamic> entity, double targetAngleDegrees) {
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

  void _handleTranslate(Map<String, dynamic> entity, double dx, double dy) {
    if (widget.onTranslate != null) {
      widget.onTranslate!(dx, dy);
    } else {
      _translateLocally(entity, dx, dy);
      widget.onEntityChanged(entity);
    }
    setState(() {});
  }

  void _translateLocally(Map<String, dynamic> ent, double dx, double dy) {
    // 1. Aldeias e Quests
    if (ent.containsKey('x') && ent.containsKey('y')) {
      final curX = (ent['x'] as num?)?.toDouble() ?? 0.0;
      final curY = (ent['y'] as num?)?.toDouble() ?? 0.0;
      ent['x'] = (curX + dx).clamp(50.0, 3950.0);
      ent['y'] = (curY + dy).clamp(50.0, 3950.0);
    }
    // 2. Rios
    if (ent.containsKey('bezier_points') && ent['bezier_points'] is List) {
      final raw = ent['bezier_points'] as List;
      final updated = <List<double>>[];
      for (final p in raw) {
        final px = (p[0] as num).toDouble() + dx;
        final py = (p[1] as num).toDouble() + dy;
        updated.add([px.clamp(50.0, 3950.0), py.clamp(50.0, 3950.0)]);
      }
      ent['bezier_points'] = updated;
    }
    // 3. Territórios
    if (ent.containsKey('polygon_coords') && ent['polygon_coords'] is List) {
      final raw = ent['polygon_coords'] as List;
      final updated = <List<double>>[];
      for (final p in raw) {
        final px = (p[0] as num).toDouble() + dx;
        final py = (p[1] as num).toDouble() + dy;
        updated.add([px.clamp(50.0, 3950.0), py.clamp(50.0, 3950.0)]);
      }
      ent['polygon_coords'] = updated;
      if (ent.containsKey('center_x')) {
        ent['center_x'] = ((ent['center_x'] as num).toDouble() + dx).clamp(50.0, 3950.0);
      }
      if (ent.containsKey('center_y')) {
        ent['center_y'] = ((ent['center_y'] as num).toDouble() + dy).clamp(50.0, 3950.0);
      }
    }
    // 4. Trilhas
    if (ent.containsKey('waypoints') && ent['waypoints'] is List) {
      final raw = ent['waypoints'] as List;
      final updated = <List<double>>[];
      for (final p in raw) {
        final px = (p[0] as num).toDouble() + dx;
        final py = (p[1] as num).toDouble() + dy;
        updated.add([px.clamp(50.0, 3950.0), py.clamp(50.0, 3950.0)]);
      }
      ent['waypoints'] = updated;
    }
  }

  // ─── Geradores Paramétricos & Manipulação Vetorial de Rios e Territórios (Demanda 1) ───
  List<List<double>> _generateRiverPoints(String preset, Offset center, [double size = 150.0]) {
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

  void _applyRiverShapePreset(Map<String, dynamic> entity, String preset) {
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
    entity['bezier_points'] = _generateRiverPoints(preset, Offset(cx, cy));
    widget.onEntityChanged(entity);
    setState(() {});
  }

  void _scaleRiverPoints(Map<String, dynamic> entity, double scaleFactor) {
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

  void _invertRiverDirection(Map<String, dynamic> entity) {
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.length < 2) return;
    entity['bezier_points'] = rawPts.reversed.toList();
    widget.onEntityChanged(entity);
    setState(() {});
  }

  void _addRiverControlPoint(Map<String, dynamic> entity) {
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
    final updated = List<List<double>>.from(rawPts.map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]));
    updated.add([newX, newY]);
    entity['bezier_points'] = updated;
    widget.onEntityChanged(entity);
    setState(() {});
  }

  void _removeRiverControlPoint(Map<String, dynamic> entity, [int? index]) {
    if (!entity.containsKey('bezier_points') || entity['bezier_points'] is! List) return;
    final rawPts = entity['bezier_points'] as List;
    if (rawPts.length <= 2) return;
    final updated = List<List<double>>.from(rawPts.map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]));
    if (index != null && index >= 0 && index < updated.length) {
      updated.removeAt(index);
    } else {
      updated.removeLast();
    }
    entity['bezier_points'] = updated;
    widget.onEntityChanged(entity);
    setState(() {});
  }

  List<List<double>> _generateTerritoryPoints(String preset, Offset center, [double size = 180.0]) {
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

  void _applyTerritoryShapePreset(Map<String, dynamic> entity, String preset) {
    final cx = (entity['center_x'] as num?)?.toDouble() ?? 2000.0;
    final cy = (entity['center_y'] as num?)?.toDouble() ?? 2000.0;
    entity['shape_preset'] = preset;
    entity['polygon_coordinates'] = _generateTerritoryPoints(preset, Offset(cx, cy));
    widget.onEntityChanged(entity);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = widget.isBottomSheet ? double.infinity : (screenWidth < 360 ? (screenWidth * 0.85) : 340.0);

    if (widget.selectedEntity == null) {
      if (widget.isBottomSheet) return const SizedBox.shrink();
      return Container(
        width: panelWidth,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(left: BorderSide(color: AppTheme.border(context))),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: AppTheme.textSecondary(context), size: 40),
              const SizedBox(height: 12),
              Text(
                'Nenhuma entidade selecionada',
                style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque em uma aldeia, rio, território, quest ou conexão para personalizar',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final entity = widget.selectedEntity!;
    final entityType = widget.entityType;
    final nameTupi = entity['name_tupi'] ?? entity['name'] ?? '';
    final namePt = entity['name_portuguese'] ?? '';
    final biome = entity['biome'] ?? 'Mata Atlântica';
    final isVisibleInFog = entity['is_unlocked_default'] ?? false;
    final revealRadius = (entity['fog_reveal_radius'] as num?)?.toDouble() ?? (entityType.contains('Aldeia') ? 180.0 : 120.0);

    final isVillage = entityType.contains('Aldeia');
    final isRiver = entityType.contains('Rio');
    final isQuest = entityType.contains('Quest') || entityType.contains('Ponto de Interesse');
    final isTrail = entityType.contains('Trilha') || entityType.contains('Conexão');
    final isTerritory = entityType.contains('Território');

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: widget.isBottomSheet
            ? null
            : Border(left: BorderSide(color: AppTheme.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com proteção estrita contra overflow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(_getEntityIcon(entityType), color: _getEntityColor(entityType), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PROPRIEDADES: $entityType',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textSecondary(context), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.border(context), height: 1),

          // Formulário de Customização
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFieldLabel(context, 'Nome em Tupi Antigo'),
                TextFormField(
                  key: ValueKey('tupi_${entity['id']}'),
                  initialValue: nameTupi,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: _inputDecoration(context, 'Ex: Tupinambá, Paranapanema'),
                  onChanged: (val) {
                    entity['name_tupi'] = val;
                    entity['name'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel(context, 'Nome em Português / Tradução'),
                TextFormField(
                  key: ValueKey('pt_${entity['id']}'),
                  initialValue: namePt,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: _inputDecoration(context, 'Ex: Rio de Águas Claras, Oca Central'),
                  onChanged: (val) {
                    entity['name_portuguese'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 14),

                // ==================== CUSTOMIZAÇÃO DE ALDEIA ====================
                if (isVillage) ...[
                  _buildSectionDivider(context, 'ESTILO & ÍCONE DA ALDEIA'),
                  _buildFieldLabel(context, 'Tipo de Oca / Arquitetura'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['village_style'] ?? 'oca',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
                    items: const [
                      DropdownMenuItem(value: 'oca', child: Text('🏕️ Oca Circular Tradicional')),
                      DropdownMenuItem(value: 'maloca', child: Text('🛖 Maloca Comunitária Longa')),
                      DropdownMenuItem(value: 'taba_fort', child: Text('🏰 Taba com Paliçada Fortificada')),
                      DropdownMenuItem(value: 'canoas', child: Text('⛵ Aldeia Portuária / Canoas')),
                      DropdownMenuItem(value: 'acampamento', child: Text('🏹 Acampamento de Caça')),
                      DropdownMenuItem(value: 'sagrado', child: Text('☀️ Centro Cerimonial Sagrado')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        entity['village_style'] = val;
                        widget.onEntityChanged(entity);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Cor do Marcador da Aldeia'),
                  _buildColorPicker(
                    context: context,
                    currentHex: entity['village_color'] ?? '#F59E0B',
                    options: const [
                      {'name': 'Âmbar Ocre', 'hex': '#F59E0B', 'color': Color(0xFFF59E0B)},
                      {'name': 'Verde Selva', 'hex': '#10B981', 'color': Color(0xFF10B981)},
                      {'name': 'Urucum Terra', 'hex': '#DC2626', 'color': Color(0xFFDC2626)},
                      {'name': 'Ciano Maré', 'hex': '#0284C7', 'color': Color(0xFF0284C7)},
                      {'name': 'Dourado Sol', 'hex': '#FBBF24', 'color': Color(0xFFFBBF24)},
                      {'name': 'Púrpura Místico', 'hex': '#9333EA', 'color': Color(0xFF9333EA)},
                    ],
                    onSelect: (hex) {
                      entity['village_color'] = hex;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Tamanho Visual da Aldeia: ${((entity['village_radius'] as num?)?.toDouble() ?? 16.0).toInt()}px'),
                  Slider(
                    value: ((entity['village_radius'] as num?)?.toDouble() ?? 16.0).clamp(10.0, 60.0),
                    min: 10.0,
                    max: 60.0,
                    divisions: 10,
                    activeColor: const Color(0xFF10B981),
                    label: '${((entity['village_radius'] as num?)?.toDouble() ?? 16.0).toInt()}px',
                    onChanged: (val) {
                      entity['village_radius'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildFieldLabel(context, 'Brilho da Fogueira Sagrada: ${((entity['fire_glow_radius'] as num?)?.toDouble() ?? 0.0).toInt()}px'),
                  Slider(
                    value: ((entity['fire_glow_radius'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 60.0),
                    min: 0.0,
                    max: 60.0,
                    divisions: 12,
                    activeColor: const Color(0xFFF59E0B),
                    label: '${((entity['fire_glow_radius'] as num?)?.toDouble() ?? 0.0).toInt()}px',
                    onChanged: (val) {
                      entity['fire_glow_radius'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Paliçada Defensiva Tribal', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Adiciona cerca circular de estacas ao redor da aldeia', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11)),
                    value: entity['has_palisade'] ?? false,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      entity['has_palisade'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  // ==================== ATIVIDADES & EXERCÍCIOS VINCULADOS ====================
                  _buildSectionDivider(context, 'ATIVIDADES & EXERCÍCIOS PEDAGÓGICOS'),
                  _buildLinkedActivitiesSection(context, entity),
                  const SizedBox(height: 14),
                ],

                // ==================== CUSTOMIZAÇÃO DE RIO ====================
                if (isRiver) ...[
                  _buildSectionDivider(context, 'PERSONALIZAÇÃO DO CURSO DE RIO'),
                  
                  // Presets Geométricos Paramétricos do Rio (Demanda 1)
                  _buildFieldLabel(context, 'Formato Geométrico Pré-definido'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildRiverPresetChip(context, entity, 'line', 'Reta', Icons.horizontal_rule),
                      _buildRiverPresetChip(context, entity, 'l_curve', 'Curva L', Icons.turn_right),
                      _buildRiverPresetChip(context, entity, 's_curve', 'Curva S', Icons.waves),
                      _buildRiverPresetChip(context, entity, 'circle', 'Lago / Círculo', Icons.circle_outlined),
                      _buildRiverPresetChip(context, entity, 'zigzag', 'Zigue-Zague', Icons.ssid_chart),
                      _buildRiverPresetChip(context, entity, 'meander', 'Meandro', Icons.water),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Largura / Vazão do Rio: ${((entity['river_width'] as num?)?.toDouble() ?? 4.0).toStringAsFixed(1)}px'),
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
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildFieldLabel(context, 'Opacidade da Água: ${(((entity['water_opacity'] as num?)?.toDouble() ?? 0.85) * 100).toInt()}%'),
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
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildFieldLabel(context, 'Tipo de Água & Bacia'),
                  _buildColorPicker(
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
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Estilo do Fluxo Hidrográfico'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['flow_style'] ?? 'solid',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
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
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // ==================== EDITOR DE VÉRTICES BÉZIER (3D-LIKE) ====================
                  _buildSectionDivider(context, 'VÉRTICES & ESCALA DO CURSO (3D-LIKE)'),
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
                          onPressed: () => _addRiverControlPoint(entity),
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
                          onPressed: () => _removeRiverControlPoint(entity),
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
                        onPressed: () => _invertRiverDirection(entity),
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
                          _buildScaleStepChip('0.75x', () => _scaleRiverPoints(entity, 0.75)),
                          const SizedBox(width: 4),
                          _buildScaleStepChip('1.25x', () => _scaleRiverPoints(entity, 1.25)),
                          const SizedBox(width: 4),
                          _buildScaleStepChip('1.5x', () => _scaleRiverPoints(entity, 1.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ==================== ANGULAÇÃO E ROTAÇÃO DO RIO ====================
                  _buildSectionDivider(context, 'ANGULAÇÃO & ROTAÇÃO HIDROGRÁFICA'),
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
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
                        _rotateRiverLocally(entity, val);
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
                      _buildAngleStepChip('-45°', () => _applyAngleDelta(entity, -45.0)),
                      _buildAngleStepChip('-15°', () => _applyAngleDelta(entity, -15.0)),
                      _buildAngleStepChip('+15°', () => _applyAngleDelta(entity, 15.0)),
                      _buildAngleStepChip('+45°', () => _applyAngleDelta(entity, 45.0)),
                      _buildAngleStepChip('180° Inverter', () => _applyAngleDelta(entity, 180.0)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Presets Cardeais
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildCardinalPresetChip(context, entity, 'Norte (0°)', 0.0),
                      _buildCardinalPresetChip(context, entity, 'Nordeste (45°)', 45.0),
                      _buildCardinalPresetChip(context, entity, 'Leste (90°)', 90.0),
                      _buildCardinalPresetChip(context, entity, 'Sudeste (135°)', 135.0),
                      _buildCardinalPresetChip(context, entity, 'Sul (180°)', 180.0),
                      _buildCardinalPresetChip(context, entity, 'Oeste (270°)', 270.0),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ==================== CUSTOMIZAÇÃO DE QUEST / POI ====================
                if (isQuest) ...[
                  _buildSectionDivider(context, 'PERSONALIZAÇÃO DA MISSÃO / POI'),
                  _buildFieldLabel(context, 'Ícone do Marcador'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['quest_icon'] ?? 'star',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
                    items: const [
                      DropdownMenuItem(value: 'star', child: Text('⭐ Estrela Dourada (Conquista)')),
                      DropdownMenuItem(value: 'explore', child: Text('🧭 Bússola / Exploração')),
                      DropdownMenuItem(value: 'relic', child: Text('🏺 Relíquia Ancestral / Sambaqui')),
                      DropdownMenuItem(value: 'scroll', child: Text('📜 Inscrição Rupestre')),
                      DropdownMenuItem(value: 'fire', child: Text('🔥 Fogueira Sagrada / Ritual')),
                      DropdownMenuItem(value: 'fish', child: Text('🐟 Pesca / Igarapé Mítico')),
                      DropdownMenuItem(value: 'hunt', child: Text('🏹 Caça & Rastreamento')),
                      DropdownMenuItem(value: 'nature', child: Text('🌿 Botânica & Etnofarmacologia')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        entity['quest_icon'] = val;
                        widget.onEntityChanged(entity);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Cor do Marcador de Quest'),
                  _buildColorPicker(
                    context: context,
                    currentHex: entity['marker_color'] ?? '#EAB308',
                    options: const [
                      {'name': 'Dourado', 'hex': '#EAB308', 'color': Color(0xFFEAB308)},
                      {'name': 'Rubi Fogo', 'hex': '#EF4444', 'color': Color(0xFFEF4444)},
                      {'name': 'Esmeralda', 'hex': '#10B981', 'color': Color(0xFF10B981)},
                      {'name': 'Turquesa', 'hex': '#06B6D4', 'color': Color(0xFF06B6D4)},
                      {'name': 'Ametista', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
                    ],
                    onSelect: (hex) {
                      entity['marker_color'] = hex;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Recompensa de Experiência (XP)'),
                  TextFormField(
                    key: ValueKey('xp_${entity['id']}'),
                    initialValue: (entity['xp_reward'] ?? 50).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, 'Ex: 50'),
                    onChanged: (val) {
                      final n = int.tryParse(val) ?? 50;
                      entity['xp_reward'] = n;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Recompensa de Conchas (Moeda)'),
                  TextFormField(
                    key: ValueKey('conchas_${entity['id']}'),
                    initialValue: (entity['conchas_reward'] ?? 25).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, 'Ex: 25'),
                    onChanged: (val) {
                      final n = int.tryParse(val) ?? 25;
                      entity['conchas_reward'] = n;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // ==================== CUSTOMIZAÇÃO DE TRILHA / CONEXÃO ====================
                if (isTrail) ...[
                  _buildSectionDivider(context, 'CONEXÃO TOPOLÓGICA UNIVERSAL'),
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔗 De: ${entity['from_name'] ?? 'Nó Inicial'} (${entity['from_type'] ?? 'Origem'})',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '➔ Para: ${entity['to_name'] ?? 'Nó Final'} (${entity['to_type'] ?? 'Destino'})',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  _buildFieldLabel(context, 'Tipo de Conexão Espacial'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['connection_type'] ?? 'terrestre',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
                    items: const [
                      DropdownMenuItem(value: 'terrestre', child: Text('🥾 Trilha Terrestre / Peabiru')),
                      DropdownMenuItem(value: 'fluvial', child: Text('🛶 Rota Fluvial de Canoa')),
                      DropdownMenuItem(value: 'costeira', child: Text('🌊 Travessia Costeira / Marítima')),
                      DropdownMenuItem(value: 'sagrado', child: Text('⚡ Caminho Espiritual Sagrado')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        entity['connection_type'] = val;
                        widget.onEntityChanged(entity);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Estilo do Traçado no Mapa'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['trail_style'] ?? 'dotted',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
                    items: const [
                      DropdownMenuItem(value: 'dotted', child: Text('••• Pontilhado Histórico')),
                      DropdownMenuItem(value: 'dashed', child: Text('--- Tracejado de Expedição')),
                      DropdownMenuItem(value: 'solid', child: Text('─── Contínuo Consolidado')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        entity['trail_style'] = val;
                        widget.onEntityChanged(entity);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // ==================== CUSTOMIZAÇÃO DE TERRITÓRIO ====================
                if (isTerritory) ...[
                  _buildSectionDivider(context, 'GEOMETRIA DO TERRITÓRIO TRIBAL'),
                  _buildFieldLabel(context, 'Presets de Forma Territorial'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTerritoryPresetChip(context, entity, 'free', 'Livre', Icons.polyline),
                      _buildTerritoryPresetChip(context, entity, 'circle', 'Círculo Tribal', Icons.circle_outlined),
                      _buildTerritoryPresetChip(context, entity, 'rect', 'Retângulo', Icons.crop_square),
                      _buildTerritoryPresetChip(context, entity, 'hex', 'Hexágono', Icons.hexagon_outlined),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel(context, 'Opacidade do Preenchimento: ${(((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25) * 100).toInt()}%'),
                  Slider(
                    value: ((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25).clamp(0.05, 0.70),
                    min: 0.05,
                    max: 0.70,
                    divisions: 13,
                    activeColor: const Color(0xFF10B981),
                    label: '${(((entity['fill_opacity'] as num?)?.toDouble() ?? 0.25) * 100).toInt()}%',
                    onChanged: (val) {
                      entity['fill_opacity'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildFieldLabel(context, 'Espessura da Fronteira: ${((entity['border_width'] as num?)?.toDouble() ?? 2.0).toStringAsFixed(1)}px'),
                  Slider(
                    value: ((entity['border_width'] as num?)?.toDouble() ?? 2.0).clamp(1.0, 8.0),
                    min: 1.0,
                    max: 8.0,
                    divisions: 14,
                    activeColor: const Color(0xFF10B981),
                    label: '${((entity['border_width'] as num?)?.toDouble() ?? 2.0).toStringAsFixed(1)}px',
                    onChanged: (val) {
                      entity['border_width'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Bioma para aldeias e territórios
                if (isVillage || isTerritory) ...[
                  _buildFieldLabel(context, 'Bioma & Atmosfera'),
                  DropdownButtonFormField<String>(
                    initialValue: biome,
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: _inputDecoration(context, ''),
                    items: const [
                      DropdownMenuItem(value: 'Mata Atlântica', child: Text('Mata Atlântica (Costa)')),
                      DropdownMenuItem(value: 'Cerrado', child: Text('Cerrado (Planalto Central)')),
                      DropdownMenuItem(value: 'Amazônia', child: Text('Floresta Amazônica')),
                      DropdownMenuItem(value: 'Caatinga', child: Text('Caatinga (Sertão)')),
                      DropdownMenuItem(value: 'Pantanal', child: Text('Pantanal')),
                      DropdownMenuItem(value: 'Pampa', child: Text('Pampa Sulista')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        entity['biome'] = val;
                        widget.onEntityChanged(entity);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // ==================== UNIVERSAL: POSIÇÃO & DESLOCAMENTO NO MAPA ====================
                _buildSectionDivider(context, 'POSIÇÃO & DESLOCAMENTO NO MAPA'),
                _buildUniversalMovementSection(context, entity),
                const SizedBox(height: 14),

                // ==================== CONFIGURAÇÃO DO FOG OF WAR ====================
                _buildSectionDivider(context, 'VISIBILIDADE & FOG OF WAR'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Desbloqueado por Padrão', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Visível sem necessidade de exploração', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11)),
                  value: isVisibleInFog,
                  activeThumbColor: AppTheme.accent(context),
                  onChanged: (val) {
                    entity['is_unlocked_default'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 8),

                _buildFieldLabel(context, 'Raio de Visão na Névoa: ${revealRadius.toInt()}px'),
                Slider(
                  value: revealRadius.clamp(60.0, 400.0),
                  min: 60.0,
                  max: 400.0,
                  divisions: 17,
                  activeColor: AppTheme.accent(context),
                  label: '${revealRadius.toInt()}px',
                  onChanged: (val) {
                    entity['fog_reveal_radius'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel(context, 'Descrição Histórica & Contexto'),
                TextFormField(
                  key: ValueKey('desc_${entity['id']}'),
                  initialValue: entity['description'] ?? '',
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: _inputDecoration(context, 'Contexto etnográfico, arqueológico ou geográfico'),
                  onChanged: (val) {
                    entity['description'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 24),

                // Botão de Excluir
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir Entidade'),
                  onPressed: widget.onDelete,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Seção Universal de Movimentação (D-Pad e Coordenadas) ─────────────────────────
  Widget _buildUniversalMovementSection(BuildContext context, Map<String, dynamic> entity) {
    String coordsInfo = '';
    if (entity.containsKey('x') && entity.containsKey('y')) {
      final x = (entity['x'] as num?)?.toDouble() ?? 0.0;
      final y = (entity['y'] as num?)?.toDouble() ?? 0.0;
      coordsInfo = 'Posição: (${x.toInt()}, ${y.toInt()})';
    } else if (entity.containsKey('bezier_points') && entity['bezier_points'] is List) {
      final pts = entity['bezier_points'] as List;
      coordsInfo = 'Curso Fluvial: ${pts.length} pontos de ancoragem';
    } else if (entity.containsKey('polygon_coords') && entity['polygon_coords'] is List) {
      final cx = (entity['center_x'] as num?)?.toInt() ?? 2000;
      final cy = (entity['center_y'] as num?)?.toInt() ?? 2000;
      coordsInfo = 'Centro do Território: ($cx, $cy)';
    } else if (entity.containsKey('waypoints') && entity['waypoints'] is List) {
      final pts = entity['waypoints'] as List;
      coordsInfo = 'Traçado da Trilha: ${pts.length} marcos';
    }

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.border(context))),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                tooltip: 'Mover para Cima (${_moveStep.toInt()}px)',
                onPressed: () => _handleTranslate(entity, 0, -_moveStep),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Esquerda
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.border(context))),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    tooltip: 'Mover para Esquerda (${_moveStep.toInt()}px)',
                    onPressed: () => _handleTranslate(entity, -_moveStep, 0),
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
                      style: TextStyle(color: AppTheme.accent(context), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Direita
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.border(context))),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    tooltip: 'Mover para Direita (${_moveStep.toInt()}px)',
                    onPressed: () => _handleTranslate(entity, _moveStep, 0),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Baixo
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surface(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppTheme.border(context))),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                tooltip: 'Mover para Baixo (${_moveStep.toInt()}px)',
                onPressed: () => _handleTranslate(entity, 0, _moveStep),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          border: Border.all(color: isSelected ? AppTheme.accent(context) : AppTheme.border(context)),
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

  // ─── Seção de Atividades e Exercícios da Aldeia ─────────────────────────────────────
  Widget _buildLinkedActivitiesSection(BuildContext context, Map<String, dynamic> entity) {
    final rawList = (entity['linked_activities'] as List<dynamic>?) ?? [];
    final activities = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nenhuma atividade vinculada. Vincule lições e quizzes a este ponto do mapa.',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final act = activities[idx];
              final type = act['type'] ?? 'quiz';
              final title = act['title'] ?? 'Atividade';
              final xp = act['xp'] ?? 20;
              final count = act['exercises_count'] ?? 5;

              IconData icon = Icons.quiz_outlined;
              Color badgeColor = const Color(0xFF10B981);
              String typeName = 'Quiz';
              if (type == 'vocab') {
                icon = Icons.translate_rounded;
                badgeColor = const Color(0xFF38BDF8);
                typeName = 'Vocabulário';
              } else if (type == 'dialogue') {
                icon = Icons.chat_bubble_outline_rounded;
                badgeColor = const Color(0xFFA855F7);
                typeName = 'Diálogo';
              } else if (type == 'writing') {
                icon = Icons.edit_note_rounded;
                badgeColor = const Color(0xFFF59E0B);
                typeName = 'Escrita';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: badgeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(typeName, style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text('$count exercícios • +$xp XP', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Desvincular Atividade',
                      onPressed: () {
                        activities.removeAt(idx);
                        entity['linked_activities'] = activities;
                        widget.onEntityChanged(entity);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 10),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_task_rounded, size: 16),
          label: const Text('Vincular Atividade / Exercício', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: () => _showAddActivityDialog(context, entity, activities),
        ),
      ],
    );
  }

  void _showAddActivityDialog(
    BuildContext context,
    Map<String, dynamic> entity,
    List<Map<String, dynamic>> activities,
  ) {
    String selectedType = 'quiz';
    String activityTitle = 'Desafio de Gramática e Vocabulário';
    int exerciseCount = 5;
    int xpReward = 25;

    final templates = [
      {'title': '1. Saudações e Boas-Vindas da Taba', 'type': 'dialogue', 'count': 4, 'xp': 20},
      {'title': '2. Vocabulário: Fauna da Mata Sagrada', 'type': 'vocab', 'count': 6, 'xp': 25},
      {'title': '3. Quiz: Formação de Palavras em Tupi', 'type': 'quiz', 'count': 5, 'xp': 30},
      {'title': '4. Tradução e Transcrição Rupestre', 'type': 'writing', 'count': 3, 'xp': 20},
      {'title': '5. Desafio Cerimonial do Cacique', 'type': 'quiz', 'count': 8, 'xp': 40},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface(dialogCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.border(dialogCtx)),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_task_rounded, color: AppTheme.accent(dialogCtx)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vincular Atividade à Aldeia',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textPrimary(dialogCtx), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modelos Rápidos Pré-configurados:', style: TextStyle(color: AppTheme.textSecondary(dialogCtx), fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: templates.map((tmpl) {
                        return ActionChip(
                          backgroundColor: AppTheme.surfaceSubtle(dialogCtx),
                          label: Text(tmpl['title'] as String, style: TextStyle(fontSize: 10, color: AppTheme.textPrimary(dialogCtx))),
                          onPressed: () {
                            setDialogState(() {
                              activityTitle = tmpl['title'] as String;
                              selectedType = tmpl['type'] as String;
                              exerciseCount = tmpl['count'] as int;
                              xpReward = tmpl['xp'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel(dialogCtx, 'Título da Atividade'),
                    TextFormField(
                      key: ValueKey('act_title_${DateTime.now().millisecondsSinceEpoch}'),
                      initialValue: activityTitle,
                      style: TextStyle(color: AppTheme.textPrimary(dialogCtx), fontSize: 13),
                      decoration: _inputDecoration(dialogCtx, 'Nome da lição'),
                      onChanged: (val) => activityTitle = val,
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel(dialogCtx, 'Tipo Pedagógico'),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: AppTheme.surface(dialogCtx),
                      style: TextStyle(color: AppTheme.textPrimary(dialogCtx), fontSize: 13),
                      decoration: _inputDecoration(dialogCtx, ''),
                      items: const [
                        DropdownMenuItem(value: 'quiz', child: Text('❓ Quiz Interativo')),
                        DropdownMenuItem(value: 'vocab', child: Text('📚 Vocabulário Mnemônico')),
                        DropdownMenuItem(value: 'dialogue', child: Text('🗣️ Diálogo com Cacique/NPC')),
                        DropdownMenuItem(value: 'writing', child: Text('✍️ Tradução e Escrita')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel(dialogCtx, 'Exercícios: $exerciseCount'),
                              Slider(
                                value: exerciseCount.toDouble(),
                                min: 1,
                                max: 15,
                                divisions: 14,
                                activeColor: AppTheme.accent(dialogCtx),
                                label: '$exerciseCount',
                                onChanged: (val) => setDialogState(() => exerciseCount = val.toInt()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel(dialogCtx, 'XP: $xpReward'),
                              Slider(
                                value: xpReward.toDouble(),
                                min: 10,
                                max: 100,
                                divisions: 18,
                                activeColor: const Color(0xFFF59E0B),
                                label: '$xpReward XP',
                                onChanged: (val) => setDialogState(() => xpReward = val.toInt()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary(dialogCtx))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent(dialogCtx),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final newActivity = {
                      'id': 'act_${DateTime.now().millisecondsSinceEpoch}',
                      'title': activityTitle,
                      'type': selectedType,
                      'exercises_count': exerciseCount,
                      'xp': xpReward,
                    };
                    activities.add(newActivity);
                    entity['linked_activities'] = activities;
                    widget.onEntityChanged(entity);
                    setState(() {});
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Vincular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRiverPresetChip(BuildContext context, Map<String, dynamic> entity, String presetId, String label, IconData icon) {
    final currentPreset = entity['shape_preset'] ?? 'line';
    final isSelected = currentPreset == presetId;

    return InkWell(
      onTap: () => _applyRiverShapePreset(entity, presetId),
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

  Widget _buildTerritoryPresetChip(BuildContext context, Map<String, dynamic> entity, String presetId, String label, IconData icon) {
    final currentPreset = entity['shape_preset'] ?? 'free';
    final isSelected = currentPreset == presetId;

    return InkWell(
      onTap: () => _applyTerritoryShapePreset(entity, presetId),
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

  Widget _buildCardinalPresetChip(BuildContext context, Map<String, dynamic> entity, String label, double angle) {
    final current = (entity['angle_degrees'] as num?)?.toDouble() ?? 0.0;
    final isSelected = (current - angle).abs() < 2.0;

    return InkWell(
      onTap: () {
        if (widget.onRotateRiver != null) {
          widget.onRotateRiver!(angle);
        } else {
          _rotateRiverLocally(entity, angle);
          widget.onEntityChanged(entity);
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

  Widget _buildSectionDivider(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.accent(context),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: AppTheme.border(context), height: 1)),
        ],
      ),
    );
  }

  Widget _buildColorPicker({
    required BuildContext context,
    required String currentHex,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final hex = opt['hex'] as String;
        final color = opt['color'] as Color;
        final name = opt['name'] as String;
        final isSelected = currentHex.toUpperCase() == hex.toUpperCase();

        return Tooltip(
          message: name,
          child: InkWell(
            onTap: () => onSelect(hex),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.black26,
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.check, size: 16, color: Colors.white))
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary(context).withValues(alpha: 0.6), fontSize: 12),
      filled: true,
      fillColor: AppTheme.surfaceSubtle(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.accent(context)),
      ),
    );
  }
}
