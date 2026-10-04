import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/world_engine/camera/camera_state.dart';
import '../../../../core/world_engine/camera/world_camera_controller.dart';
import '../../../../core/world_engine/coordinates/world_bounds.dart';
import '../../../../core/world_engine/fog/fog_engine.dart';
import '../../../../core/world_engine/fog/fog_state.dart';
import '../../../../core/world_engine/fog/world_discovery_engine.dart';
import '../../../../core/world_engine/particles/world_particle_pool.dart';
import '../../../../core/world_engine/rendering/pindorama_world_viewport.dart';
import '../../../../core/world_engine/theme/pindorama_theme_palette.dart';
import '../../../../core/world_engine/landmarks/historical_landmark.dart';
import '../../../../core/world_engine/trails/historical_trail.dart';
import '../../../../core/world_engine/trails/historical_overlay.dart';
import '../../../../core/world_engine/trails/river_path.dart';
import '../../../../core/world_engine/villages/village_node.dart';
import '../../../../core/world_engine/world_sync_service.dart';
import '../../../home/data/models/trail_map_models.dart';
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
/// - MiniMap radar and Material 3 Expressive HUD with cosmetic store theme integration.
class PindoramaMapScreen extends StatefulWidget {
  final Map<String, double>? bktMasteryMap;
  final List<CapituloMapData>? capitulos;

  const PindoramaMapScreen({
    super.key,
    this.bktMasteryMap,
    this.capitulos,
  });

  @override
  State<PindoramaMapScreen> createState() => _PindoramaMapScreenState();
}

