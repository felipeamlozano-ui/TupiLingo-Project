import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'widgets/entity_property_helpers.dart';
import 'widgets/linked_activities_panel.dart';
import 'widgets/river_geometry_panel.dart';
import 'widgets/territory_geometry_panel.dart';
import 'widgets/universal_movement_panel.dart';

// Painel lateral e gaveta de customização avançada de todas as entidades do mapa do World Builder.
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
  // Retorna o ícone representativo no cabeçalho conforme a categoria do elemento cartográfico.
  IconData _getEntityIcon(String type) {
    if (type.contains('Aldeia')) return Icons.holiday_village;
    if (type.contains('Território')) return Icons.polyline;
    if (type.contains('Rio')) return Icons.water;
    if (type.contains('Trilha') || type.contains('Conexão')) return Icons.route;
    if (type.contains('Quest') || type.contains('Ponto de Interesse')) return Icons.explore;
    return Icons.tune;
  }

  // Define a paleta de acentuação do cabeçalho de acordo com a semântica da entidade.
  Color _getEntityColor(String type) {
    if (type.contains('Aldeia')) return const Color(0xFF10B981);
    if (type.contains('Território')) return const Color(0xFF059669);
    if (type.contains('Rio')) return const Color(0xFF0284C7);
    if (type.contains('Trilha') || type.contains('Conexão')) return const Color(0xFFD97706);
    if (type.contains('Quest') || type.contains('Ponto de Interesse')) return const Color(0xFFEAB308);
    return const Color(0xFF10B981);
  }

  // Notifica o callback de translação global ou desloca os pontos localmente caso o callback seja nulo.
  void _handleTranslate(Map<String, dynamic> entity, double dx, double dy) {
    if (widget.onTranslate != null) {
      widget.onTranslate!(dx, dy);
    } else {
      _translateLocally(entity, dx, dy);
      widget.onEntityChanged(entity);
    }
    setState(() {});
  }

  // Move os pontos no plano cartesiano local mantendo todas as coordenadas dentro dos limites do mapa.
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

  // Constrói o painel de propriedades completo com formulários contextuais para o tipo selecionado.
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
                buildFieldLabel(context, 'Nome em Tupi Antigo'),
                TextFormField(
                  key: ValueKey('tupi_${entity['id']}'),
                  initialValue: nameTupi,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: entityInputDecoration(context, 'Ex: Tupinambá, Paranapanema'),
                  onChanged: (val) {
                    entity['name_tupi'] = val;
                    entity['name'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 14),

                buildFieldLabel(context, 'Nome em Português / Tradução'),
                TextFormField(
                  key: ValueKey('pt_${entity['id']}'),
                  initialValue: namePt,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: entityInputDecoration(context, 'Ex: Rio de Águas Claras, Oca Central'),
                  onChanged: (val) {
                    entity['name_portuguese'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 14),

                // ==================== CUSTOMIZAÇÃO DE ALDEIA ====================
                if (isVillage) ...[
                  buildSectionDivider(context, 'ESTILO & ÍCONE DA ALDEIA'),
                  buildFieldLabel(context, 'Tipo de Oca / Arquitetura'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['village_style'] ?? 'oca',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, ''),
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

                  buildFieldLabel(context, 'Cor do Marcador da Aldeia'),
                  buildColorPicker(
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

                  buildFieldLabel(
                    context,
                    'Tamanho Visual da Aldeia: ${((entity['village_radius'] as num?)?.toDouble() ?? 16.0).toInt()}px',
                  ),
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

                  buildFieldLabel(
                    context,
                    'Brilho da Fogueira Sagrada: ${((entity['fire_glow_radius'] as num?)?.toDouble() ?? 0.0).toInt()}px',
                  ),
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
                    title: Text(
                      'Paliçada Defensiva Tribal',
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Adiciona cerca circular de estacas ao redor da aldeia',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                    value: entity['has_palisade'] ?? false,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      entity['has_palisade'] = val;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Atividades Pedagógicas Vinculadas
                  buildSectionDivider(context, 'ATIVIDADES & EXERCÍCIOS PEDAGÓGICOS'),
                  LinkedActivitiesPanel(
                    entity: entity,
                    onEntityChanged: widget.onEntityChanged,
                  ),
                  const SizedBox(height: 14),
                ],

                // ==================== CUSTOMIZAÇÃO DE RIO ====================
                if (isRiver) ...[
                  RiverGeometryPanel(
                    entity: entity,
                    onEntityChanged: widget.onEntityChanged,
                    onRotateRiver: widget.onRotateRiver,
                  ),
                ],

                // ==================== CUSTOMIZAÇÃO DE QUEST / POI ====================
                if (isQuest) ...[
                  buildSectionDivider(context, 'PERSONALIZAÇÃO DA MISSÃO / POI'),
                  buildFieldLabel(context, 'Ícone do Marcador'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['quest_icon'] ?? 'star',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, ''),
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

                  buildFieldLabel(context, 'Cor do Marcador de Quest'),
                  buildColorPicker(
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

                  buildFieldLabel(context, 'Recompensa de Experiência (XP)'),
                  TextFormField(
                    key: ValueKey('xp_${entity['id']}'),
                    initialValue: (entity['xp_reward'] ?? 50).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, 'Ex: 50'),
                    onChanged: (val) {
                      final n = int.tryParse(val) ?? 50;
                      entity['xp_reward'] = n;
                      widget.onEntityChanged(entity);
                    },
                  ),
                  const SizedBox(height: 14),

                  buildFieldLabel(context, 'Recompensa de Conchas (Moeda)'),
                  TextFormField(
                    key: ValueKey('conchas_${entity['id']}'),
                    initialValue: (entity['conchas_reward'] ?? 25).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, 'Ex: 25'),
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
                  buildSectionDivider(context, 'CONEXÃO TOPOLÓGICA UNIVERSAL'),
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

                  buildFieldLabel(context, 'Tipo de Conexão Espacial'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['connection_type'] ?? 'terrestre',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, ''),
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

                  buildFieldLabel(context, 'Estilo do Traçado no Mapa'),
                  DropdownButtonFormField<String>(
                    initialValue: entity['trail_style'] ?? 'dotted',
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, ''),
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
                  TerritoryGeometryPanel(
                    entity: entity,
                    onEntityChanged: widget.onEntityChanged,
                  ),
                ],

                // Bioma para aldeias e territórios
                if (isVillage || isTerritory) ...[
                  buildFieldLabel(context, 'Bioma & Atmosfera'),
                  DropdownButtonFormField<String>(
                    initialValue: biome,
                    dropdownColor: AppTheme.surface(context),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: entityInputDecoration(context, ''),
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
                buildSectionDivider(context, 'POSIÇÃO & DESLOCAMENTO NO MAPA'),
                UniversalMovementPanel(
                  entity: entity,
                  onTranslate: (dx, dy) => _handleTranslate(entity, dx, dy),
                ),
                const SizedBox(height: 14),

                // ==================== CONFIGURAÇÃO DO FOG OF WAR ====================
                buildSectionDivider(context, 'VISIBILIDADE & FOG OF WAR'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Desbloqueado por Padrão',
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Visível sem necessidade de exploração',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                  ),
                  value: isVisibleInFog,
                  activeThumbColor: AppTheme.accent(context),
                  onChanged: (val) {
                    entity['is_unlocked_default'] = val;
                    widget.onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 8),

                buildFieldLabel(context, 'Raio de Visão na Névoa: ${revealRadius.toInt()}px'),
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

                buildFieldLabel(context, 'Descrição Histórica & Contexto'),
                TextFormField(
                  key: ValueKey('desc_${entity['id']}'),
                  initialValue: entity['description'] ?? '',
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: entityInputDecoration(context, 'Contexto etnográfico, arqueológico ou geográfico'),
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
}
