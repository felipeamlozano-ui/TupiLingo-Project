import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../shared/floating_toolbar.dart';
import '../shared/status_badge.dart';
import 'entity_property_panel.dart';
import 'publish_pipeline_dialog.dart';
import 'world_builder_canvas.dart';
import 'package:tupi_lingo/core/world_engine/world_sync_service.dart';

/// Tela Mestre do World Builder CMS (RFC-013 Capítulo 19).
class WorldBuilderScreen extends ConsumerStatefulWidget {
  const WorldBuilderScreen({super.key});

  @override
  ConsumerState<WorldBuilderScreen> createState() => _WorldBuilderScreenState();
}

class _WorldBuilderScreenState extends ConsumerState<WorldBuilderScreen> {
  final TransformationController _transformationController = TransformationController();
  WorldBuilderTool _activeTool = WorldBuilderTool.select;
  bool _showFogPreview = false;
  double _fogOpacity = 0.85;
  Color _fogColor = const Color(0xFF060B15);
  bool _isLoading = false;
  String _selectedEpoch = '1500: Primeiro Contato';

  // Entidades do Mundo
  List<Map<String, dynamic>> _territories = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _rivers = [];
  List<Map<String, dynamic>> _trails = [];
  List<Map<String, dynamic>> _quests = [];

  // Seleção e Conexão Universal de Nós (Aldeias, Rios, Territórios, Quests)
  Map<String, dynamic>? _selectedEntity;
  String _selectedEntityType = '';
  Map<String, dynamic>? _connectionStartEntity;
  String _connectionStartType = '';

  // Presets de Formato Geométrico (Demanda 1: Edição Total)
  String _selectedRiverShapePreset = 'line';
  String _selectedTerritoryShapePreset = 'free';

  // Gerenciador de Camadas (Overlays)
  bool _layerTerritories = true;
  bool _layerVillages = true;
  bool _layerRivers = true;
  bool _layerTrails = true;
  bool _layerQuests = true;
  bool _layerGrid = true;
  bool _layerLabels = true;

