import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';
import 'package:tupi_lingo/core/world_engine/biomes/biome_palette.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/lesson_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/chest_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/quest_node.dart';

/// 5 Discrete Evolution Stages for Indigenous Villages (RFC-012C Chapter 8 & Patch 1 Chapter 7).
enum VillageEvolutionStage {
  oculta,     // 0. Neblina densa, silhueta em névoa
  descoberta, // 1. Oca principal erguida, fumaça sutil
  explorada,  // 2. Múltiplas ocas e clareira comunitária
  dominada,   // 3. Totens sagrados e paliçada protetora
  historica;  // 4/5. Aldeia viva com fogueira comunal, aura dourada e bandeiras

  int get level => index;
}

/// Visual and spatial entity representing an authentic indigenous village (Taba) in Pindorama.
/// Maps 1:1 with a Curriculum Chapter (RFC-012C Patch 1 Chapter 1).
@immutable
class VillageNode {
  final String id;
  final String name;
  final String tupiName;
  final WorldCoordinate position;
  final int variantId;
  final BiomeType biome;
  final VillageEvolutionStage stage;
  final int residentCount;
  final double discoveryRadius;
  final bool hasBossChallenge;
  final String? curriculumNodeId;
  final String dialectVariant;
  final String leaderName;
  final String historicalContext;

  // Curriculum World Graph extensions (Patch 1 Chapter 1)
  final String territoryId;
  final String chapterId;
  final bool isUnlocked;
  final bool isMastered;
  final List<LessonNode> lessons;
  final List<ChestNode> chests;
  final List<QuestNode> quests;
  final List<String> activeEpochs;

  const VillageNode({
    required this.id,
    required this.name,
    required this.tupiName,
    required this.position,
    required this.variantId,
    required this.biome,
    this.stage = VillageEvolutionStage.oculta,
    this.residentCount = 120,
    this.discoveryRadius = 450.0,
    this.hasBossChallenge = false,
    this.curriculumNodeId,
    this.dialectVariant = 'Tupi Antigo',
    this.leaderName = 'Cacique Ancestral',
    this.historicalContext = 'Aldeamento ancestral com profundo significado histórico.',
    this.territoryId = 'territorio_planalto_paulista',
    this.chapterId = 'capitulo_1',
    this.isUnlocked = true,
    this.isMastered = false,
    this.lessons = const [],
    this.chests = const [],
    this.quests = const [],
    this.activeEpochs = const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'],
  });

  WorldCoordinate get coordinate => position;

  double get completionPercentage {
    if (lessons.isEmpty) return stage == VillageEvolutionStage.historica ? 1.0 : 0.5;
    final completedCount = lessons.where((l) => l.status == LessonStatus.completed || l.status == LessonStatus.mastered).length;
    return completedCount / lessons.length;
  }

