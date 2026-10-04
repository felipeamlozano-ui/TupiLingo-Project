import 'package:flutter/foundation.dart';
import '../../../../core/world_engine/coordinates/world_coordinate.dart';
import '../../../../core/world_engine/coordinates/world_bounds.dart';
import '../../../../core/world_engine/biomes/biome_palette.dart';

/// Territory node representing a Macro-Capítulo in Pindorama (RFC-012C Patch 1 Chapter 1).
///
/// Encapsulates historical period, primary dialect variant, biome, progression
/// percentage, total XP, and constituent village IDs.
@immutable
class TerritoryNode {
  final String id;
  final String name;
  final String tupiName;
  final String historicalPeriod;
  final String primaryDialect;
  final BiomeType biome;
  final double completionPercentage;
  final int totalXp;
  final int learnedConceptsCount;
  final int totalLessonsCount;
  final WorldCoordinate center;
  final WorldBounds bounds;
  final List<String> villageIds;
  final bool isUnlocked;

  const TerritoryNode({
    required this.id,
    required this.name,
    required this.tupiName,
    required this.historicalPeriod,
    required this.primaryDialect,
    required this.biome,
    this.completionPercentage = 0.0,
    this.totalXp = 0,
    this.learnedConceptsCount = 0,
    this.totalLessonsCount = 8,
    required this.center,
    required this.bounds,
    required this.villageIds,
    this.isUnlocked = true,
  });

  TerritoryNode copyWith({
    String? id,
    String? name,
    String? tupiName,
    String? historicalPeriod,
    String? primaryDialect,
    BiomeType? biome,
    double? completionPercentage,
    int? totalXp,
    int? learnedConceptsCount,
    int? totalLessonsCount,
    WorldCoordinate? center,
    WorldBounds? bounds,
    List<String>? villageIds,
    bool? isUnlocked,
  }) {
    return TerritoryNode(
      id: id ?? this.id,
      name: name ?? this.name,
      tupiName: tupiName ?? this.tupiName,
      historicalPeriod: historicalPeriod ?? this.historicalPeriod,
      primaryDialect: primaryDialect ?? this.primaryDialect,
      biome: biome ?? this.biome,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      totalXp: totalXp ?? this.totalXp,
      learnedConceptsCount: learnedConceptsCount ?? this.learnedConceptsCount,
      totalLessonsCount: totalLessonsCount ?? this.totalLessonsCount,
      center: center ?? this.center,
      bounds: bounds ?? this.bounds,
      villageIds: villageIds ?? this.villageIds,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tupi_name': tupiName,
        'historical_period': historicalPeriod,
        'primary_dialect': primaryDialect,
        'biome': biome.name,
        'completion_percentage': completionPercentage,
        'total_xp': totalXp,
        'learned_concepts_count': learnedConceptsCount,
        'total_lessons_count': totalLessonsCount,
        'cx': center.x,
        'cy': center.y,
        'village_ids': villageIds,
        'is_unlocked': isUnlocked,
      };

  /// Canonical territories defining Pindorama's curriculum world regions.
  static List<TerritoryNode> get canonicalTerritories => [
        const TerritoryNode(
          id: 'territorio_planalto_paulista',
          name: 'Planalto de Piratininga & Vale do Tietê',
          tupiName: 'Piratininga Yby',
          historicalPeriod: '1554 — Primeiros Aldeamentos',
          primaryDialect: 'Tupi Paulista',
          biome: BiomeType.mataAtlantica,
          completionPercentage: 0.65,
          totalXp: 350,
          learnedConceptsCount: 24,
          totalLessonsCount: 8,
          center: WorldCoordinate(5000, 5000),
          bounds: WorldBounds(minX: 4500, minY: 4600, maxX: 5500, maxY: 5400),
          villageIds: ['piratininga'],
          isUnlocked: true,
        ),
        const TerritoryNode(
          id: 'territorio_litoral_paulista',
          name: 'Litoral Santista & Encosta da Serra',
          tupiName: 'Enguaguassu Paranã',
          historicalPeriod: '1532 — Primeiros Portos',
          primaryDialect: 'Tupinambá Litorâneo',
          biome: BiomeType.litoral,
          completionPercentage: 0.45,
          totalXp: 220,
          learnedConceptsCount: 16,
          totalLessonsCount: 6,
          center: WorldCoordinate(5350, 5550),
          bounds: WorldBounds(minX: 4900, minY: 5200, maxX: 5700, maxY: 6000),
          villageIds: ['sao_vicente'],
          isUnlocked: true,
        ),
        const TerritoryNode(
          id: 'territorio_costa_dos_tamoios',
          name: 'Costa Verde & Baía da Ilha Grande',
          tupiName: 'Iperoig Ybytyra',
          historicalPeriod: '1563 — Confederação dos Tamoios',
          primaryDialect: 'Tupinambá',
          biome: BiomeType.litoral,
          completionPercentage: 0.20,
          totalXp: 120,
          learnedConceptsCount: 8,
          totalLessonsCount: 7,
          center: WorldCoordinate(5700, 5350),
          bounds: WorldBounds(minX: 5300, minY: 5000, maxX: 6200, maxY: 5700),
          villageIds: ['ubatuba'],
          isUnlocked: true,
        ),
        const TerritoryNode(
          id: 'territorio_baia_da_guanabara',
          name: 'Baía de Guanabara & França Antártica',
          tupiName: 'Karióka Paranã',
          historicalPeriod: '1555 — Aliança Franco-Indígena',
          primaryDialect: 'Tupinambá Guanabarino',
          biome: BiomeType.mataAtlantica,
          completionPercentage: 0.0,
          totalXp: 0,
          learnedConceptsCount: 0,
          totalLessonsCount: 9,
          center: WorldCoordinate(6600, 4850),
          bounds: WorldBounds(minX: 6200, minY: 4400, maxX: 7000, maxY: 5200),
          villageIds: ['guanabara'],
          isUnlocked: false,
        ),
        const TerritoryNode(
          id: 'territorio_cabo_frio',
          name: 'Região dos Lagos & Rota do Pau-Brasil',
          tupiName: 'Mapeg Paranã',
          historicalPeriod: '1504 — Feitorias de Pau-Brasil',
          primaryDialect: 'Tupinambá',
          biome: BiomeType.litoral,
          completionPercentage: 0.0,
          totalXp: 0,
          learnedConceptsCount: 0,
          totalLessonsCount: 5,
          center: WorldCoordinate(7100, 4600),
          bounds: WorldBounds(minX: 6800, minY: 4200, maxX: 7500, maxY: 5000),
          villageIds: ['cabo_frio'],
          isUnlocked: false,
        ),
      ];
}
