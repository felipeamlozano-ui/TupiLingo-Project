import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';
import '../villages/village_node.dart';
import '../trails/historical_trail.dart';

/// 3 Discrete Spatial States of the World Fog of War (Section 4).
enum DiscoveryState {
  /// Território nunca descoberto: coberto por bruma densa com silhuetas sutis de relevo.
  unknown,

  /// Território descoberto anteriormente: permanece conhecido e visível com atmosfera de memória.
  revealed,

  /// Território atualmente dentro do campo de visão ativo do jogador/aldeia: 100% nítido e iluminado.
  currentlyVisible,
}

/// A spatial chunk tracking persistent historical discovery across Pindorama (Section 24).
class DiscoveryChunk {
  final int chunkX;
  final int chunkY;
  final WorldBounds bounds;
  final WorldCoordinate center;
  DiscoveryState state;
  double revealFactor; // 0.0 = fully unknown, 0.65 = revealed, 1.0 = currently visible
  double targetRevealFactor;

  DiscoveryChunk({
    required this.chunkX,
    required this.chunkY,
    required this.bounds,
    required this.center,
    this.state = DiscoveryState.unknown,
    this.revealFactor = 0.0,
    this.targetRevealFactor = 0.0,
  });
}

/// High-performance Spatial Discovery & Fog of War Engine (RFC-012C Chapter 8).
///
/// Implements:
/// - 3-state visibility: UNKNOWN -> REVEALED -> CURRENTLY_VISIBLE (Section 4).
/// - Persistent chunk-based discovery across chapters and historical epochs (Section 11 & 24).
/// - Decoupled UNLOCKED vs DISCOVERED state management (Section 20 & 21).
/// - Organic, non-circular clearance hulls with procedural noise (Section 5 & 7).
/// - Smooth animated discovery transitions (Section 29).
class WorldDiscoveryEngine {
  WorldDiscoveryEngine._() {
    _initGrid();
    loadPersistedState();
  }

  static final WorldDiscoveryEngine instance = WorldDiscoveryEngine._();

  static const double chunkSize = 500.0;
  static const int gridDimension = 20; // 20x20 = 400 chunks covering 10000x10000
  static const String _prefKeyDiscovered = 'pindorama_discovered_villages_v1';

  final Map<int, DiscoveryChunk> _chunks = {};
  final Set<String> _revealedVillageIds = {'piratininga'};
  String? _activeVillageId;

  Map<int, DiscoveryChunk> get chunks => _chunks;
  Set<String> get revealedVillageIds => _revealedVillageIds;
  String? get activeVillageId => _activeVillageId;

  int _chunkKey(int cx, int cy) => (cx & 0xFFFF) | ((cy & 0xFFFF) << 16);

