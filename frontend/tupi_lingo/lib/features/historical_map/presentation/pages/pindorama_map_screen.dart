import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/world_engine/camera/camera_state.dart';
import '../../../../core/world_engine/camera/world_camera_controller.dart';
import '../../../../core/world_engine/fog/fog_engine.dart';
import '../../../../core/world_engine/fog/fog_state.dart';
import '../../../../core/world_engine/particles/world_particle_pool.dart';
import '../../../../core/world_engine/rendering/pindorama_world_viewport.dart';
import '../../../../core/world_engine/trails/historical_trail.dart';
import '../../../../core/world_engine/trails/historical_overlay.dart';
import '../../../../core/world_engine/trails/river_path.dart';
import '../../../../core/world_engine/villages/village_node.dart';
import '../../../../core/world_engine/world_sync_service.dart';
import '../../domain/entities/territory_node.dart';
import '../../domain/entities/lesson_node.dart';
import '../../domain/entities/quest_node.dart';
import '../../domain/services/curriculum_world_graph.dart';
import 'package:tupi_lingo/features/lesson/presentation/lesson_player.dart';
import 'package:tupi_lingo/features/pratica/presentation/thematic_practice_screen.dart';
import '../widgets/historical_timeline_slider.dart';
import '../widgets/journey_sheet_widget.dart';
import '../widgets/mini_map_widget.dart';
import '../widgets/pindorama_expressive_hud.dart';

/// Fullscreen AAA Interactive Curriculum World (RFC-012C Patch 1).
///
/// Features:
/// - Smooth spring physics camera with elastic bounds, pan inertia, and desktop mouse wheel zoom.
/// - Clickable 5-epoch historical timeline engine controlling visible routes, villages, and alliances.
/// - Expandable Journey Sheet displaying chapter lessons with instant execution flow.
/// - Contextual atmospheric particle pool and dynamic quest beacons.
/// - MiniMap radar and Material 3 Expressive HUD.
class PindoramaMapScreen extends StatefulWidget {
  final Map<String, double>? bktMasteryMap;

  const PindoramaMapScreen({
    super.key,
    this.bktMasteryMap,
  });

  @override
  State<PindoramaMapScreen> createState() => _PindoramaMapScreenState();
}

class _PindoramaMapScreenState extends State<PindoramaMapScreen> {
  late final WorldCameraController _cameraController;
  late final WorldParticlePool _particlePool;
  late CurriculumWorldGraph _curriculumGraph;

  late List<VillageNode> _villages;
  late List<RiverPath> _rivers;
  late List<HistoricalTrail> _trails;
  late List<HistoricalOverlay> _overlays;
  late FogState _fogState;

  VillageNode? _selectedVillage;
  TerritoryNode? _activeTerritory;
  QuestNode? _activeQuest;
  HistoricalEpoch _currentEpoch = HistoricalEpoch.epoch1554;
  final bool _showMiniMap = true;

  @override
  void initState() {
    super.initState();
    _cameraController = WorldCameraController(
      initialState: const CameraState(
        x: 5000.0,
        y: 5000.0,
        zoom: 0.95,
      ),
    );
    _particlePool = WorldParticlePool();
    _curriculumGraph = CurriculumWorldGraph();

    WorldSyncService.instance.activeWorldNotifier.addListener(_onWorldSnapshotChanged);
    _initWorldData();
  }

  void _onWorldSnapshotChanged() {
    if (!mounted) return;
    setState(() {
      _initWorldData();
    });
  }

  void _initWorldData() {
    final activeBundle = WorldSyncService.instance.activeSnapshot;
    if (activeBundle != null && (activeBundle['villages'] != null || activeBundle['rivers'] != null)) {
      final customVillages = WorldSyncService.instance.parseVillages(activeBundle);
      final customRivers = WorldSyncService.instance.parseRivers(activeBundle);
      final customTrails = WorldSyncService.instance.parseTrails(activeBundle);
      final customTerritories = WorldSyncService.instance.parseTerritories(activeBundle);

      _curriculumGraph = CurriculumWorldGraph(
        villages: customVillages,
        territories: customTerritories,
      );
      _villages = customVillages;
      _rivers = customRivers;
      _trails = customTrails;
    } else {
      _villages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
      _rivers = [
        RiverPath.canonicalTiete,
        RiverPath.canonicalParaiba,
      ];
      _trails = HistoricalTrail.canonicalTrails;
    }

    _overlays = HistoricalOverlay.canonicalOverlays
        .where((o) => o.epochId == _currentEpoch.id)
        .toList();
    _activeQuest = _curriculumGraph.getActiveMainQuest();

    _fogState = FogEngine.computeFromWorld(
      villages: _villages,
      trails: _trails,
      bktMasteryMap: widget.bktMasteryMap,
    );

    _particlePool.initializeDefaults(villages: _villages);
  }

