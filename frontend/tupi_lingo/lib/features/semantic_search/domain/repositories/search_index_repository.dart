import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_facets.dart';

/// Contract for indexing and querying Tupi linguistic terms.
abstract class SearchIndexRepository {
  /// Executes a multi-axis search.
  Future<List<SearchResult>> search(SearchQuery query);

  /// Retrieves fast prefix suggestions.
  List<MapEntry<String, String>> getSuggestions(String prefix, {int limit = 8});

  /// Retrieves available facets (biomes, categories, roots).
  Future<SearchFacets> getFacets({int? variantId});

  /// Indexes a new word entry into the search repository.
  Future<void> indexWord(SearchResult item);

  /// Synchronizes search index with remote database.
  Future<void> syncIndex({int? variantId});
}
