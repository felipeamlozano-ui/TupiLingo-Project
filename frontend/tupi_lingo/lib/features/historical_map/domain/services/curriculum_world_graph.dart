import '../../../../core/world_engine/villages/village_node.dart';
import '../entities/territory_node.dart';
import '../entities/lesson_node.dart';
import '../entities/quest_node.dart';

/// Service managing the Curriculum World Graph (RFC-012C Patch 1 Chapter 1 & 15).
///
/// Implements the canonical mapping:
/// Território = Macro Capítulo
/// Aldeia = Capítulo
/// Oca = Lição
/// Trilha = Dependência Curricular
/// Rio = Linha Histórica
class CurriculumWorldGraph {
  final Map<String, TerritoryNode> _territories = {};
  final Map<String, VillageNode> _villages = {};

  CurriculumWorldGraph({
    List<TerritoryNode>? territories,
    List<VillageNode>? villages,
  }) {
    final tList = territories ?? TerritoryNode.canonicalTerritories;
    for (final t in tList) {
      _territories[t.id] = t;
    }

    final vList = villages ?? VillageNode.canonicalVillages;
    for (final v in vList) {
      _villages[v.id] = v;
    }
  }

  List<TerritoryNode> get allTerritories => _territories.values.toList();
  List<VillageNode> get allVillages => _villages.values.toList();

  TerritoryNode? getTerritoryById(String id) => _territories[id];
  VillageNode? getVillageById(String id) => _villages[id];

  /// Returns territory that contains the given village ID
  TerritoryNode? getTerritoryForVillage(String villageId) {
    for (final t in _territories.values) {
      if (t.villageIds.contains(villageId)) return t;
    }
    return null;
  }

  /// Filters villages according to active historical epoch (Chapter 3)
  List<VillageNode> getVillagesForEpoch(String epochId) {
    return _villages.values.where((v) {
      return v.activeEpochs.contains(epochId);
    }).toList();
  }

  /// Filters territories according to active historical epoch
  List<TerritoryNode> getTerritoriesForEpoch(String epochId) {
    final visibleVillages = getVillagesForEpoch(epochId).map((v) => v.id).toSet();
    return _territories.values.where((t) {
      return t.villageIds.any((vid) => visibleVillages.contains(vid));
    }).toList();
  }

  /// Calculates total curriculum completion percentage across all territories
  double get overallProgress {
    if (_villages.isEmpty) return 0.0;
    double sum = 0.0;
    int count = 0;
    for (final v in _villages.values) {
      if (v.lessons.isNotEmpty) {
        sum += v.completionPercentage;
        count++;
      }
    }
    return count > 0 ? (sum / count) : 0.0;
  }

  /// Finds active main quest across Pindorama
  QuestNode? getActiveMainQuest() {
    for (final v in _villages.values) {
      for (final q in v.quests) {
        if (q.isMain && !q.isCompleted) return q;
      }
    }
    return null;
  }

  /// Returns a copy with updated village lesson progress
  CurriculumWorldGraph updateLessonStatus({
    required String villageId,
    required String lessonId,
    required LessonStatus newStatus,
    double? newProgress,
  }) {
    final v = _villages[villageId];
    if (v == null) return this;

    final updatedLessons = v.lessons.map((lesson) {
      if (lesson.id == lessonId) {
        return lesson.copyWith(
          status: newStatus,
          progressPercentage: newProgress ?? (newStatus == LessonStatus.completed ? 1.0 : lesson.progressPercentage),
        );
      }
      return lesson;
    }).toList();

    // Unlock dependent lessons within village if prerequisite completed
    final completedIds = updatedLessons
        .where((l) => l.status == LessonStatus.completed || l.status == LessonStatus.mastered)
        .map((l) => l.id)
        .toSet();

    final unblockedLessons = updatedLessons.map((l) {
      if (l.status == LessonStatus.locked &&
          l.prerequisiteIds.isNotEmpty &&
          l.prerequisiteIds.every((prereq) => completedIds.contains(prereq))) {
        return l.copyWith(status: LessonStatus.available);
      }
      return l;
    }).toList();

    // Check if village is mastered
    final isMastered = unblockedLessons.isNotEmpty &&
        unblockedLessons.every((l) => l.status == LessonStatus.completed || l.status == LessonStatus.mastered);

    final updatedVillage = v.copyWith(
      lessons: unblockedLessons,
      isMastered: isMastered,
      stage: isMastered ? VillageEvolutionStage.historica : v.stage,
    );

    final newVillages = Map<String, VillageNode>.from(_villages);
    newVillages[villageId] = updatedVillage;

    return CurriculumWorldGraph(
      territories: _territories.values.toList(),
      villages: newVillages.values.toList(),
    );
  }
}
