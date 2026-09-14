import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_edge_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/subgraph_extractor.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/repositories/knowledge_graph_v2_repository.dart';

/// Implementation of KnowledgeGraphV2Repository with embedded localized topology.
class KnowledgeGraphV2RepositoryImpl implements KnowledgeGraphV2Repository {
  final Map<String, KGNodeV2> _nodes = {};
  final List<KGEdgeV2> _edges = [];
  final SubgraphExtractor _extractor;

  KnowledgeGraphV2RepositoryImpl({SubgraphExtractor? extractor})
      : _extractor = extractor ?? SubgraphExtractor() {
    _initSampleGraph();
  }

  void _initSampleGraph() {
    // 1. Territories
    _nodes['terr_guanabara'] = const KGNodeV2(
      id: 'terr_guanabara',
      label: 'Baía de Guanabara',
      nodeType: KGNodeType.territory,
      variantId: 1,
      attributes: {'biome': 'Mata Atlântica', 'historical_year': 1555},
    );
    _nodes['terr_paranagua'] = const KGNodeV2(
      id: 'terr_paranagua',
      label: 'Paranaguá',
      nodeType: KGNodeType.territory,
      variantId: 1,
      attributes: {'biome': 'Litoral', 'historical_year': 1540},
    );

    // 2. Lexical & Concepts
    _nodes['lex_ygara'] = const KGNodeV2(
      id: 'lex_ygara',
      label: 'ygara',
      nodeType: KGNodeType.lexical,
      translationPt: 'canoa',
      morphologyRoot: 'y',
      variantId: 1,
    );
    _nodes['lex_parana'] = const KGNodeV2(
      id: 'lex_parana',
      label: 'paranã',
      nodeType: KGNodeType.lexical,
      translationPt: 'mar / grande rio',
      morphologyRoot: 'y',
      variantId: 1,
    );
    _nodes['cult_tamoios'] = const KGNodeV2(
      id: 'cult_tamoios',
      label: 'Confederação dos Tamoios',
      nodeType: KGNodeType.culture,
      variantId: 1,
      attributes: {'historical_year': 1554},
    );

    // 3. Edges
    _edges.add(const KGEdgeV2(
      id: 'edge_1',
      sourceNodeId: 'terr_guanabara',
      targetNodeId: 'cult_tamoios',
      edgeType: KGEdgeType.culturalContext,
    ));
    _edges.add(const KGEdgeV2(
      id: 'edge_2',
      sourceNodeId: 'terr_guanabara',
      targetNodeId: 'lex_ygara',
      edgeType: KGEdgeType.culturalContext,
    ));
    _edges.add(const KGEdgeV2(
      id: 'edge_3',
      sourceNodeId: 'lex_ygara',
      targetNodeId: 'lex_parana',
      edgeType: KGEdgeType.morphology,
    ));
  }

  @override
  Future<KGNodeV2?> getNode(String nodeId) async => _nodes[nodeId];

  @override
  Future<List<KGNodeV2>> getNodesByType(KGNodeType type, {int? variantId}) async {
    return _nodes.values.where((n) {
      if (n.nodeType != type) return false;
      if (variantId != null && n.variantId != null && n.variantId != variantId) return false;
      return true;
    }).toList();
  }

  @override
  Future<SubgraphV2> getLocalizedSubgraph(String centerNodeId, {int maxRadius = 2}) async {
    return _extractor.extract(
      centerNodeId: centerNodeId,
      allNodes: _nodes,
      allEdges: _edges,
      maxRadius: maxRadius,
    );
  }

  @override
  Future<void> syncGraph({int? variantId}) async {
    // Best-effort remote synchronization
  }
}
