import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_edge_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/graph_traversal_engine.dart';

/// Subgraph container holding connected nodes and edges for localized caching.
class SubgraphV2 {
  final Map<String, KGNodeV2> nodes;
  final List<KGEdgeV2> edges;

  const SubgraphV2({
    required this.nodes,
    required this.edges,
  });
}

/// Extracts localized subgraphs (e.g. for an active territory).
class SubgraphExtractor {
  final GraphTraversalEngine _traversal;

  SubgraphExtractor({GraphTraversalEngine? traversal})
      : _traversal = traversal ?? GraphTraversalEngine();

  /// Extracts a localized subgraph centered on [centerNodeId] within [maxRadius] hops.
  SubgraphV2 extract({
    required String centerNodeId,
    required Map<String, KGNodeV2> allNodes,
    required List<KGEdgeV2> allEdges,
    int maxRadius = 2,
  }) {
    final connectedNodes = _traversal.bfs(
      startNodeId: centerNodeId,
      nodes: allNodes,
      edges: allEdges,
      maxDepth: maxRadius,
    );

    final nodeMap = <String, KGNodeV2>{};
    if (allNodes.containsKey(centerNodeId)) {
      nodeMap[centerNodeId] = allNodes[centerNodeId]!;
    }
    for (final node in connectedNodes) {
      nodeMap[node.id] = node;
    }

    final subgraphEdges = allEdges.where((e) {
      return nodeMap.containsKey(e.sourceNodeId) && nodeMap.containsKey(e.targetNodeId);
    }).toList();

    return SubgraphV2(nodes: nodeMap, edges: subgraphEdges);
  }
}
