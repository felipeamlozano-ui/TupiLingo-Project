import 'package:flutter/foundation.dart';

/// Semantic relationship types connecting Knowledge Graph V2 nodes.
enum KGEdgeType {
  prerequisite,    // Must master source before target
  cluster,         // Semantic cluster grouping
  morphology,      // Shared root or derivation
  cognate,         // Cross-variant historical cognate
  culturalContext; // Cultural artifact or territory connection

  static KGEdgeType fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'prerequisite':
      case 'pre_requisito':
        return KGEdgeType.prerequisite;
      case 'cluster':
        return KGEdgeType.cluster;
      case 'morphology':
      case 'morfologia':
        return KGEdgeType.morphology;
      case 'cognate':
      case 'cognato':
        return KGEdgeType.cognate;
      case 'culturalcontext':
      case 'contexto':
      default:
        return KGEdgeType.culturalContext;
    }
  }
}

/// Directed edge between two Knowledge Graph nodes.
@immutable
class KGEdgeV2 {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final KGEdgeType edgeType;
  final double weight; // [0.0, 1.0]

  const KGEdgeV2({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.edgeType,
    this.weight = 1.0,
  });

  factory KGEdgeV2.fromJson(Map<String, dynamic> json) {
    return KGEdgeV2(
      id: json['id'] as String? ?? '',
      sourceNodeId: json['source_node_id'] as String? ?? '',
      targetNodeId: json['target_node_id'] as String? ?? '',
      edgeType: KGEdgeType.fromString(json['edge_type'] as String? ?? 'cluster'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType.name,
      'weight': weight,
    };
  }
}