  @override
  void initState() {
    super.initState();
    _centerCanvas();
    _loadWorldData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerCanvas() {
    _transformationController.value = Matrix4.identity()
      ..setTranslationRaw(-1200.0, -1200.0, 0.0)
      ..scaleByDouble(0.85, 0.85, 1.0, 1.0);
  }

  // ─── Geradores Paramétricos de Formas (Demanda 1) ──────────────────────────
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

  Future<void> _loadWorldData() async {
    // 1. Carrega imediatamente o snapshot ativo do WorldSyncService se existir
    final active = WorldSyncService.instance.activeSnapshot;
    if (active != null) {
      setState(() {
        if (active['territories'] != null) _territories = List<Map<String, dynamic>>.from(active['territories']);
        if (active['villages'] != null) _villages = List<Map<String, dynamic>>.from(active['villages']);
        if (active['rivers'] != null) _rivers = List<Map<String, dynamic>>.from(active['rivers']);
        if (active['trails'] != null) _trails = List<Map<String, dynamic>>.from(active['trails']);
        if (active['quests'] != null) _quests = List<Map<String, dynamic>>.from(active['quests']);
      });
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/world/active/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? {};
        setState(() {
          _territories = List<Map<String, dynamic>>.from(data['territories'] ?? _territories);
          _villages = List<Map<String, dynamic>>.from(data['villages'] ?? _villages);
          _rivers = List<Map<String, dynamic>>.from(data['rivers'] ?? _rivers);
          _trails = List<Map<String, dynamic>>.from(data['trails'] ?? _trails);
          _quests = List<Map<String, dynamic>>.from(data['quests'] ?? _quests);
        });
      }
    } catch (_) {
      if (_villages.isEmpty && _territories.isEmpty) {
        _populateDefaultPindoramaWorld();
      }
    } finally {
      if (_villages.isEmpty && _territories.isEmpty) {
        _populateDefaultPindoramaWorld();
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateDefaultPindoramaWorld() {
    setState(() {
      _territories = [
        {
          'id': 1,
          'name_tupi': 'Tupinambá',
          'name_portuguese': 'Costa da Guanabara e Ubatuba',
          'biome': 'Mata Atlântica',
          'center_x': 2000.0,
          'center_y': 2000.0,
          'is_unlocked_default': true,
          'fog_reveal_radius': 240.0,
          'polygon_coordinates': [
            [1700.0, 1800.0],
            [2300.0, 1750.0],
            [2400.0, 2200.0],
            [2100.0, 2400.0],
            [1650.0, 2250.0],
          ],
        },
        {
          'id': 2,
          'name_tupi': 'Tupiniquim',
          'name_portuguese': 'Planalto de Piratininga',
          'biome': 'Mata Atlântica',
          'center_x': 2600.0,
          'center_y': 2000.0,
          'is_unlocked_default': false,
          'fog_reveal_radius': 240.0,
          'polygon_coordinates': [
            [2450.0, 1800.0],
            [2850.0, 1750.0],
            [2900.0, 2300.0],
            [2500.0, 2250.0],
          ],
        },
      ];

      _villages = [
        {
          'id': 1,
          'name_tupi': 'Ubatuba',
          'name_portuguese': 'Lugar de Muitas Canoas',
          'biome': 'Mata Atlântica',
          'village_style': 'canoas',
          'village_color': '#F59E0B',
          'x': 1950.0,
          'y': 1950.0,
          'is_unlocked_default': true,
          'fog_reveal_radius': 190.0,
          'description': 'Principal centro da Confederação dos Tamoios sob liderança de Cunhambebe.',
        },
        {
          'id': 2,
          'name_tupi': 'Karióka',
          'name_portuguese': 'Casa do Homem Branco',
          'biome': 'Mata Atlântica',
          'village_style': 'taba_fort',
          'village_color': '#10B981',
          'x': 2250.0,
          'y': 2100.0,
          'is_unlocked_default': true,
          'fog_reveal_radius': 180.0,
          'description': 'Aldeia histórica na foz do rio Carioca na baía de Guanabara.',
        },
        {
          'id': 3,
          'name_tupi': 'Piratininga',
          'name_portuguese': 'Peixe Seco ao Sol',
          'biome': 'Mata Atlântica',
          'village_style': 'maloca',
          'village_color': '#DC2626',
          'x': 2650.0,
          'y': 1980.0,
          'is_unlocked_default': false,
          'fog_reveal_radius': 170.0,
          'description': 'Aldeia liderada por Tibiriçá no planalto paulista.',
        },
      ];

      _rivers = [
        {
          'id': 1,
          'name_tupi': 'Paranapanema',
          'name_portuguese': 'Rio da Água Ruim / Larga',
          'river_width': 6.0,
          'water_color': '#38BDF8',
          'flow_style': 'currents',
          'bezier_points': [
            [1600.0, 1700.0],
            [1850.0, 1900.0],
            [2200.0, 2050.0],
            [2600.0, 2150.0],
            [2850.0, 2400.0],
          ],
        },
      ];

      _trails = [
        {
          'id': 1,
          'name_tupi': 'Peabiru Histórico',
          'name_portuguese': 'Caminho Ancestral Transcontinental',
          'connection_type': 'terrestre',
          'trail_color': '#F59E0B',
          'trail_style': 'dotted',
          'trail_width': 3.0,
          'from_id': 1,
          'from_type': 'Aldeia',
          'from_name': 'Ubatuba',
          'to_id': 2,
          'to_type': 'Aldeia',
          'to_name': 'Karióka',
          'waypoints': [
            [1950.0, 1950.0],
            [2100.0, 2020.0],
            [2250.0, 2100.0],
          ],
        },
      ];

      _quests = [
        {
          'id': 1,
          'name_tupi': 'Sambaqui de Guaratiba',
          'name_portuguese': 'Sítio Concheiro Arqueológico',
          'biome': 'Mata Atlântica',
          'quest_icon': 'relic',
          'marker_color': '#EAB308',
          'x': 2100.0,
          'y': 2250.0,
          'type': 'ancient_relic',
          'xp_reward': 75,
          'is_unlocked_default': true,
          'fog_reveal_radius': 130.0,
          'description': 'Montículo de conchas e vestígios pré-colombianos de extrema importância arqueológica.',
        },
        {
          'id': 2,
          'name_tupi': 'Itacoatiara do Peabiru',
          'name_portuguese': 'Inscrições Rupestres Sagradas',
          'biome': 'Mata Atlântica',
          'quest_icon': 'scroll',
          'marker_color': '#8B5CF6',
          'x': 2450.0,
          'y': 2040.0,
          'type': 'curiosity',
          'xp_reward': 50,
          'is_unlocked_default': false,
          'fog_reveal_radius': 110.0,
          'description': 'Petroglifos entalhados na rocha ao longo da antiga rota milenar indígena.',
        },
      ];
    });
  }

  Offset _getEntityCenter(Map<String, dynamic> entity) {
    if (entity.containsKey('x') && entity.containsKey('y')) {
      return Offset((entity['x'] as num).toDouble(), (entity['y'] as num).toDouble());
    }
    if (entity.containsKey('center_x') && entity.containsKey('center_y')) {
      return Offset((entity['center_x'] as num).toDouble(), (entity['center_y'] as num).toDouble());
    }
    if (entity.containsKey('bezier_points')) {
      final pts = (entity['bezier_points'] as List?) ?? [];
      if (pts.isNotEmpty) {
        final mid = pts[pts.length ~/ 2] as List;
        return Offset((mid[0] as num).toDouble(), (mid[1] as num).toDouble());
      }
    }
    if (entity.containsKey('waypoints')) {
      final wps = (entity['waypoints'] as List?) ?? [];
      if (wps.isNotEmpty) {
        final mid = wps[wps.length ~/ 2] as List;
        return Offset((mid[0] as num).toDouble(), (mid[1] as num).toDouble());
      }
    }
    return const Offset(2000, 2000);
  }

  void _handleEntityTapForConnection(Map<String, dynamic> entity, String type) {
    if (_connectionStartEntity == null) {
      setState(() {
        _connectionStartEntity = entity;
        _connectionStartType = type;
      });
      final name = entity['name_tupi'] ?? entity['name'] ?? type;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.hub_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Origem: $type "$name". Toque em qualquer elemento para ligar!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (_connectionStartEntity!['id'] == entity['id']) {
      setState(() {
        _connectionStartEntity = null;
        _connectionStartType = '';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleção de nó cancelada.'),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final start = _connectionStartEntity!;
      final startType = _connectionStartType;

      final startPos = _getEntityCenter(start);
      final endPos = _getEntityCenter(entity);

      final midX = (startPos.dx + endPos.dx) / 2;
      final midY = (startPos.dy + endPos.dy) / 2 + 15;

      String connType = 'terrestre';
      String connColor = '#F59E0B';
      String connStyle = 'dotted';

      if (startType == 'Rio' || type == 'Rio') {
        connType = 'fluvial';
        connColor = '#38BDF8';
        connStyle = 'dashed';
      } else if (startType == 'Território' || type == 'Território') {
        connType = 'fronteira';
        connColor = '#10B981';
        connStyle = 'solid';
      } else if (startType.contains('Quest') || type.contains('Quest')) {
        connType = 'terrestre'; // 'expedicao' não existe no dropdown — usa terrestre como fallback válido
        connColor = '#FBBF24';
        connStyle = 'dashed';
      }

      final startName = start['name_tupi'] ?? start['name'] ?? startType;
      final endName = entity['name_tupi'] ?? entity['name'] ?? type;

      final newTrailId = DateTime.now().millisecondsSinceEpoch;
      final newTrail = {
        'id': newTrailId,
        'name_tupi': '$startName ➔ $endName',
        'name_portuguese': 'Conexão $startType a $type',
        'from_id': start['id'],
        'from_type': startType,
        'from_name': startName,
        'to_id': entity['id'],
        'to_type': type,
        'to_name': endName,
        'connection_type': connType,
        'trail_color': connColor,
        'trail_style': connStyle,
        'trail_width': 2.5,
        'waypoints': [
          [startPos.dx, startPos.dy],
          [midX, midY],
          [endPos.dx, endPos.dy],
        ],
      };

      setState(() {
        _trails.add(newTrail);
        _connectionStartEntity = null;
        _connectionStartType = '';
        _selectedEntity = newTrail;
        _selectedEntityType = 'Trilha Histórica';
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Conectado: $startType "$startName" ➔ $type "$endName"!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF064E3B),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleCanvasTap(Offset pos) {
    setState(() {
      if (_activeTool == WorldBuilderTool.village) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        final newVillage = {
          'id': newId,
          'name_tupi': 'Nova Oca $newId',
          'name_portuguese': 'Nova Aldeia',
          'biome': 'Mata Atlântica',
          'village_style': 'oca',
          'village_color': '#F59E0B',
          'x': pos.dx,
          'y': pos.dy,
          'is_unlocked_default': true,
          'fog_reveal_radius': 180.0,
          'description': 'Nova aldeia adicionada pelo World Builder CMS',
        };
        _villages.add(newVillage);
        _selectedEntity = newVillage;
        _selectedEntityType = 'Aldeia';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nova aldeia criada em (${pos.dx.toInt()}, ${pos.dy.toInt()})!'),
            backgroundColor: const Color(0xFF065F46),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (_activeTool == WorldBuilderTool.river) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        final pts = _generateRiverPoints(_selectedRiverShapePreset, pos);
        final isClosed = _selectedRiverShapePreset == 'circle';
        final newRiver = {
          'id': newId,
          'name_tupi': 'Y $newId',
          'name_portuguese': 'Novo Rio',
          'river_width': 5.0,
          'water_color': '#38BDF8',
          'flow_style': 'solid',
          'shape_preset': _selectedRiverShapePreset,
          'is_closed': isClosed,
          'bezier_points': pts,
        };
        _rivers.add(newRiver);
        _selectedEntity = newRiver;
        _selectedEntityType = 'Rio';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Novo curso de rio ($_selectedRiverShapePreset) criado em (${pos.dx.toInt()}, ${pos.dy.toInt()})!'),
            backgroundColor: const Color(0xFF0369A1),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (_activeTool == WorldBuilderTool.territory) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        final poly = _generateTerritoryPoints(_selectedTerritoryShapePreset, pos);
        final newTerritory = {
          'id': newId,
          'name_tupi': 'Novo Território $newId',
          'name_portuguese': 'Região Inexplorada',
          'biome': 'Mata Atlântica',
          'center_x': pos.dx,
          'center_y': pos.dy,
          'is_unlocked_default': false,
          'fog_reveal_radius': 240.0,
          'shape_preset': _selectedTerritoryShapePreset,
          'fill_opacity': 0.25,
          'border_width': 2.0,
          'polygon_coordinates': poly,
        };
        _territories.add(newTerritory);
        _selectedEntity = newTerritory;
        _selectedEntityType = 'Território';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Novo território ($_selectedTerritoryShapePreset) demarcado em (${pos.dx.toInt()}, ${pos.dy.toInt()})!'),
            backgroundColor: const Color(0xFF065F46),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (_activeTool == WorldBuilderTool.quest) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        final newQuest = {
          'id': newId,
          'name_tupi': 'Mba\'épora $newId',
          'name_portuguese': 'Nova Missão / POI',
          'biome': 'Mata Atlântica',
          'quest_icon': 'star',
          'marker_color': '#EAB308',
          'x': pos.dx,
          'y': pos.dy,
          'type': 'curiosity',
          'xp_reward': 50,
          'is_unlocked_default': false,
          'fog_reveal_radius': 120.0,
          'description': 'Ponto de interesse histórico com artefato ou desafio etnográfico.',
        };
        _quests.add(newQuest);
        _selectedEntity = newQuest;
        _selectedEntityType = 'Ponto de Interesse / Quest';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nova Quest criada em (${pos.dx.toInt()}, ${pos.dy.toInt()})!'),
            backgroundColor: const Color(0xFF854D0E),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (_activeTool == WorldBuilderTool.trail) {
        if (_connectionStartEntity != null) {
          final startName = _connectionStartEntity!['name_tupi'] ?? _connectionStartEntity!['name'] ?? _connectionStartType;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Para ligar, toque em outro elemento! (Origem: $_connectionStartType "$startName")'),
              backgroundColor: const Color(0xFFB45309),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Toque em uma aldeia, rio, território ou quest como origem da conexão!'),
              backgroundColor: Color(0xFF1E293B),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (_activeTool == WorldBuilderTool.select) {
        _selectedEntity = null;
        _selectedEntityType = '';
      }
    });
  }

  void _translateSelectedEntity(double dx, double dy) {
    if (_selectedEntity == null) return;
    setState(() {
      final ent = _selectedEntity!;
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
      _selectedEntity = ent;
    });
  }

  void _rotateRiver(double targetAngleDegrees) {
    if (_selectedEntity == null) return;
    final ent = _selectedEntity!;
    if (!ent.containsKey('bezier_points') || ent['bezier_points'] is! List) return;

    final rawPts = ent['bezier_points'] as List;
    if (rawPts.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    for (final p in rawPts) {
      sumX += (p[0] as num).toDouble();
      sumY += (p[1] as num).toDouble();
    }
    final cx = sumX / rawPts.length;
    final cy = sumY / rawPts.length;

    final currentAngle = (ent['angle_degrees'] as num?)?.toDouble() ?? 0.0;
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

    setState(() {
      ent['bezier_points'] = updatedPts;
      ent['angle_degrees'] = targetAngleDegrees % 360.0;
      _selectedEntity = ent;
    });
  }

  void _openOverlayManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.layers, color: AppTheme.accent(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gerenciador de Camadas & Fog of War',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary(context),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ative ou desative as camadas cartográficas e personalize o Fog of War.',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                    const SizedBox(height: 14),

                    // ==================== SEÇÃO DE CAMADAS ====================
                    _buildSectionHeader('CAMADAS CARTOGRÁFICAS'),
                    _buildLayerTile(
                      title: 'Territórios e Fronteiras Tribais',
                      icon: Icons.polyline,
                      color: const Color(0xFF10B981),
                      value: _layerTerritories,
                      onChanged: (val) {
                        setState(() => _layerTerritories = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Aldeias e Centros Populacionais',
                      icon: Icons.holiday_village,
                      color: const Color(0xFFF59E0B),
                      value: _layerVillages,
                      onChanged: (val) {
                        setState(() => _layerVillages = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Rios e Bacias Hidrográficas',
                      icon: Icons.water,
                      color: const Color(0xFF0284C7),
                      value: _layerRivers,
                      onChanged: (val) {
                        setState(() => _layerRivers = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Trilhas & Conexões (Peabiru)',
                      icon: Icons.route,
                      color: const Color(0xFFD97706),
                      value: _layerTrails,
                      onChanged: (val) {
                        setState(() => _layerTrails = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Missões e Pontos de Interesse (Quests)',
                      icon: Icons.explore,
                      color: const Color(0xFFEAB308),
                      value: _layerQuests,
                      onChanged: (val) {
                        setState(() => _layerQuests = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Grid Cartográfico (100m / 500m)',
                      icon: Icons.grid_4x4,
                      color: const Color(0xFF64748B),
                      value: _layerGrid,
                      onChanged: (val) {
                        setState(() => _layerGrid = val);
                        setModalState(() {});
                      },
                    ),
                    _buildLayerTile(
                      title: 'Rótulos e Nomes em Tupi',
                      icon: Icons.label,
                      color: const Color(0xFFA855F7),
                      value: _layerLabels,
                      onChanged: (val) {
                        setState(() => _layerLabels = val);
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 14),
                    // ==================== PERSONALIZAÇÃO DO FOG OF WAR ====================
                    _buildSectionHeader('PERSONALIZAÇÃO DO FOG OF WAR'),
                    _buildLayerTile(
                      title: 'Simulação do Fog of War',
                      icon: Icons.cloud,
                      color: const Color(0xFF38BDF8),
                      value: _showFogPreview,
                      onChanged: (val) {
                        setState(() => _showFogPreview = val);
                        setModalState(() {});
                      },
                    ),

                    if (_showFogPreview) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          'Densidade da Névoa: ${(_fogOpacity * 100).toInt()}%',
                          style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Slider(
                        value: _fogOpacity,
                        min: 0.20,
                        max: 0.98,
                        divisions: 15,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (v) {
                          setState(() => _fogOpacity = v);
                          setModalState(() {});
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: Text(
                          'Tom / Atmosfera da Névoa:',
                          style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFogColorChip('Abismo Noturno', const Color(0xFF060B15), setModalState),
                          _buildFogColorChip('Neblina Selva', const Color(0xFF0A2118), setModalState),
                          _buildFogColorChip('Pergaminho', const Color(0xFF24180C), setModalState),
                          _buildFogColorChip('Crepúsculo Místico', const Color(0xFF151226), setModalState),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.accent(context),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFogColorChip(String label, Color color, StateSetter setModalState) {
    final isSelected = _fogColor == color;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppTheme.textPrimary(context))),
      avatar: CircleAvatar(backgroundColor: color, radius: 7),
      selected: isSelected,
      selectedColor: AppTheme.accent(context),
      backgroundColor: AppTheme.surfaceSubtle(context),
      onSelected: (_) {
        setState(() => _fogColor = color);
        setModalState(() {});
      },
    );
  }

  Widget _buildLayerTile({
    required String title,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600),
      ),
      value: value,
      activeThumbColor: AppTheme.accent(context),
      onChanged: onChanged,
    );
  }

  Future<void> _saveAndApplyWorld({bool showFeedback = true}) async {
    final bundle = {
      'territories': _territories,
      'villages': _villages,
      'rivers': _rivers,
      'trails': _trails,
      'quests': _quests,
      'fog_config': {
        'opacity': _fogOpacity,
        'color': '#${_fogColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      },
    };

    final ok = await WorldSyncService.instance.saveAndApplyWorld(
      bundle: bundle,
      publishToBackend: true,
      commitMessage: 'Alterações instantâneas do World Builder',
      versionTag: '1.3.1',
    );

    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.warning_rounded, color: ok ? const Color(0xFF10B981) : Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? 'Alterações salvas e aplicadas instantaneamente no jogo!'
                      : 'Salvo localmente com garantia offline.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openPublishDialog() async {
    final bundle = {
      'territories': _territories,
      'villages': _villages,
      'rivers': _rivers,
      'trails': _trails,
      'quests': _quests,
      'fog_config': {
        'opacity': _fogOpacity,
        'color': '#${_fogColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      },
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PublishPipelineDialog(
        worldBundle: bundle,
        onConfirmPublish: (commitMessage, authorRole, versionTag) async {
          await WorldSyncService.instance.saveAndApplyWorld(
            bundle: bundle,
            publishToBackend: true,
            commitMessage: commitMessage,
            authorRole: authorRole,
            versionTag: versionTag,
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Snapshot do Pindorama publicado com sucesso e aplicado no jogo!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Column(
        children: [
          // Barra Superior do World Builder
          _buildTopBar(),

          // Área Principal com Canvas e Painel Lateral
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 768;

                return Stack(
                  children: [
                    // Canvas (Ocupa 100% da tela em mobile, ou divide lado a lado em desktop)
                    Row(
                      children: [
                        Expanded(
                          child: WorldBuilderCanvas(
                            transformationController: _transformationController,
                            activeTool: _activeTool,
                            showFogPreview: _showFogPreview,
                            fogOpacity: _fogOpacity,
                            fogColor: _fogColor,
                            territories: _territories,
                            villages: _villages,
                            rivers: _rivers,
                            trails: _trails,
                            quests: _quests,
                            selectedEntity: _selectedEntity,
                            connectionStartEntity: _connectionStartEntity,
                            connectionStartType: _connectionStartType,
                            layerTerritories: _layerTerritories,
                            layerVillages: _layerVillages,
                            layerRivers: _layerRivers,
                            layerTrails: _layerTrails,
                            layerQuests: _layerQuests,
                            layerGrid: _layerGrid,
                            layerLabels: _layerLabels,
                            onSelectEntity: (entity, type) {
                              setState(() {
                                _selectedEntity = entity;
                                _selectedEntityType = type;
                              });
                            },
                            onCanvasTap: _handleCanvasTap,
                            onEntityTapForConnection: _handleEntityTapForConnection,
                            onEntityDrag: (entity, delta) => _translateSelectedEntity(delta.dx, delta.dy),
                          ),
                        ),

                        // Painel Lateral (EXCLUSIVO PARA DESKTOP)
                        if (isDesktop && _selectedEntity != null)
                          EntityPropertyPanel(
                            selectedEntity: _selectedEntity,
                            entityType: _selectedEntityType,
                            isBottomSheet: false,
                            onTranslate: _translateSelectedEntity,
                            onRotateRiver: _rotateRiver,
                            onEntityChanged: (updated) {
                              setState(() {
                                _selectedEntity = updated;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                final id = _selectedEntity?['id'];
                                _villages.removeWhere((v) => v['id'] == id);
                                _territories.removeWhere((t) => t['id'] == id);
                                _rivers.removeWhere((r) => r['id'] == id);
                                _trails.removeWhere((tr) => tr['id'] == id);
                                _quests.removeWhere((q) => q['id'] == id);
                                _selectedEntity = null;
                              });
                            },
                            onClose: () => setState(() => _selectedEntity = null),
                          ),
                      ],
                    ),

                    // Floating Toolbar Superior com Seletor de Formas Paramétricas
                    Positioned(
                      top: 12,
                      left: 12,
                      right: (isDesktop && _selectedEntity != null) ? 356 : 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: FloatingWorldToolbar(
                              activeTool: _activeTool,
                              onToolSelected: (tool) {
                                if (tool == WorldBuilderTool.overlay) {
                                  _openOverlayManager();
                                  return;
                                }
                                setState(() {
                                  _activeTool = tool;
                                  if (tool != WorldBuilderTool.trail) {
                                    _connectionStartEntity = null;
                                    _connectionStartType = '';
                                  }
                                });

                                String msg = '';
                                switch (tool) {
                                  case WorldBuilderTool.select:
                                    msg = 'Modo Seleção: Toque em qualquer elemento para inspecionar e editar.';
                                    break;
                                  case WorldBuilderTool.village:
                                    msg = 'Modo Aldeia: Toque no mapa para posicionar uma nova Oca / Aldeia.';
                                    break;
                                  case WorldBuilderTool.river:
                                    msg = 'Modo Rio: Escolha o formato desejado abaixo e toque no mapa!';
                                    break;
                                  case WorldBuilderTool.trail:
                                    msg = 'Modo Conexão Universal: Toque em qualquer aldeia, rio, território ou quest para ligar!';
                                    break;
                                  case WorldBuilderTool.territory:
                                    msg = 'Modo Território: Escolha a geometria abaixo e demarque no mapa.';
                                    break;
                                  case WorldBuilderTool.quest:
                                    msg = 'Modo Quest: Toque no mapa para posicionar um Ponto de Interesse histórico.';
                                    break;
                                  default:
                                    break;
                                }
                                if (msg.isNotEmpty) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF1E293B),
                                    ),
                                  );
                                }
                              },
                              onZoomIn: () {
                                _transformationController.value = _transformationController.value.clone()..scaleByDouble(1.25, 1.25, 1.0, 1.0);
                              },
                              onZoomOut: () {
                                _transformationController.value = _transformationController.value.clone()..scaleByDouble(0.8, 0.8, 1.0, 1.0);
                              },
                              onResetView: _centerCanvas,
                              showFogPreview: _showFogPreview,
                              onToggleFogPreview: (val) => setState(() => _showFogPreview = val),
                            ),
                          ),
                          if (_activeTool == WorldBuilderTool.river) ...[
                            const SizedBox(height: 8),
                            _buildRiverShapeSelector(context),
                          ] else if (_activeTool == WorldBuilderTool.territory) ...[
                            const SizedBox(height: 8),
                            _buildTerritoryShapeSelector(context),
                          ],
                        ],
                      ),
                    ),

                    // Banner de Instrução em Modo de Conexão Universal (Trail Mode)
                    if (_activeTool == WorldBuilderTool.trail)
                      Positioned(
                        top: 68,
                        left: 16,
                        right: (isDesktop && _selectedEntity != null) ? 364 : 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hub_rounded, color: Color(0xFFF59E0B), size: 17),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _connectionStartEntity == null
                                        ? 'Toque em qualquer aldeia, rio, território ou quest para iniciar'
                                        : 'Origem: $_connectionStartType "${_connectionStartEntity!['name_tupi'] ?? _connectionStartEntity!['name'] ?? ''}". Toque no destino para ligar!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_connectionStartEntity != null) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _connectionStartEntity = null;
                                      _connectionStartType = '';
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Painel Inferior de Propriedades (EM MOBILE / TABLET)
                    if (!isDesktop && _selectedEntity != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: constraints.maxHeight * 0.58,
                        child: Material(
                          elevation: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          color: AppTheme.surface(context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface(context),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              border: Border(top: BorderSide(color: AppTheme.border(context), width: 1.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, -6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: AppTheme.border(context),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: EntityPropertyPanel(
                                    selectedEntity: _selectedEntity,
                                    entityType: _selectedEntityType,
                                    isBottomSheet: true,
                                    onTranslate: _translateSelectedEntity,
                                    onRotateRiver: _rotateRiver,
                                    onEntityChanged: (updated) {
                                      setState(() {
                                        _selectedEntity = updated;
                                      });
                                    },
                                    onDelete: () {
                                      setState(() {
                                        final id = _selectedEntity?['id'];
                                        _villages.removeWhere((v) => v['id'] == id);
                                        _territories.removeWhere((t) => t['id'] == id);
                                        _rivers.removeWhere((r) => r['id'] == id);
                                        _trails.removeWhere((tr) => tr['id'] == id);
                                        _quests.removeWhere((q) => q['id'] == id);
                                        _selectedEntity = null;
                                      });
                                    },
                                    onClose: () => setState(() => _selectedEntity = null),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(bottom: BorderSide(color: AppTheme.border(context))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.public, color: AppTheme.accent(context), size: 26),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pindorama World Builder',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'CMS Topológico & Curadoria Curricular',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            StatusBadge.draft(label: 'DRAFT v1.3.0'),
            const SizedBox(width: 24),

            // Seletor de Época na Timeline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: DropdownButton<String>(
                value: _selectedEpoch,
                dropdownColor: AppTheme.surface(context),
                underline: const SizedBox(),
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  DropdownMenuItem(value: '1500: Primeiro Contato', child: Text('1500: Primeiro Contato')),
                  DropdownMenuItem(value: '1554: Confederação dos Tamoios', child: Text('1554: Confederação dos Tamoios')),
                  DropdownMenuItem(value: '1567: Fundação do Rio de Janeiro', child: Text('1567: Fundação do Rio de Janeiro')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedEpoch = val);
                },
              ),
            ),

            const SizedBox(width: 24),

            // Botões de Ação
            IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent(context)),
                    )
                  : Icon(Icons.sync, color: AppTheme.textSecondary(context)),
              tooltip: 'Sincronizar do Backend',
              onPressed: _isLoading ? null : _loadWorldData,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent(context),
                side: BorderSide(color: AppTheme.accent(context)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text(
                '+ Nova Aldeia',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final newId = DateTime.now().millisecondsSinceEpoch;
                final newVillage = {
                  'id': newId,
                  'name_tupi': 'Nova Oca $newId',
                  'name_portuguese': 'Nova Aldeia',
                  'biome': 'Mata Atlântica',
                  'village_style': 'oca',
                  'village_color': '#F59E0B',
                  'x': 2000.0,
                  'y': 2000.0,
                  'is_unlocked_default': true,
                  'fog_reveal_radius': 180.0,
                  'description': 'Nova aldeia adicionada pelo World Builder CMS',
                };
                setState(() {
                  _villages.add(newVillage);
                  _selectedEntity = newVillage;
                  _selectedEntityType = 'Aldeia';
                });
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Salvar & Aplicar no Jogo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _saveAndApplyWorld(showFeedback: true),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text(
                'Publicar Snapshot',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _openPublishDialog,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Seletores Flutuantes de Formas Paramétricas ───────────────────────────
  Widget _buildRiverShapeSelector(BuildContext context) {
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
              final isSel = _selectedRiverShapePreset == p['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(p['icon'] as IconData, size: 14, color: isSel ? Colors.white : const Color(0xFF38BDF8)),
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
                    if (val) setState(() => _selectedRiverShapePreset = p['id'] as String);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTerritoryShapeSelector(BuildContext context) {
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
              final isSel = _selectedTerritoryShapePreset == p['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(p['icon'] as IconData, size: 14, color: isSel ? Colors.white : const Color(0xFF10B981)),
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
                    if (val) setState(() => _selectedTerritoryShapePreset = p['id'] as String);
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
