import 'package:tupi_lingo/features/curriculum/domain/entities/curriculum_node.dart';

/// Contract for Curriculum Graph persistence and query.
abstract class CurriculumRepository {
  Future<List<CurriculumNode>> getNodesByTerritory(String territoryId);
  Future<CurriculumNode?> getNodeById(String nodeId);
  Future<void> markNodeCompleted(String userId, String nodeId);
  Future<Set<String>> getCompletedNodeIds(String userId);
}
