import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/curriculum/domain/entities/curriculum_node.dart';
import 'package:tupi_lingo/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:tupi_lingo/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:tupi_lingo/features/curriculum/domain/services/prerequisite_engine.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepositoryImpl();
});

final prerequisiteEngineProvider = Provider<PrerequisiteEngine>((ref) {
  return PrerequisiteEngine();
});

final territoryCurriculumProvider =
    FutureProvider.family<List<CurriculumNode>, ({String territoryId, String userId, Map<String, double> masteryMap})>(
  (ref, args) async {
    final repo = ref.watch(curriculumRepositoryProvider);
    final engine = ref.watch(prerequisiteEngineProvider);

    final allNodes = await repo.getNodesByTerritory(args.territoryId);
    final completedIds = await repo.getCompletedNodeIds(args.userId);

    // Topological sort then unlock evaluation
    final sorted = engine.topologicalSort(allNodes);

    return sorted.map((node) {
      final isCompleted = completedIds.contains(node.id);
      final isUnlocked = isCompleted ||
          engine.canUnlockNode(
            node: node,
            completedNodeIds: completedIds,
            masteryByNode: args.masteryMap,
          );

      return node.copyWith(
        isUnlocked: isUnlocked,
        isCompleted: isCompleted,
      );
    }).toList();
  },
);