class _PindoramaMapScreenState extends State<PindoramaMapScreen>
    with TickerProviderStateMixin {
  late final WorldCameraController _cameraController;
  late final WorldParticlePool _particlePool;
  late CurriculumWorldGraph _curriculumGraph;

  late List<VillageNode> _villages;
  late List<RiverPath> _rivers;
  late List<HistoricalTrail> _trails;
  late List<HistoricalOverlay> _overlays;
  late FogState _fogState;

  VillageNode? _selectedVillage;
  HistoricalLandmark? _selectedLandmark;
  TerritoryNode? _activeTerritory;
  QuestNode? _activeQuest;
  HistoricalEpoch _currentEpoch = HistoricalEpoch.pre1500;
  HistoricalEpoch _previousEpoch = HistoricalEpoch.pre1500;
  late final AnimationController _epochTransitionController;
  bool _isMiniMapVisible = false;

  @override
  void initState() {
    super.initState();
    _epochTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _cameraController = WorldCameraController(
      initialState: const CameraState(
        x: 5000.0,
        y: 5000.0,
        zoom: 1.15,
      ),
    );
    _particlePool = WorldParticlePool();
    _curriculumGraph = CurriculumWorldGraph();

    WorldSyncService.instance.activeWorldNotifier.addListener(_onWorldSnapshotChanged);
    ThemeNotifier.instance.addListener(_onThemeChanged);
    _initWorldData(initialCentering: true);

    // Asynchronously load persisted village discovery state (Section 20 & 23)
    WorldDiscoveryEngine.instance.loadPersistedState().then((_) {
      if (mounted) {
        setState(() {
          _villages = _applyProgression(_villages);
          final palette = PindoramaThemePalette.current();
          _fogState = FogEngine.computeFromWorld(
            villages: _villages,
            trails: _trails,
            bktMasteryMap: widget.bktMasteryMap,
            fogColor: palette.fogColor,
          );
        });
      }
    });
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      final palette = PindoramaThemePalette.current();
      _fogState = FogEngine.computeFromWorld(
        villages: _villages,
        trails: _trails,
        bktMasteryMap: widget.bktMasteryMap,
        fogColor: palette.fogColor,
      );
    });
  }

  void _onWorldSnapshotChanged() {
    if (!mounted) return;
    setState(() {
      _initWorldData();
    });
  }

  /// Transforms raw village list into authentic sequential chapter progression
  List<VillageNode> _applyProgression(List<VillageNode> rawVillages) {
    if (rawVillages.isEmpty) return rawVillages;

    final caps = widget.capitulos;
    int activeChapterIndex = 0;

    if (caps != null && caps.isNotEmpty) {
      for (int i = 0; i < caps.length; i++) {
        final cap = caps[i];
        final isCompleted = cap.moduleProgressPercentage >= 1.0 ||
            (cap.licoes.isNotEmpty && cap.licoes.every((l) => l.status == LicaoStatus.concluida));
        if (!isCompleted) {
          activeChapterIndex = i;
          break;
        }
        if (i == caps.length - 1) {
          activeChapterIndex = caps.length - 1;
        }
      }
    } else {
      // Derive from village lesson completion or default to first village
      for (int i = 0; i < rawVillages.length; i++) {
        final v = rawVillages[i];
        if (v.completionPercentage < 1.0) {
          activeChapterIndex = i;
          break;
        }
        if (i == rawVillages.length - 1) {
          activeChapterIndex = rawVillages.length - 1;
        }
      }
    }

    const canonicalOrder = ['piratininga', 'sao_vicente', 'ubatuba', 'guanabara', 'cabo_frio'];

    final updated = <VillageNode>[];
    for (int i = 0; i < rawVillages.length; i++) {
      final v = rawVillages[i];
      int globalIndex = i;
      final vid = v.id.toLowerCase();
      final chMatch = RegExp(r'(?:vila|reg|chapter|capitulo)_0*(\d+)').firstMatch(vid);
      if (chMatch != null) {
        final parsed = int.tryParse(chMatch.group(1)!);
        if (parsed != null && parsed >= 1) {
          globalIndex = parsed - 1;
        }
      } else if (canonicalOrder.contains(vid)) {
        globalIndex = canonicalOrder.indexOf(vid);
      }
      final cap = (caps != null && globalIndex < caps.length) ? caps[globalIndex] : null;

      // Map actual chapter lessons if available
      List<LessonNode> lessons = v.lessons;
      if (cap != null && cap.licoes.isNotEmpty) {
        lessons = cap.licoes.map((l) {
          final s = switch (l.status) {
            LicaoStatus.concluida => LessonStatus.completed,
            LicaoStatus.disponivel => LessonStatus.available,
            LicaoStatus.emAndamento => LessonStatus.inProgress,
            LicaoStatus.bloqueada => LessonStatus.locked,
          };
          return LessonNode(
            id: 'licao_${l.id}',
            licaoId: l.id,
            title: l.titulo,
            tupiTitle: l.titulo,
            description: l.descricao.isNotEmpty ? l.descricao : 'Lição ancestral do capítulo.',
            status: s,
            xpReward: l.xpBase,
            progressPercentage: s == LessonStatus.completed ? 1.0 : (s == LessonStatus.inProgress ? 0.5 : 0.0),
          );
        }).toList();
      }

      if (globalIndex < activeChapterIndex) {
        // Completed chapter village: fully revealed, historically mastered
        updated.add(v.copyWith(
          stage: VillageEvolutionStage.historica,
          status: VillageStatus.completed,
          isUnlocked: true,
          isDiscovered: true,
          isMastered: true,
          isFrontier: false,
          lessons: lessons,
        ));
      } else if (globalIndex == activeChapterIndex) {
        // Current active chapter village: active outpost in progress
        // The active chapter village is ALWAYS unlocked & discovered
        WorldDiscoveryEngine.instance.markVillageDiscovered(v.id, coordinate: v.coordinate);
        updated.add(v.copyWith(
          stage: VillageEvolutionStage.explorada,
          status: VillageStatus.current,
          isUnlocked: true,
          isDiscovered: true,
          isMastered: false,
          isFrontier: false,
          lessons: lessons,
        ));
      } else if (globalIndex == activeChapterIndex + 1) {
        // Next chapter frontier target: visible on mist border with padlock
        final isDisc = WorldDiscoveryEngine.instance.isVillageDiscovered(v.id);
        updated.add(v.copyWith(
          stage: VillageEvolutionStage.oculta,
          status: VillageStatus.locked,
          isUnlocked: false,
          isDiscovered: isDisc,
          isMastered: false,
          isFrontier: true,
          lessons: lessons,
        ));
      } else {
        // Deep unexplored fog: completely shrouded
        updated.add(v.copyWith(
          stage: VillageEvolutionStage.oculta,
          status: VillageStatus.locked,
          isUnlocked: false,
          isDiscovered: false,
          isMastered: false,
          isFrontier: false,
          lessons: lessons,
        ));
      }
    }

    return updated;
  }

  void _updateCameraBoundsAndCenter({bool jumpToActive = false}) {
    final activeOrFrontier = _villages
        .where((v) => v.stage != VillageEvolutionStage.oculta || v.isFrontier)
        .toList();

    if (activeOrFrontier.isNotEmpty) {
      double minX = activeOrFrontier.first.coordinate.x;
      double maxX = activeOrFrontier.first.coordinate.x;
      double minY = activeOrFrontier.first.coordinate.y;
      double maxY = activeOrFrontier.first.coordinate.y;

      for (final v in activeOrFrontier) {
        if (v.coordinate.x < minX) minX = v.coordinate.x;
        if (v.coordinate.x > maxX) maxX = v.coordinate.x;
        if (v.coordinate.y < minY) minY = v.coordinate.y;
        if (v.coordinate.y > maxY) maxY = v.coordinate.y;
      }

      // Generous margin ensures the player can pan and zoom out to Strategic View (0.45x - 0.70x)
      // to survey the continental relief, mountain mist, and surrounding geography (Section 20 & 21).
      const margin = 1800.0;
      final allowedBounds = WorldBounds(
        minX: (minX - margin).clamp(0.0, CameraState.worldSize),
        maxX: (maxX + margin).clamp(0.0, CameraState.worldSize),
        minY: (minY - margin).clamp(0.0, CameraState.worldSize),
        maxY: (maxY + margin).clamp(0.0, CameraState.worldSize),
      );
      _cameraController.setAllowedBounds(allowedBounds, snapImmediately: jumpToActive);

      if (jumpToActive) {
        final activeVillage = _villages.firstWhere(
          (v) => v.stage == VillageEvolutionStage.explorada || v.stage == VillageEvolutionStage.descoberta,
          orElse: () => _villages.first,
        );
        _cameraController.jumpTo(activeVillage.coordinate, zoom: 1.15);
      }
    }
  }

  void _initWorldData({bool initialCentering = false}) {
    final activeBundle = WorldSyncService.instance.activeSnapshot;
    List<VillageNode> baseVillages;
    if (activeBundle != null && (activeBundle['villages'] != null || activeBundle['rivers'] != null)) {
      final customVillages = WorldSyncService.instance.parseVillages(activeBundle);
      final customRivers = WorldSyncService.instance.parseRivers(activeBundle);
      final customTrails = WorldSyncService.instance.parseTrails(activeBundle);
      final customTerritories = WorldSyncService.instance.parseTerritories(activeBundle);
      final customOverlays = WorldSyncService.instance.parseOverlays(activeBundle);

      _curriculumGraph = CurriculumWorldGraph(
        villages: customVillages,
        territories: customTerritories,
      );
      final epochVillages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
      baseVillages = epochVillages.isNotEmpty ? epochVillages : customVillages;
      _rivers = customRivers;
      _trails = customTrails.where((t) => t.activeEpochs.contains(_currentEpoch.id)).toList();

      final filteredOverlays = customOverlays.where((o) => o.epochId == _currentEpoch.id).toList();
      _overlays = filteredOverlays.isNotEmpty ? filteredOverlays : customOverlays;
    } else {
      baseVillages = _curriculumGraph.getVillagesForEpoch(_currentEpoch.id);
      _rivers = RiverPath.canonicalRivers();
      _trails = HistoricalTrail.canonicalTrails
          .where((t) => t.activeEpochs.contains(_currentEpoch.id))
          .toList();
      _overlays = HistoricalOverlay.canonicalOverlays
          .where((o) => o.epochId == _currentEpoch.id)
          .toList();
    }

    _villages = _applyProgression(baseVillages);
    _curriculumGraph = CurriculumWorldGraph(
      villages: _villages,
      territories: _curriculumGraph.allTerritories,
    );

    _activeQuest = _curriculumGraph.getActiveMainQuest();

    final palette = PindoramaThemePalette.current();
    _fogState = FogEngine.computeFromWorld(
      villages: _villages,
      trails: _trails,
      bktMasteryMap: widget.bktMasteryMap,
      fogColor: palette.fogColor,
    );

    _particlePool.initializeDefaults(villages: _villages);
    _updateCameraBoundsAndCenter(jumpToActive: initialCentering);
  }

  @override
  void dispose() {
    WorldSyncService.instance.activeWorldNotifier.removeListener(_onWorldSnapshotChanged);
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _epochTransitionController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _onVillageSelected(VillageNode village) {
    if (!village.isUnlocked) {
      HapticFeedback.heavyImpact();
      final palette = PindoramaThemePalette.current();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Aldeia ${village.tupiName} bloqueada! Complete o capítulo anterior para desbravar.'),
              ),
            ],
          ),
          backgroundColor: palette.hudSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
            side: BorderSide(color: palette.hudBorder),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Explicitly discover settlement if unlocked but shrouded, and persist state (Section 20-23)
    if (!village.isDiscovered) {
      WorldDiscoveryEngine.instance.markVillageDiscovered(village.id, coordinate: village.coordinate);
      _villages = _applyProgression(_villages);
      final palette = PindoramaThemePalette.current();
      _fogState = FogEngine.computeFromWorld(
        villages: _villages,
        trails: _trails,
        bktMasteryMap: widget.bktMasteryMap,
        fogColor: palette.fogColor,
      );
    }

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

  void _onLandmarkSelected(HistoricalLandmark landmark) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLandmark = landmark;
      _selectedVillage = null;
      _activeTerritory = null;
    });

    _cameraController.flyTo(
      landmark.coordinate,
      zoom: (_cameraController.zoom < 1.25 ? 1.45 : _cameraController.zoom),
    );

    _openLandmarkModal(landmark);
  }

  void _openLandmarkModal(HistoricalLandmark landmark) {
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
                maxHeight: MediaQuery.of(ctx).size.height * 0.72,
              ),
              decoration: BoxDecoration(
                color: const Color(0xEE0B1519),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                border: Border.all(color: const Color(0x66FFD54F), width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.explore, color: Color(0xFFFFD54F), size: 26.0),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                landmark.title,
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17.0,
                                ),
                              ),
                              Text(
                                landmark.subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF80CBC4),
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14.0),
                    Text(
                      landmark.historicalLore,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                    ),
                    const SizedBox(height: 20.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_stories, size: 18),
                        label: const Text('Compreender Memória Ancestral', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5A93C),
                          foregroundColor: const Color(0xFF10191F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
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

  void _onEpochChanged(HistoricalEpoch newEpoch) {
    if (newEpoch == _currentEpoch) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _previousEpoch = _currentEpoch;
      _currentEpoch = newEpoch;
      _epochTransitionController.forward(from: 0.0);
      final epochVillages = _curriculumGraph.getVillagesForEpoch(newEpoch.id);
      final rawEpoch = epochVillages.isNotEmpty ? epochVillages : _curriculumGraph.allVillages;
      _villages = _applyProgression(rawEpoch);

      // Filter historical overlays based on epoch
      final activeBundle = WorldSyncService.instance.activeSnapshot;
      final allOverlays = WorldSyncService.instance.parseOverlays(activeBundle);
      final filteredOverlays = allOverlays.where((o) => o.epochId == newEpoch.id).toList();
      _overlays = filteredOverlays.isNotEmpty ? filteredOverlays : allOverlays;

      // Filter historical trails based on epoch
      final allTrails = WorldSyncService.instance.parseTrails(activeBundle);
      _trails = allTrails.where((t) => t.activeEpochs.contains(newEpoch.id)).toList();

      final palette = PindoramaThemePalette.current();
      _fogState = FogEngine.computeFromWorld(
        villages: _villages,
        trails: _trails,
        bktMasteryMap: widget.bktMasteryMap,
        fogColor: palette.fogColor,
      );

      _updateCameraBoundsAndCenter();

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
    final palette = PindoramaThemePalette.current();

    return Scaffold(
      backgroundColor: palette.terrainBackground,
      body: Stack(
        children: [
          // 1. Continuous Interactive World Viewport
          PindoramaWorldViewport(
            controller: _cameraController,
            villages: _villages,
            rivers: _rivers,
            trails: _trails,
            overlays: _overlays,
            landmarks: HistoricalLandmark.canonicalLandmarks,
            fogState: _fogState,
            particlePool: _particlePool,
            palette: palette,
            selectedVillage: _selectedVillage,
            selectedLandmark: _selectedLandmark,
            currentEpoch: _currentEpoch,
            previousEpoch: _previousEpoch,
            epochTransitionProgress: _epochTransitionController.value,
            onVillageSelected: _onVillageSelected,
            onVillageLongPressed: _onVillageLongPressed,
            onVillageDoubleTapped: _onVillageDoubleTapped,
            onLandmarkSelected: _onLandmarkSelected,
            onBackgroundTapped: () {
              if (_selectedVillage != null || _selectedLandmark != null) {
                setState(() {
                  _selectedVillage = null;
                  _selectedLandmark = null;
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
            palette: palette,
            isMiniMapVisible: _isMiniMapVisible,
            onToggleMiniMap: () {
              setState(() {
                _isMiniMapVisible = !_isMiniMapVisible;
              });
            },
            onBack: () => Navigator.of(context).pop(),
            onRecenter: () {
              final activeVillage = _villages.firstWhere(
                (v) => v.stage == VillageEvolutionStage.explorada || v.stage == VillageEvolutionStage.descoberta,
                orElse: () => _villages.first,
              );
              _cameraController.flyTo(activeVillage.coordinate, zoom: 1.25);
            },
            onToggleQuests: _focusActiveQuest,
            onOpenNarrative: _openNarrativeModal,
          ),

          // 3. Compact Radar MiniMap (Collapsible via Compass HUD button)
          if (_isMiniMapVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72.0,
              right: 16.0,
              child: ListenableBuilder(
                listenable: _cameraController,
                builder: (context, _) {
                  return MiniMapWidget(
                    camera: _cameraController.state,
                    villages: _villages,
                    palette: palette,
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
