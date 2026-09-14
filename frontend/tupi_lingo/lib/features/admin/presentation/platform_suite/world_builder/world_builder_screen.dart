import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import '../shared/floating_toolbar.dart';
import '../shared/status_badge.dart';
import 'entity_property_panel.dart';
import 'publish_pipeline_dialog.dart';
import 'world_builder_canvas.dart';

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
  bool _isLoading = false;
  String _selectedEpoch = '1500: Primeiro Contato';

  List<Map<String, dynamic>> _territories = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _rivers = [];
  List<Map<String, dynamic>> _trails = [];

  Map<String, dynamic>? _selectedEntity;
  String _selectedEntityType = '';

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
    // Centraliza o canvas 4000x4000 na tela com zoom inicial ~0.85
    _transformationController.value = Matrix4.identity()
      ..setTranslationRaw(-1200.0, -1200.0, 0.0)
      ..scaleByDouble(0.85, 0.85, 1.0, 1.0);
  }

  Future<void> _loadWorldData() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/world/active/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? {};
        setState(() {
          _territories = List<Map<String, dynamic>>.from(data['territories'] ?? []);
          _villages = List<Map<String, dynamic>>.from(data['villages'] ?? []);
          _rivers = List<Map<String, dynamic>>.from(data['rivers'] ?? []);
          _trails = List<Map<String, dynamic>>.from(data['trails'] ?? []);
        });
      }
    } catch (_) {
      // Fallback rico com dados etnográficos de Pindorama
      _populateDefaultPindoramaWorld();
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
          'x': 1950.0,
          'y': 1950.0,
          'is_unlocked_default': true,
          'description': 'Principal centro da Confederação dos Tamoios sob liderança de Cunhambebe.',
        },
        {
          'id': 2,
          'name_tupi': 'Karióka',
          'name_portuguese': 'Casa do Homem Branco',
          'biome': 'Mata Atlântica',
          'x': 2250.0,
          'y': 2100.0,
          'is_unlocked_default': true,
          'description': 'Aldeia histórica na foz do rio Carioca na baía de Guanabara.',
        },
        {
          'id': 3,
          'name_tupi': 'Piratininga',
          'name_portuguese': 'Peixe Seco ao Sol',
          'biome': 'Mata Atlântica',
          'x': 2650.0,
          'y': 1980.0,
          'is_unlocked_default': false,
          'description': 'Aldeia liderada por Tibiriçá no planalto paulista.',
        },
      ];

      _rivers = [
        {
          'id': 1,
          'name_tupi': 'Paranapanema',
          'name_portuguese': 'Rio da Água Ruim / Larga',
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
          'waypoints': [
            [1950.0, 1950.0],
            [2250.0, 2100.0],
            [2650.0, 1980.0],
          ],
        },
      ];
    });
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
          'x': pos.dx,
          'y': pos.dy,
          'is_unlocked_default': false,
          'description': 'Nova aldeia adicionada pelo World Builder CMS',
        };
        _villages.add(newVillage);
        _selectedEntity = newVillage;
        _selectedEntityType = 'Aldeia';
      } else if (_activeTool == WorldBuilderTool.territory) {
        final newId = DateTime.now().millisecondsSinceEpoch;
        final newTerritory = {
          'id': newId,
          'name_tupi': 'Novo Território',
          'name_portuguese': 'Região Inexplorada',
          'biome': 'Mata Atlântica',
          'center_x': pos.dx,
          'center_y': pos.dy,
          'is_unlocked_default': false,
          'polygon_coordinates': [
            [pos.dx - 150, pos.dy - 150],
            [pos.dx + 150, pos.dy - 150],
            [pos.dx + 150, pos.dy + 150],
            [pos.dx - 150, pos.dy + 150],
          ],
        };
        _territories.add(newTerritory);
        _selectedEntity = newTerritory;
        _selectedEntityType = 'Território';
      }
    });
  }

  Future<void> _openPublishDialog() async {
    final bundle = {
      'territories': _territories,
      'villages': _villages,
      'rivers': _rivers,
      'trails': _trails,
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PublishPipelineDialog(
        worldBundle: bundle,
        onConfirmPublish: (commitMessage, authorRole, versionTag) async {
          final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/world/publish/');
          await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'commit_message': commitMessage,
              'author_role': authorRole,
              'version_tag': versionTag,
            }),
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Snapshot do Pindorama publicado com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B15),
      body: Column(
        children: [
          // Barra Superior do World Builder
          _buildTopBar(),

          // Área Principal com Canvas e Painel Lateral
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // Canvas Interativo
                    Expanded(
                      child: WorldBuilderCanvas(
                        transformationController: _transformationController,
                        activeTool: _activeTool,
                        showFogPreview: _showFogPreview,
                        territories: _territories,
                        villages: _villages,
                        rivers: _rivers,
                        trails: _trails,
                        selectedEntity: _selectedEntity,
                        onSelectEntity: (entity, type) {
                          setState(() {
                            _selectedEntity = entity;
                            _selectedEntityType = type;
                          });
                        },
                        onCanvasTap: _handleCanvasTap,
                      ),
                    ),

                    // Painel de Propriedades da Entidade
                    EntityPropertyPanel(
                      selectedEntity: _selectedEntity,
                      entityType: _selectedEntityType,
                      onEntityChanged: (updated) {
                        setState(() {
                          _selectedEntity = updated;
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _villages.removeWhere((v) => v['id'] == _selectedEntity?['id']);
                          _territories.removeWhere((t) => t['id'] == _selectedEntity?['id']);
                          _selectedEntity = null;
                        });
                      },
                      onClose: () => setState(() => _selectedEntity = null),
                    ),
                  ],
                ),

                // Floating Toolbar Superior Centralizada
                Positioned(
                  top: 16,
                  left: 0,
                  right: _selectedEntity != null ? 320 : 0,
                  child: Center(
                    child: FloatingWorldToolbar(
                      activeTool: _activeTool,
                      onToolSelected: (tool) => setState(() => _activeTool = tool),
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
                ),
              ],
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
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.public, color: Color(0xFF10B981), size: 26),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pindorama World Builder',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'CMS Topológico & Curadoria Curricular',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 16),
            StatusBadge.draft(label: 'DRAFT v1.2.0'),
            const SizedBox(width: 24),

            // Seletor de Época na Timeline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButton<String>(
                value: _selectedEpoch,
                dropdownColor: const Color(0xFF1E293B),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  : const Icon(Icons.sync, color: Colors.white70),
              tooltip: 'Sincronizar do Backend',
              onPressed: _isLoading ? null : _loadWorldData,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
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
}
