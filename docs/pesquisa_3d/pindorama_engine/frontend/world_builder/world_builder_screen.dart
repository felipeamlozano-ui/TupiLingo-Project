import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/core/world_engine/world_sync_service.dart';
import '../shared/floating_toolbar.dart';
import 'entity_property_panel.dart';
import 'publish_pipeline_dialog.dart';
import 'widgets/pindorama_world_defaults.dart';
import 'widgets/river_geometry_panel.dart';
import 'widgets/shape_selector_bar.dart';
import 'widgets/territory_geometry_panel.dart';
import 'widgets/world_builder_top_bar.dart';
import 'widgets/world_overlay_manager_sheet.dart';
import 'world_builder_canvas.dart';

// Tela Mestre do World Builder CMS (RFC-013 Capítulo 19).
class WorldBuilderScreen extends ConsumerStatefulWidget {
  const WorldBuilderScreen({super.key});

  @override
  ConsumerState<WorldBuilderScreen> createState() => _WorldBuilderScreenState();
}

class _WorldBuilderScreenState extends ConsumerState<WorldBuilderScreen> {
  final TransformationController _transformationController = TransformationController();
  WorldBuilderTool _activeTool = WorldBuilderTool.select;

  // Presets de Criação Rápida
  String _selectedRiverShapePreset = 's_curve';
  String _selectedTerritoryShapePreset = 'free';

  // Entidade Selecionada no Painel de Propriedades
  Map<String, dynamic>? _selectedEntity;
  String _selectedEntityType = '';

  // Modo de Conexão Universal de Trilha
  Map<String, dynamic>? _connectionStartEntity;
  String _connectionStartType = '';

  // Simulação de Fog of War
  bool _showFogPreview = true;
  double _fogOpacity = 0.88;
  Color _fogColor = const Color(0xFF060B15);

  // Época Histórica Ativa
  String _selectedEpoch = '1500: Primeiro Contato';

  // Listas de Entidades Cartográficas em Memória
  List<Map<String, dynamic>> _territories = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _rivers = [];
  List<Map<String, dynamic>> _trails = [];
  List<Map<String, dynamic>> _quests = [];

  bool _isLoading = false;

  // Toggle de Camadas
  bool _layerTerritories = true;
  bool _layerVillages = true;
  bool _layerRivers = true;
  bool _layerTrails = true;
  bool _layerQuests = true;
  bool _layerGrid = true;
  bool _layerLabels = true;

  // Inicializa a tela centralizando a visão cartográfica e carregando os dados do mundo.
  @override
  void initState() {
    super.initState();
    _centerCanvas();
    _loadWorldData();
  }

  // Libera o TransformationController do canvas ao destruir o widget.
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // Reposiciona e ajusta o zoom da câmera do canvas nas coordenadas centrais do mapa.
  void _centerCanvas() {
    _transformationController.value = Matrix4.identity()
      ..setTranslationRaw(-1200.0, -1200.0, 0.0)
      ..scaleByDouble(0.85, 0.85, 1.0, 1.0);
  }