  VillageNode copyWith({
    String? id,
    String? name,
    String? tupiName,
    WorldCoordinate? position,
    int? variantId,
    BiomeType? biome,
    VillageEvolutionStage? stage,
    int? residentCount,
    double? discoveryRadius,
    bool? hasBossChallenge,
    String? curriculumNodeId,
    String? dialectVariant,
    String? leaderName,
    String? historicalContext,
    String? territoryId,
    String? chapterId,
    bool? isUnlocked,
    bool? isMastered,
    List<LessonNode>? lessons,
    List<ChestNode>? chests,
    List<QuestNode>? quests,
    List<String>? activeEpochs,
  }) {
    return VillageNode(
      id: id ?? this.id,
      name: name ?? this.name,
      tupiName: tupiName ?? this.tupiName,
      position: position ?? this.position,
      variantId: variantId ?? this.variantId,
      biome: biome ?? this.biome,
      stage: stage ?? this.stage,
      residentCount: residentCount ?? this.residentCount,
      discoveryRadius: discoveryRadius ?? this.discoveryRadius,
      hasBossChallenge: hasBossChallenge ?? this.hasBossChallenge,
      curriculumNodeId: curriculumNodeId ?? this.curriculumNodeId,
      dialectVariant: dialectVariant ?? this.dialectVariant,
      leaderName: leaderName ?? this.leaderName,
      historicalContext: historicalContext ?? this.historicalContext,
      territoryId: territoryId ?? this.territoryId,
      chapterId: chapterId ?? this.chapterId,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isMastered: isMastered ?? this.isMastered,
      lessons: lessons ?? this.lessons,
      chests: chests ?? this.chests,
      quests: quests ?? this.quests,
      activeEpochs: activeEpochs ?? this.activeEpochs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tupi_name': tupiName,
    'wx': position.wx,
    'wy': position.wy,
    'variant_id': variantId,
    'biome': biome.name,
    'stage': stage.name,
    'resident_count': residentCount,
    'discovery_radius': discoveryRadius,
    'has_boss_challenge': hasBossChallenge,
    'curriculum_node_id': curriculumNodeId,
    'dialect_variant': dialectVariant,
    'leader_name': leaderName,
    'historical_context': historicalContext,
    'territory_id': territoryId,
    'chapter_id': chapterId,
    'is_unlocked': isUnlocked,
    'is_mastered': isMastered,
    'active_epochs': activeEpochs,
  };

  factory VillageNode.fromJson(Map<String, dynamic> json) {
    return VillageNode(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tupiName: json['tupi_name'] as String? ?? json['name'] as String? ?? '',
      position: WorldCoordinate(
        (json['wx'] as num?)?.toDouble() ?? 5000.0,
        (json['wy'] as num?)?.toDouble() ?? 5000.0,
      ),
      variantId: (json['variant_id'] as num?)?.toInt() ?? 1,
      biome: BiomeType.values.firstWhere(
        (e) => e.name == (json['biome'] as String?),
        orElse: () => BiomeType.mataAtlantica,
      ),
      stage: VillageEvolutionStage.values.firstWhere(
        (e) => e.name == (json['stage'] as String?),
        orElse: () => VillageEvolutionStage.oculta,
      ),
      residentCount: (json['resident_count'] as num?)?.toInt() ?? 120,
      discoveryRadius: (json['discovery_radius'] as num?)?.toDouble() ?? 450.0,
      hasBossChallenge: json['has_boss_challenge'] as bool? ?? false,
      curriculumNodeId: json['curriculum_node_id'] as String?,
      dialectVariant: json['dialect_variant'] as String? ?? 'Tupi Antigo',
      leaderName: json['leader_name'] as String? ?? 'Cacique Ancestral',
      historicalContext: json['historical_context'] as String? ?? '',
      territoryId: json['territory_id'] as String? ?? 'territorio_planalto_paulista',
      chapterId: json['chapter_id'] as String? ?? 'capitulo_1',
      isUnlocked: json['is_unlocked'] as bool? ?? true,
      isMastered: json['is_mastered'] as bool? ?? false,
      activeEpochs: (json['active_epochs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'],
    );
  }

  /// Canonical indigenous villages across Pindorama mapped to Curriculum chapters
  static List<VillageNode> get canonicalVillages => [
        VillageNode(
          id: 'piratininga',
          name: 'Tietepó / Piratininga',
          tupiName: 'Piratininga',
          position: const WorldCoordinate(5000, 5000),
          variantId: 1,
          biome: BiomeType.mataAtlantica,
          stage: VillageEvolutionStage.dominada,
          residentCount: 350,
          dialectVariant: 'Tupi Paulista',
          leaderName: 'Cacique Tibiriçá',
          hasBossChallenge: true,
          historicalContext: 'Ponto focal de confluência entre o Rio Tamanduateí e Tietê, berço de alianças e resistência.',
          territoryId: 'territorio_planalto_paulista',
          chapterId: 'capitulo_piratininga',
          isUnlocked: true,
          isMastered: false,
          activeEpochs: const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'],
          lessons: const [
            LessonNode(
              id: 'piratininga_01',
              licaoId: 1,
              title: 'Saudações Tradicionais',
              tupiTitle: 'Maíra-monhangaba',
              description: 'Primeiros cumprimentos e acolhimento na taba: Kauê, Karai.',
              difficulty: LessonDifficulty.iniciante,
              type: LessonType.vocabulario,
              status: LessonStatus.completed,
              xpReward: 30,
              durationMinutes: 4,
              progressPercentage: 1.0,
              practiceTheme: 'Saudações',
            ),
            LessonNode(
              id: 'piratininga_02',
              licaoId: 2,
              title: 'Águas e Florestas',
              tupiTitle: 'Y & Ka’a',
              description: 'Vocabulário essencial do bioma: Y, Paranã, Ka’aguy.',
              difficulty: LessonDifficulty.iniciante,
              type: LessonType.vocabulario,
              status: LessonStatus.inProgress,
              xpReward: 40,
              durationMinutes: 5,
              progressPercentage: 0.65,
              practiceTheme: 'Natureza',
              prerequisiteIds: ['piratininga_01'],
            ),
            LessonNode(
              id: 'piratininga_03',
              licaoId: 3,
              title: 'A Taba e a Família',
              tupiTitle: 'Taba & Tetyma',
              description: 'Relações de parentesco e estrutura social Tupi.',
              difficulty: LessonDifficulty.intermediario,
              type: LessonType.gramatica,
              status: LessonStatus.available,
              xpReward: 45,
              durationMinutes: 6,
              progressPercentage: 0.0,
              practiceTheme: 'Família',
              prerequisiteIds: ['piratininga_02'],
            ),
            LessonNode(
              id: 'piratininga_boss',
              licaoId: 4,
              title: 'Desafio do Pajé: Sabedoria de Tibiriçá',
              tupiTitle: 'Pajé Marandu',
              description: 'Boss Challenge integrando acolhimento, natureza e oratória tupi.',
              difficulty: LessonDifficulty.mestre,
              type: LessonType.bossChallenge,
              status: LessonStatus.locked,
              xpReward: 120,
              durationMinutes: 8,
              progressPercentage: 0.0,
              practiceTheme: 'Desafio do Pajé',
              prerequisiteIds: ['piratininga_03'],
            ),
          ],
          chests: const [
            ChestNode(
              id: 'chest_piratininga_maraca',
              title: 'Maracá Ancestral de Tibiriçá',
              artifactName: 'Maracá Ritualístico',
              tupiLore: 'Instrumento sagrado utilizado em cerimônias de acolhimento e conselhos da tribo.',
              isUnlocked: true,
              xpBonus: 80,
            ),
          ],
          quests: const [
            QuestNode(
              id: 'quest_piratininga_main',
              title: 'Pacto do Planalto',
              description: 'Domine os fundamentos das águas e florestas para consolidar a aliança.',
              isMain: true,
              targetVillageId: 'piratininga',
              targetCoordinate: WorldCoordinate(5000, 5000),
              isCompleted: false,
              rewardXp: 200,
            ),
          ],
        ),
        VillageNode(
          id: 'sao_vicente',
          name: 'Enguaguassu / São Vicente',
          tupiName: 'Enguaguassu',
          position: const WorldCoordinate(5350, 5550),
          variantId: 1,
          biome: BiomeType.litoral,
          stage: VillageEvolutionStage.explorada,
          residentCount: 280,
          dialectVariant: 'Tupinambá Litorâneo',
          leaderName: 'Cacique Piquerobi',
          hasBossChallenge: true,
          historicalContext: 'Primeiro porto colonial estabelecido no litoral em território Tupiniquim.',
          territoryId: 'territorio_litoral_paulista',
          chapterId: 'capitulo_sao_vicente',
          isUnlocked: true,
          isMastered: false,
          activeEpochs: const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'],
          lessons: const [
            LessonNode(
              id: 'sv_01',
              licaoId: 5,
              title: 'Canoas e Embarcações',
              tupiTitle: 'Ygara & Paranã',
              description: 'Navegação costeira e travessia das restingas.',
              difficulty: LessonDifficulty.iniciante,
              type: LessonType.vocabulario,
              status: LessonStatus.available,
              xpReward: 35,
              durationMinutes: 4,
              progressPercentage: 0.0,
              practiceTheme: 'Embarcações',
            ),
            LessonNode(
              id: 'sv_02',
              licaoId: 6,
              title: 'Pesca e Alimentos do Mar',
              tupiTitle: 'Pira & Pindá',
              description: 'Subsistência litorânea e técnicas de captura marinha.',
              difficulty: LessonDifficulty.intermediario,
              type: LessonType.vocabulario,
              status: LessonStatus.locked,
              xpReward: 40,
              durationMinutes: 5,
              progressPercentage: 0.0,
              practiceTheme: 'Pesca',
              prerequisiteIds: ['sv_01'],
            ),
          ],
          chests: const [
            ChestNode(
              id: 'chest_sv_anzol',
              title: 'Pindá de Osso Costeiro',
              artifactName: 'Anzol Ancestral',
              tupiLore: 'Talhado em osso de baleia, simbolizando a mestria dos povos pescadores.',
              isUnlocked: false,
              xpBonus: 60,
            ),
          ],
        ),
        VillageNode(
          id: 'ubatuba',
          name: 'Iperoig / Ubatuba',
          tupiName: 'Ypero-yg',
          position: const WorldCoordinate(5700, 5350),
          variantId: 1,
          biome: BiomeType.litoral,
          stage: VillageEvolutionStage.descoberta,
          residentCount: 220,
          dialectVariant: 'Tupinambá',
          leaderName: 'Cacique Cunhambebe',
          hasBossChallenge: true,
          historicalContext: 'Coração da Confederação dos Tamoios e local do célebre Armistício de Iperoig.',
          territoryId: 'territorio_costa_dos_tamoios',
          chapterId: 'capitulo_ubatuba',
          isUnlocked: true,
          isMastered: false,
          activeEpochs: const ['pre1500', 'epoch1555', 'epoch1567', 'atual'],
          lessons: const [
            LessonNode(
              id: 'ub_01',
              licaoId: 7,
              title: 'A Paz de Iperoig',
              tupiTitle: 'Ipero-yg Pyatã',
              description: 'Tratado de paz e vocabulário diplomático Tupi.',
              difficulty: LessonDifficulty.avancado,
              type: LessonType.historia,
              status: LessonStatus.available,
              xpReward: 50,
              durationMinutes: 6,
              progressPercentage: 0.0,
              practiceTheme: 'Diplomacia',
            ),
          ],
        ),
        VillageNode(
          id: 'guanabara',
          name: 'Karióka / Guanabara',
          tupiName: 'Karióka',
          position: const WorldCoordinate(6600, 4850),
          variantId: 1,
          biome: BiomeType.mataAtlantica,
          stage: VillageEvolutionStage.oculta,
          residentCount: 410,
          dialectVariant: 'Tupinambá Guanabarino',
          leaderName: 'Cacique Aimberê',
          hasBossChallenge: true,
          historicalContext: 'Fortaleza natural tupinambá que resistiu durante a aliança franco-indígena.',
          territoryId: 'territorio_baia_da_guanabara',
          chapterId: 'capitulo_guanabara',
          isUnlocked: false,
          isMastered: false,
          activeEpochs: const ['pre1500', 'epoch1555', 'epoch1567', 'atual'],
          lessons: const [],
        ),
        VillageNode(
          id: 'cabo_frio',
          name: 'Mapeg / Cabo Frio',
          tupiName: 'Mapeg',
          position: const WorldCoordinate(7100, 4600),
          variantId: 1,
          biome: BiomeType.litoral,
          stage: VillageEvolutionStage.oculta,
          residentCount: 180,
          dialectVariant: 'Tupinambá',
          leaderName: 'Cacique Guaimixara',
          historicalContext: 'Território estratégico de extração de pau-brasil e entreposto atlântico.',
          territoryId: 'territorio_cabo_frio',
          chapterId: 'capitulo_cabo_frio',
          isUnlocked: false,
          isMastered: false,
          activeEpochs: const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'],
          lessons: const [],
        ),
      ];
}
