import 'package:flutter/foundation.dart';

/// Search axes supported by the RFC-012B Semantic Search Platform.
enum SearchAxis {
  lexical,       // Direct Tupi label match
  translation,   // Portuguese meaning match
  morphological, // Root / family / affix match
  phonetic,      // IPA or sound-alike match
  cultural;      // Biome / territory / mythology context

  String get displayName {
    switch (this) {
      case SearchAxis.lexical:
        return 'Léxico Tupi';
      case SearchAxis.translation:
        return 'Tradução em Português';
      case SearchAxis.morphological:
        return 'Família Morfológica';
      case SearchAxis.phonetic:
        return 'Fonética / Som';
      case SearchAxis.cultural:
        return 'Contexto Cultural / Bioma';
    }
  }
}

/// Structured search query with filters and selected axes.
@immutable
class SearchQuery {
  final String rawQuery;
  final Set<SearchAxis> enabledAxes;
  final int? variantId;
  final String? biomeFilter;
  final String? categoryFilter;
  final int limit;

  const SearchQuery({
    required this.rawQuery,
    this.enabledAxes = const {
      SearchAxis.lexical,
      SearchAxis.translation,
      SearchAxis.morphological,
    },
    this.variantId,
    this.biomeFilter,
    this.categoryFilter,
    this.limit = 20,
  });

  String get normalizedText => rawQuery.trim().toLowerCase();

  bool get isEmpty => normalizedText.isEmpty;

  SearchQuery copyWith({
    String? rawQuery,
    Set<SearchAxis>? enabledAxes,
    int? variantId,
    String? biomeFilter,
    String? categoryFilter,
    int? limit,
  }) {
    return SearchQuery(
      rawQuery: rawQuery ?? this.rawQuery,
      enabledAxes: enabledAxes ?? this.enabledAxes,
      variantId: variantId ?? this.variantId,
      biomeFilter: biomeFilter ?? this.biomeFilter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      limit: limit ?? this.limit,
    );
  }
}
