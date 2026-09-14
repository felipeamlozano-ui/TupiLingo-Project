import 'package:flutter/foundation.dart';

/// Category of knowledge represented in Knowledge Graph V2 (Chapter 36).
enum KGNodeType {
  lexical,    // Words, expressions
  grammar,    // Affixes, particles, constructions
  culture,    // Traditions, artifacts, ceremonies
  mythology,  // Deities, spiritual entities, cosmological concepts
  territory;  // Indigenous geographic locations, biomes

  static KGNodeType fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'lexical':
      case 'lexico':
        return KGNodeType.lexical;
      case 'grammar':
      case 'gramatica':
        return KGNodeType.grammar;
      case 'culture':
      case 'cultura':
        return KGNodeType.culture;
      case 'mythology':
      case 'mitologia':
        return KGNodeType.mythology;
      case 'territory':
      case 'territorio':
      default:
        return KGNodeType.territory;
    }
  }
}

/// Knowledge Graph Node V2 with multi-modal embeddings and metadata slots.
@immutable
class KGNodeV2 {
  final String id;
  final String label;
  final KGNodeType nodeType;
  final int? variantId;
  final String? translationPt;
  final String? morphologyRoot;
  final String? ipa;
  final List<double>? semanticEmbedding; // 256D/768D vector
  final Map<String, dynamic> attributes;

  const KGNodeV2({
    required this.id,
    required this.label,
    required this.nodeType,
    this.variantId,
    this.translationPt,
    this.morphologyRoot,
    this.ipa,
    this.semanticEmbedding,
    this.attributes = const {},
  });

  factory KGNodeV2.fromJson(Map<String, dynamic> json) {
    return KGNodeV2(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      nodeType: KGNodeType.fromString(json['node_type'] as String? ?? 'lexical'),
      variantId: (json['variante_id'] as num?)?.toInt() ?? (json['variant_id'] as num?)?.toInt(),
      translationPt: json['translation_pt'] as String?,
      morphologyRoot: json['morphology_root'] as String?,
      ipa: json['ipa'] as String?,
      semanticEmbedding: (json['semantic_embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      attributes: json['attributes'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'node_type': nodeType.name,
      'variante_id': variantId,
      'translation_pt': translationPt,
      'morphology_root': morphologyRoot,
      'ipa': ipa,
      'semantic_embedding': semanticEmbedding,
      'attributes': attributes,
    };
  }
}