  /// Loads persisted discovered settlements from storage
  Future<void> loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKeyDiscovered);
      if (list != null && list.isNotEmpty) {
        _revealedVillageIds.addAll(list);
      }
    } catch (_) {
      // Offline fallback
    }
  }

  /// Explicitly marks a settlement as discovered by player exploration and persists state
  Future<void> markVillageDiscovered(String villageId, {WorldCoordinate? coordinate}) async {
    _revealedVillageIds.add(villageId);
    if (coordinate != null) {
      _revealArea(
        center: coordinate,
        radius: 750.0,
        state: DiscoveryState.currentlyVisible,
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKeyDiscovered, _revealedVillageIds.toList());
    } catch (_) {
      // Offline storage fallback
    }
  }

  /// Checks if a settlement has been explored/revealed
  bool isVillageDiscovered(String villageId) {
    if (villageId == 'piratininga') return true;
    return _revealedVillageIds.contains(villageId);
  }

  /// Resets the discovery grid to initial unknown state (useful for fresh sessions or testing).
  void reset() {
    _revealedVillageIds.clear();
    _revealedVillageIds.add('piratininga');
    _activeVillageId = null;
    _initGrid();
  }

  void _initGrid() {
    _chunks.clear();
    for (int cx = 0; cx < gridDimension; cx++) {
      for (int cy = 0; cy < gridDimension; cy++) {
        final minX = cx * chunkSize;
        final minY = cy * chunkSize;
        final bounds = WorldBounds(
          minX: minX,
          minY: minY,
          maxX: minX + chunkSize,
          maxY: minY + chunkSize,
        );
        final center = WorldCoordinate(minX + chunkSize / 2, minY + chunkSize / 2);
        _chunks[_chunkKey(cx, cy)] = DiscoveryChunk(
          chunkX: cx,
          chunkY: cy,
          bounds: bounds,
          center: center,
          state: DiscoveryState.unknown,
          revealFactor: 0.0,
          targetRevealFactor: 0.0,
        );
      }
    }
  }

  /// Updates discovery grid based on active villages, player progression, and trails.
  void synchronizeProgression({
    required List<VillageNode> villages,
    required List<HistoricalTrail> trails,
    Map<String, double>? bktMasteryMap,
  }) {
    if (villages.isEmpty) return;

    // Reset currentlyVisible to revealed for previous active areas
    for (final chunk in _chunks.values) {
      if (chunk.state == DiscoveryState.currentlyVisible) {
        chunk.state = DiscoveryState.revealed;
        chunk.targetRevealFactor = 0.70;
      }
    }

    VillageNode? activeVillage;

    // 1. Mark completed and active villages (respecting UNLOCKED vs DISCOVERED separation)
    for (final v in villages) {
      final isUnlocked = v.isUnlocked || v.status == VillageStatus.current || v.stage != VillageEvolutionStage.oculta;
      if (!isUnlocked) {
        if (v.isFrontier) {
          // Subtle hint at the edge of unexplored mist
          _revealArea(
            center: v.coordinate,
            radius: 220.0,
            state: DiscoveryState.revealed,
          );
        }
        continue;
      }

      final isDiscovered = v.isDiscovered ||
          isVillageDiscovered(v.id) ||
          v.stage != VillageEvolutionStage.oculta ||
          v.status == VillageStatus.current;
      if (!isDiscovered) {
        // Village is UNLOCKED (exists in the world) but NOT YET DISCOVERED (hidden by Fog of War)
        continue;
      }

      _revealedVillageIds.add(v.id);

      final isCurrentlyActive = (v.status == VillageStatus.current ||
              v.stage == VillageEvolutionStage.explorada ||
              v.stage == VillageEvolutionStage.descoberta) &&
          v.stage != VillageEvolutionStage.historica &&
          v.stage != VillageEvolutionStage.dominada &&
          v.status != VillageStatus.completed;

      if (isCurrentlyActive && activeVillage == null) {
        activeVillage = v;
        _activeVillageId = v.id;
      }

      final mastery = bktMasteryMap?[v.id] ??
          (v.stage == VillageEvolutionStage.historica
              ? 1.0
              : v.stage == VillageEvolutionStage.dominada
                  ? 0.85
                  : 0.60);

      // Discovery radius expands with mastery (Section 10)
      final radius = isCurrentlyActive ? 750.0 + (mastery * 250.0) : 550.0 + (mastery * 200.0);

      _revealArea(
        center: v.coordinate,
        radius: radius,
        state: isCurrentlyActive ? DiscoveryState.currentlyVisible : DiscoveryState.revealed,
      );
    }

    // 2. Reveal explored historical trails (corredores de exploração)
    for (final trail in trails) {
      if (!trail.isDiscovered || trail.points.isEmpty) continue;

      for (int i = 0; i < trail.points.length; i += 3) {
        _revealArea(
          center: trail.points[i],
          radius: 350.0,
          state: DiscoveryState.revealed,
        );
      }
    }
  }

  void _revealArea({
    required WorldCoordinate center,
    required double radius,
    required DiscoveryState state,
  }) {
    final minCx = math.max(0, ((center.wx - radius) / chunkSize).floor());
    final maxCx = math.min(gridDimension - 1, ((center.wx + radius) / chunkSize).floor());
    final minCy = math.max(0, ((center.wy - radius) / chunkSize).floor());
    final maxCy = math.min(gridDimension - 1, ((center.wy + radius) / chunkSize).floor());

    final targetVal = state == DiscoveryState.currentlyVisible ? 1.0 : 0.70;

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final chunk = _chunks[_chunkKey(cx, cy)];
        if (chunk == null) continue;

        final dist = chunk.center.distanceTo(center);
        if (dist <= radius) {
          // Promote state if higher
          if (state == DiscoveryState.currentlyVisible) {
            chunk.state = DiscoveryState.currentlyVisible;
            chunk.targetRevealFactor = targetVal;
          } else if (chunk.state != DiscoveryState.currentlyVisible) {
            chunk.state = DiscoveryState.revealed;
            chunk.targetRevealFactor = math.max(chunk.targetRevealFactor, targetVal);
          }
        } else if (dist <= radius + chunkSize * 0.6) {
          // Soft feathered boundary chunk
          final feather = 1.0 - ((dist - radius) / (chunkSize * 0.6));
          final factor = (targetVal * feather).clamp(0.0, targetVal);
          if (chunk.state == DiscoveryState.unknown) {
            chunk.state = DiscoveryState.revealed;
          }
          chunk.targetRevealFactor = math.max(chunk.targetRevealFactor, factor * 0.85);
        }
      }
    }
  }

  /// Ticks smooth animated reveal progress (Section 29: soft reveal animation).
  void tick(double dt) {
    const speed = 2.8; // Smooth 350ms transition
    for (final chunk in _chunks.values) {
      if ((chunk.revealFactor - chunk.targetRevealFactor).abs() > 0.005) {
        chunk.revealFactor += (chunk.targetRevealFactor - chunk.revealFactor) * (speed * dt).clamp(0.0, 1.0);
      } else {
        chunk.revealFactor = chunk.targetRevealFactor;
      }
    }
  }

  /// Returns discovery state at a specific world coordinate.
  DiscoveryState getStateAt(WorldCoordinate point) {
    final cx = (point.wx / chunkSize).floor();
    final cy = (point.wy / chunkSize).floor();
    return _chunks[_chunkKey(cx, cy)]?.state ?? DiscoveryState.unknown;
  }

  /// Returns visibility factor (0.0 to 1.0) at a specific coordinate.
  double getVisibilityAt(WorldCoordinate point) {
    final cx = (point.wx / chunkSize).floor().clamp(0, gridDimension - 1);
    final cy = (point.wy / chunkSize).floor().clamp(0, gridDimension - 1);
    return _chunks[_chunkKey(cx, cy)]?.revealFactor ?? 0.0;
  }
}
