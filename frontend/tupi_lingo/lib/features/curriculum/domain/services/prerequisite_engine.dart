import 'package:tupi_lingo/features/curriculum/domain/entities/curriculum_node.dart';

/// Topological DAG engine for curriculum prerequisites and unlock criteria (RFC-012A Chapter 12).
class PrerequisiteEngine {
  /// Evaluates whether [node] can be unlocked by the learner.
  bool canUnlockNode({
    required CurriculumNode node,
    required Set<String> completedNodeIds,
    required Map<String, double> masteryByNode,
  }) {
    // If no prerequisites, unlocked by default
    if (node.prerequisiteIds.isEmpty) return true;

    // All prerequisites must be completed OR meet the required mastery threshold
    for (final prereqId in node.prerequisiteIds) {
      final isCompleted = completedNodeIds.contains(prereqId);
      final mastery = masteryByNode[prereqId] ?? 0.0;

      if (!isCompleted && mastery < node.requiredMasteryThreshold) {
        return false;
      }
    }

    return true;
  }

  /// Filters a list of [nodes], returning only those that meet unlock criteria.
  List<CurriculumNode> getAvailableNodes({
    required List<CurriculumNode> allNodes,
    required Set<String> completedNodeIds,
    required Map<String, double> masteryByNode,
  }) {
    return allNodes.where((node) {
      if (completedNodeIds.contains(node.id)) return true;
      return canUnlockNode(
        node: node,
        completedNodeIds: completedNodeIds,
        masteryByNode: masteryByNode,
      );
    }).toList();
  }

  /// Performs topological sort of curriculum nodes using Kahn's algorithm.
  List<CurriculumNode> topologicalSort(List<CurriculumNode> nodes) {
    final nodeMap = {for (final n in nodes) n.id: n};
    final inDegree = <String, int>{for (final n in nodes) n.id: 0};
    final adjacency = <String, List<String>>{for (final n in nodes) n.id: []};

    // Build DAG graph
    for (final node in nodes) {
      for (final prereq in node.prerequisiteIds) {
        if (nodeMap.containsKey(prereq)) {
          adjacency[prereq]?.add(node.id);
          inDegree[node.id] = (inDegree[node.id] ?? 0) + 1;
        }
      }
    }

    // Queue nodes with zero in-degree (root nodes)
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    final sorted = <CurriculumNode>[];
    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      final node = nodeMap[currId];
      if (node != null) {
        sorted.add(node);
      }

      for (final neighbor in adjacency[currId] ?? const <String>[]) {
        inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1;
        if (inDegree[neighbor] == 0) {
          queue.add(neighbor);
        }
      }
    }

    // Fallback if cycles exist
    if (sorted.length < nodes.length) {
      return List.from(nodes)..sort((a, b) => a.order.compareTo(b.order));
    }

    return sorted;
  }
}