  // Carrega os nós geográficos da API ou do cache sincronizado, com fallback para o mundo padrão.
  Future<void> _loadWorldData() async {
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

  // Popula os arrays do mapa com o cenário histórico padrão de Pindorama.
  void _populateDefaultPindoramaWorld() {
    setState(() {
      _territories = PindoramaWorldDefaults.defaultTerritories();
      _villages = PindoramaWorldDefaults.defaultVillages();
      _rivers = PindoramaWorldDefaults.defaultRivers();
      _trails = PindoramaWorldDefaults.defaultTrails();
      _quests = PindoramaWorldDefaults.defaultQuests();
    });
  }

  // Calcula o ponto médio ou centroide de qualquer entidade para ancorar conexões e trilhas.
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

  // Gerencia a seleção sequencial do nó de origem e nó de destino para traçar caminhos topológicos.
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
        connType = 'terrestre';
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

  // Cria uma nova entidade no ponto exato onde o desenvolvedor tocou dependendo da ferramenta ativa.
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
        final pts = RiverGeometryPanel.generateRiverPoints(_selectedRiverShapePreset, pos);
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
        final poly = TerritoryGeometryPanel.generateTerritoryPoints(_selectedTerritoryShapePreset, pos);
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
          'conchas_reward': 20,
          'is_unlocked_default': false,
          'fog_reveal_radius': 120.0,
          'description': 'Novo ponto de interesse histórico-cultural.',
        };
        _quests.add(newQuest);
        _selectedEntity = newQuest;
        _selectedEntityType = 'Ponto de Interesse';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Novo Ponto de Interesse criado em (${pos.dx.toInt()}, ${pos.dy.toInt()})!'),
            backgroundColor: const Color(0xFF78350F),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (_activeTool == WorldBuilderTool.select) {
        _selectedEntity = null;
        _selectedEntityType = '';
      }
    });
  }

  // Aplica translação cartesiana à entidade selecionada mantendo-a dentro dos limites do canvas.
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

  // Aplica rotação angular aos vértices do curso do rio selecionado.
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
    final deltaRad = (targetAngleDegrees - currentAngle) * (3.141592653589793 / 180.0);
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

  // Exibe o modal inferior de controle de camadas cartográficas e simulação de névoa.
  void _openOverlayManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WorldOverlayManagerSheet(
        layerTerritories: _layerTerritories,
        onLayerTerritoriesChanged: (val) => setState(() => _layerTerritories = val),
        layerVillages: _layerVillages,
        onLayerVillagesChanged: (val) => setState(() => _layerVillages = val),
        layerRivers: _layerRivers,
        onLayerRiversChanged: (val) => setState(() => _layerRivers = val),
        layerTrails: _layerTrails,
        onLayerTrailsChanged: (val) => setState(() => _layerTrails = val),
        layerQuests: _layerQuests,
        onLayerQuestsChanged: (val) => setState(() => _layerQuests = val),
        layerGrid: _layerGrid,
        onLayerGridChanged: (val) => setState(() => _layerGrid = val),
        layerLabels: _layerLabels,
        onLayerLabelsChanged: (val) => setState(() => _layerLabels = val),
        showFogPreview: _showFogPreview,
        onShowFogPreviewChanged: (val) => setState(() => _showFogPreview = val),
        fogOpacity: _fogOpacity,
        onFogOpacityChanged: (val) => setState(() => _fogOpacity = val),
        fogColor: _fogColor,
        onFogColorChanged: (val) => setState(() => _fogColor = val),
      ),
    );
  }

  // Salva o snapshot do mundo no storage local e sincroniza com o backend para refletir no jogo.
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

  // Abre o diálogo de publicação de versão com pipeline de validação e tag de release.
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

  // Monta o layout com barra superior, canvas interativo com suporte a drag-and-drop e painel de propriedades.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Column(
        children: [
          // Barra Superior do World Builder
          WorldBuilderTopBar(
            selectedEpoch: _selectedEpoch,
            onEpochChanged: (val) => setState(() => _selectedEpoch = val),
            isLoading: _isLoading,
            onSyncBackend: _loadWorldData,
            onAddVillage: () {
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
            onSaveAndApply: () => _saveAndApplyWorld(showFeedback: true),
            onPublishSnapshot: _openPublishDialog,
          ),

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
                            RiverShapeSelector(
                              selectedPreset: _selectedRiverShapePreset,
                              onPresetSelected: (val) => setState(() => _selectedRiverShapePreset = val),
                            ),
                          ] else if (_activeTool == WorldBuilderTool.territory) ...[
                            const SizedBox(height: 8),
                            TerritoryShapeSelector(
                              selectedPreset: _selectedTerritoryShapePreset,
                              onPresetSelected: (val) => setState(() => _selectedTerritoryShapePreset = val),
                            ),
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
}
