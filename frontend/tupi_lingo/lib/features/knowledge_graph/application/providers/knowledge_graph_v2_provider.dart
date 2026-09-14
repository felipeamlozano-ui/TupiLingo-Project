import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/repositories/knowledge_graph_v2_repository.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/subgraph_extractor.dart';
import 'package:tupi_lingo/features/knowledge_graph/data/repositories/knowledge_graph_v2_repository_impl.dart';

/// Knowledge Graph V2 repository provider.
final knowledgeGraphV2RepositoryProvider = Provider<KnowledgeGraphV2Repository>((ref) {
  return KnowledgeGraphV2RepositoryImpl();
});

/// Future provider for localized subgraphs.
final localizedSubgraphProvider =
    FutureProvider.family<SubgraphV2, String>((ref, centerNodeId) async {
  final repo = ref.watch(knowledgeGraphV2RepositoryProvider);
  return repo.getLocalizedSubgraph(centerNodeId);
});

/// Future provider to fetch nodes of a specific type.
final nodesByTypeProvider =
    FutureProvider.family<List<KGNodeV2>, KGNodeType>((ref, type) async {
  final repo = ref.watch(knowledgeGraphV2RepositoryProvider);
  return repo.getNodesByType(type);
});
