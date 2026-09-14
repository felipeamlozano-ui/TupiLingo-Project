import 'dart:collection';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_edge_v2.dart';

/// Graph traversal engine supporting multi-hop BFS and DFS searches over Knowledge Graph V2.
class GraphTraversalEngine {
  /// Executes a Breadth-First Search from [startNodeId] up to [maxDepth] hops.
  List<KGNodeV2> bfs({
    required String startNodeId,
    required Map<String, KGNodeV2> nodes,
    required List<KGEdgeV2> edges,
    int maxDepth = 2,
    Set<KGEdgeType>? allowedEdgeTypes,
  }) {
    if (!nodes.containsKey(startNodeId)) return const [];

    final visited = <String>{startNodeId};
    final queue = Queue<MapEntry<String, int>>();
    queue.add(MapEntry(startNodeId, 0));

    final List<KGNodeV2> result = [];

    // Pre-build adjacency list
    final Map<String, List<KGEdgeV2>> adj = {};
    for (final edge in edges) {
      if (allowedEdgeTypes != null && !allowedEdgeTypes.contains(edge.edgeType)) {
        continue;
      }
      adj.putIfAbsent(edge.sourceNodeId, () => []).add(edge);
      // Graph is treated as undirected for semantic neighborhood traversal
      adj.putIfAbsent(edge.targetNodeId, () => []).add(edge);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final currentId = current.key;
      final currentDepth = current.value;

      if (currentId != startNodeId && nodes.containsKey(currentId)) {
        result.add(nodes[currentId]!);
      }

      if (currentDepth >= maxDepth) continue;

      final neighbors = adj[currentId] ?? [];
      for (final edge in neighbors) {
        final nextId = edge.sourceNodeId == currentId ? edge.targetNodeId : edge.sourceNodeId;
        if (!visited.contains(nextId) && nodes.containsKey(nextId)) {
          visited.add(nextId);
          queue.add(MapEntry(nextId, currentDepth + 1));
        }
      }
    }

    return result;
  }
}
