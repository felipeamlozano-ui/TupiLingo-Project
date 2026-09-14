import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';

/// Single ranked search hit returned by the Semantic Search Engine.
@immutable
class SearchResult {
  final String id;
  final String wordLabel;
  final String translationPt;
  final double score;
  final SearchAxis matchingAxis;
  final String explanation;
  final String? root;
  final String? ipa;
  final String? category;
  final String? biome;
  final int? variantId;

  const SearchResult({
    required this.id,
    required this.wordLabel,
    required this.translationPt,
    required this.score,
    required this.matchingAxis,
    required this.explanation,
    this.root,
    this.ipa,
    this.category,
    this.biome,
    this.variantId,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String? ?? json['word_label'] as String? ?? '',
      wordLabel: json['word_label'] as String? ?? '',
      translationPt: json['translation_pt'] as String? ?? json['significado'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 1.0,
      matchingAxis: SearchAxis.values.firstWhere(
        (a) => a.name == json['matching_axis'],
        orElse: () => SearchAxis.lexical,
      ),
      explanation: json['explanation'] as String? ?? '',
      root: json['root'] as String?,
      ipa: json['ipa'] as String?,
      category: json['category'] as String?,
      biome: json['biome'] as String?,
      variantId: (json['variante_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word_label': wordLabel,
      'translation_pt': translationPt,
      'score': score,
      'matching_axis': matchingAxis.name,
      'explanation': explanation,
      'root': root,
      'ipa': ipa,
      'category': category,
      'biome': biome,
      'variante_id': variantId,
    };
  }

  @override
  String toString() => 'SearchResult($wordLabel ["$translationPt"], score: ${score.toStringAsFixed(2)}, axis: ${matchingAxis.name})';
}
