import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_facets.dart';
import 'package:tupi_lingo/features/semantic_search/domain/repositories/search_index_repository.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/semantic_search_engine.dart';
import 'package:tupi_lingo/features/semantic_search/data/repositories/search_index_repository_impl.dart';

/// Singleton search repository provider.
final searchRepositoryProvider = Provider<SearchIndexRepository>((ref) {
  return SearchIndexRepositoryImpl();
});

/// Semantic search engine provider.
final semanticSearchEngineProvider = Provider<SemanticSearchEngine>((ref) {
  return SemanticSearchEngine();
});

/// Provider returning instant (< 2ms) autocomplete suggestions for a given prefix.
final autocompleteSuggestionsProvider =
    Provider.family<List<MapEntry<String, String>>, String>((ref, prefix) {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getSuggestions(prefix);
});

/// Provider executing a multi-axis search for a given SearchQuery.
final searchResultsProvider =
    FutureProvider.family<List<SearchResult>, SearchQuery>((ref, query) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.search(query);
});

/// Provider fetching current search facets (biomes, categories, roots).
final searchFacetsProvider = FutureProvider<SearchFacets>((ref) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getFacets();
});
