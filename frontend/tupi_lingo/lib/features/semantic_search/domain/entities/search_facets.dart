import 'package:flutter/foundation.dart';

/// Available faceted filters for refining semantic searches.
@immutable
class SearchFacets {
  final List<String> biomes;
  final List<String> categories;
  final List<String> commonRoots;

  const SearchFacets({
    this.biomes = const [],
    this.categories = const [],
    this.commonRoots = const [],
  });

  factory SearchFacets.empty() => const SearchFacets();
}