  @override
  void dispose() {
    WorldSyncService.instance.activeWorldNotifier.removeListener(_onWorldSnapshotChanged);
    _cameraController.dispose();
    super.dispose();
  }

  void _onVillageSelected(VillageNode village) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedVillage = village;
      _activeTerritory = _curriculumGraph.getTerritoryForVillage(village.id);
    });

    // Smooth camera fly-to focusing on village
    _cameraController.flyTo(
      village.coordinate,
      zoom: (_cameraController.zoom < 1.2 ? 1.35 : _cameraController.zoom),
    );
  }

  void _onVillageLongPressed(VillageNode village) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: const Color(0xEE0B1519),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                border: Border.all(color: const Color(0x55E5A93C), width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield, color: Color(0xFFFFD54F), size: 24.0),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'Memória Ancestral: ${village.tupiName}',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      village.historicalContext,
                      style: const TextStyle(color: Colors.white, fontSize: 13.0, height: 1.4),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Líder: ${village.leaderName} (${village.dialectVariant})',
                      style: const TextStyle(color: Color(0xFF80CBC4), fontSize: 12.0, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onVillageSelected(village);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5A93C),
                          foregroundColor: const Color(0xFF10191F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        child: const Text('Explorar Capítulo', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onVillageDoubleTapped(VillageNode village) {
    _cameraController.flyTo(village.coordinate, zoom: 2.0);
  }

  void _onEpochChanged(HistoricalEpoch newEpoch) {
    setState(() {
      _currentEpoch = newEpoch;
      _villages = _curriculumGraph.getVillagesForEpoch(newEpoch.id);

      // Filter historical trails and overlays based on epoch
      _overlays = HistoricalOverlay.canonicalOverlays
          .where((o) => o.epochId == newEpoch.id)
          .toList();

      _trails = HistoricalTrail.canonicalTrails.map((trail) {
        if (newEpoch == HistoricalEpoch.pre1500) {
          return trail.id == 'peabiru_principal'
              ? trail
              : HistoricalTrail(
                  id: trail.id,
                  name: trail.name,
                  description: trail.description,
                  points: trail.points,
                  color: trail.color.withValues(alpha: 0.35),
                  strokeWidth: 2.0,
                  isDiscovered: false,
                );
        }
        return trail;
      }).toList();

      // Recalculate fog of war for visible horizon
      _fogState = FogEngine.computeFromWorld(
        villages: _villages,
        trails: _trails,
        bktMasteryMap: widget.bktMasteryMap,
      );

      // Deselect village if it no longer exists in epoch
      if (_selectedVillage != null && !_villages.any((v) => v.id == _selectedVillage!.id)) {
        _selectedVillage = null;
        _activeTerritory = null;
      }
    });
  }

  Future<void> _startLesson(LessonNode lesson) async {
    if (_selectedVillage == null) return;

    final villageId = _selectedVillage!.id;
    final previousStatus = lesson.status;
    final previousProgress = lesson.progressPercentage;

    dynamic result;
    bool hadError = false;

    try {
      if (lesson.licaoId != null) {
        result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonPlayerScreen(licaoId: lesson.licaoId!),
          ),
        );
      } else if (lesson.practiceTheme != null) {
        result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ThematicPracticeScreen(
              tema: lesson.practiceTheme!,
              varianteId: _selectedVillage?.variantId ?? 1,
              varianteNome: _selectedVillage?.dialectVariant ?? 'Tupi Antigo',
              initialConchas: 5,
            ),
          ),
        );
      }
    } catch (e) {
      hadError = true;
      debugPrint('[PindoramaMap] Erro ao carregar ou executar lição: $e');
    }

    if (!mounted) return;

    // Se a requisição/execução falhou, efetua rollback explícito do estado visual antes da mensagem
    if (hadError) {
      setState(() {
        _curriculumGraph = _curriculumGraph.updateLessonStatus(
          villageId: villageId,
          lessonId: lesson.id,
          newStatus: previousStatus == LessonStatus.completed
              ? LessonStatus.available
              : previousStatus,
          newProgress: previousProgress,
        );
        _selectedVillage = _curriculumGraph.getVillageById(villageId);
        _villages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
        _fogState = FogEngine.computeFromWorld(
          villages: _villages,
          trails: _trails,
          bktMasteryMap: widget.bktMasteryMap,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar lição. Tente novamente.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final isCompleted = result == true || (result is Map && result['completed'] != false);

    if (isCompleted && _selectedVillage != null) {
      setState(() {
        _curriculumGraph = _curriculumGraph.updateLessonStatus(
          villageId: _selectedVillage!.id,
          lessonId: lesson.id,
          newStatus: LessonStatus.completed,
        );
        _selectedVillage = _curriculumGraph.getVillageById(_selectedVillage!.id);
        _villages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
        _fogState = FogEngine.computeFromWorld(
          villages: _villages,
          trails: _trails,
          bktMasteryMap: widget.bktMasteryMap,
        );
      });
    } else if (mounted && _selectedVillage != null) {
      // Usuário cancelou ou voltou antes de concluir: garante rollback/preservação do status anterior
      setState(() {
        _curriculumGraph = _curriculumGraph.updateLessonStatus(
          villageId: villageId,
          lessonId: lesson.id,
          newStatus: previousStatus,
          newProgress: previousProgress,
        );
        _selectedVillage = _curriculumGraph.getVillageById(villageId);
        _villages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
      });
    }
  }

  void _focusActiveQuest() {
    if (_activeQuest != null) {
      _cameraController.flyTo(_activeQuest!.targetCoordinate, zoom: 1.5);
      final targetVillage = _curriculumGraph.getVillageById(_activeQuest!.targetVillageId);
      if (targetVillage != null) {
        _onVillageSelected(targetVillage);
      }
    }
  }

  void _openNarrativeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: const EdgeInsets.all(22.0),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xEE0B1519),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                border: Border.all(color: const Color(0x55E5A93C), width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_stories, color: Color(0xFFFFD54F), size: 24.0),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            _currentEpoch.title,
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      _currentEpoch.description,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 14.0),
                    const Text(
                      'Territórios Históricos Ativos:',
                      style: TextStyle(color: Color(0xFF80CBC4), fontWeight: FontWeight.bold, fontSize: 13.0),
                    ),
                    const SizedBox(height: 6.0),
                    ..._curriculumGraph.getTerritoriesForEpoch(_currentEpoch.id).map((t) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, color: Color(0xFFFFD54F), size: 18.0),
                            Expanded(
                              child: Text(
                                '${t.name} (${t.primaryDialect})',
                                style: const TextStyle(color: Colors.white70, fontSize: 12.0),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B14),
      body: Stack(
        children: [
          // 1. Continuous Interactive World Viewport
          PindoramaWorldViewport(
            controller: _cameraController,
            villages: _villages,
            rivers: _rivers,
            trails: _trails,
            overlays: _overlays,
            fogState: _fogState,
            particlePool: _particlePool,
            selectedVillage: _selectedVillage,
            onVillageSelected: _onVillageSelected,
            onVillageLongPressed: _onVillageLongPressed,
            onVillageDoubleTapped: _onVillageDoubleTapped,
            onBackgroundTapped: () {
              if (_selectedVillage != null) {
                setState(() {
                  _selectedVillage = null;
                  _activeTerritory = null;
                });
              }
            },
          ),

          // 2. Material 3 Expressive HUD (Top Bar & FABs)
          PindoramaExpressiveHud(
            currentTerritory: _activeTerritory,
            currentEpoch: _currentEpoch,
            activeQuest: _activeQuest,
            onBack: () => Navigator.of(context).pop(),
            onRecenter: () => _cameraController.resetToCenter(),
            onToggleQuests: _focusActiveQuest,
            onOpenNarrative: _openNarrativeModal,
          ),

          // 3. Compact Radar MiniMap (Top Right Floating beneath top bar)
          if (_showMiniMap)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72.0,
              right: 16.0,
              child: ListenableBuilder(
                listenable: _cameraController,
                builder: (context, _) {
                  return MiniMapWidget(
                    camera: _cameraController.state,
                    villages: _villages,
                    onCoordinateTapped: (coord) {
                      _cameraController.flyTo(coord);
                    },
                  );
                },
              ),
            ),

          // 4. Interactive Timeline Slider (Bottom Floating)
          if (_selectedVillage == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: Offset.zero,
                child: HistoricalTimelineSlider(
                  currentEpoch: _currentEpoch,
                  onEpochChanged: _onEpochChanged,
                ),
              ),
            ),

          // 5. Expandable Journey Sheet (When village is selected)
          if (_selectedVillage != null)
            JourneySheetWidget(
              village: _selectedVillage!,
              mastery: widget.bktMasteryMap?[_selectedVillage!.id] ??
                  (_selectedVillage!.completionPercentage),
              onLessonTapped: _startLesson,
              onClose: () {
                setState(() {
                  _selectedVillage = null;
                  _activeTerritory = null;
                });
              },
            ),
        ],
      ),
    );
  }
}
