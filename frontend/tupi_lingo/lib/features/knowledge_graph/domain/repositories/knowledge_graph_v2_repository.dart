import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/subgraph_extractor.dart';

/// Contract for Knowledge Graph V2 operations.
abstract class KnowledgeGraphV2Repository {
  /// Fetches a node by ID.
  Future<KGNodeV2?> getNode(String nodeId);

  /// Retrieves all nodes of a specific type.
  Future<List<KGNodeV2>> getNodesByType(KGNodeType type, {int? variantId});

  /// Extracts a localized subgraph around a node.
  Future<SubgraphV2> getLocalizedSubgraph(String centerNodeId, {int maxRadius = 2});

  /// Synchronizes graph data with remote database.
  Future<void> syncGraph({int? variantId});
}
