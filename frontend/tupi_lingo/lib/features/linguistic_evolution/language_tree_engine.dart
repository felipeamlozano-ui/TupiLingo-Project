import 'package:flutter/foundation.dart';

/// Node in the Tupi phylogenetic language tree (RFC-012B Chapter 28).
@immutable
class EvolutionNode {
  final String id;
  final String name;
  final int approximateYear;
  final String geographicRegion;
  final String description;
  final bool isLiving;

  const EvolutionNode({
    required this.id,
    required this.name,
    required this.approximateYear,
    required this.geographicRegion,
    required this.description,
    this.isLiving = false,
  });
}

/// Historical branch in linguistic evolution.
@immutable
class EvolutionEdge {
  final String sourceId;
  final String targetId;
  final String relationship; // e.g. 'ramificação histórica', 'isolamento geográfico'

  const EvolutionEdge({
    required this.sourceId,
    required this.targetId,
    required this.relationship,
  });
}

/// LanguageTreeEngine building and traversing Tupi linguistic evolution trees.
class LanguageTreeEngine {
  final Map<String, EvolutionNode> _nodes = {};
  final List<EvolutionEdge> _edges = [];

  LanguageTreeEngine() {
    _initHistoricalTree();
  }

  void _initHistoricalTree() {
    _nodes['proto_tupi'] = const EvolutionNode(
      id: 'proto_tupi',
      name: 'Proto-Tupi (Ancestral)',
      approximateYear: 1000,
      geographicRegion: 'Bacia Amazônica / Madeira-Guaporé',
      description: 'Língua ancestral hipotética reconstruída por linguistas.',
    );
    _nodes['tupi_antigo'] = const EvolutionNode(
      id: 'tupi_antigo',
      name: 'Tupi Antigo (Tupinambá)',
      approximateYear: 1550,
      geographicRegion: 'Costa Brasileira (Atlântico)',
      description: 'Língua clássica da costa brasileira documentada no século XVI.',
    );
    _nodes['lingua_geral'] = const EvolutionNode(
      id: 'lingua_geral',
      name: 'Língua Geral Colonial',
      approximateYear: 1650,
      geographicRegion: 'São Paulo e Amazônia Colonial',
      description: 'Língua franca de comunicação entre colonizadores e povos indígenas.',
    );
    _nodes['nheengatu'] = const EvolutionNode(
      id: 'nheengatu',
      name: 'Nheengatu (Língua Geral Amazônica)',
      approximateYear: 1800,
      geographicRegion: 'Rio Negro e Vale Amazônico',
      description: 'Variante viva moderna falada na Amazônia e língua co-oficial.',
      isLiving: true,
    );
    _nodes['guarani_mbya'] = const EvolutionNode(
      id: 'guarani_mbya',
      name: 'Guarani Mbyá',
      approximateYear: 1700,
      geographicRegion: 'Sul e Sudeste do Brasil / Paraguai',
      description: 'Variante viva da família Tupi-Guarani com rica tradição oral.',
      isLiving: true,
    );

    _edges.add(const EvolutionEdge(
      sourceId: 'proto_tupi',
      targetId: 'tupi_antigo',
      relationship: 'Ramificação litorânea',
    ));
    _edges.add(const EvolutionEdge(
      sourceId: 'proto_tupi',
      targetId: 'guarani_mbya',
      relationship: 'Ramo meridional',
    ));
    _edges.add(const EvolutionEdge(
      sourceId: 'tupi_antigo',
      targetId: 'lingua_geral',
      relationship: 'Período colonial',
    ));
    _edges.add(const EvolutionEdge(
      sourceId: 'lingua_geral',
      targetId: 'nheengatu',
      relationship: 'Continuidade amazônica',
    ));
  }

  /// Traces ancestry chain from a modern descendant up to the root ancestor.
  List<EvolutionNode> traceAncestry(String nodeId) {
    final List<EvolutionNode> path = [];
    String? currentId = nodeId;

    while (currentId != null && _nodes.containsKey(currentId)) {
      path.add(_nodes[currentId]!);
      final parentEdge = _edges.cast<EvolutionEdge?>().firstWhere(
            (e) => e?.targetId == currentId,
            orElse: () => null,
          );
      currentId = parentEdge?.sourceId;
    }

    return path.reversed.toList();
  }
}
