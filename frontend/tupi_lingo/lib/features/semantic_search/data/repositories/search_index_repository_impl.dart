import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_facets.dart';
import 'package:tupi_lingo/features/semantic_search/domain/repositories/search_index_repository.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/semantic_search_engine.dart';
import 'package:tupi_lingo/features/semantic_search/data/datasources/search_local_index.dart';
import 'package:tupi_lingo/features/semantic_search/data/datasources/search_remote_datasource.dart';

/// Implementation of SearchIndexRepository using SearchLocalIndex and SemanticSearchEngine.
class SearchIndexRepositoryImpl implements SearchIndexRepository {
  final SearchLocalIndex _localIndex;
  final SearchRemoteDataSource _remoteDataSource;
  final SemanticSearchEngine _engine;

  SearchIndexRepositoryImpl({
    SearchLocalIndex? localIndex,
    SearchRemoteDataSource? remoteDataSource,
    SemanticSearchEngine? engine,
  })  : _localIndex = localIndex ?? SearchLocalIndex(),
        _remoteDataSource = remoteDataSource ?? SearchRemoteDataSource(),
        _engine = engine ?? SemanticSearchEngine();

  @override
  Future<List<SearchResult>> search(SearchQuery query) async {
    final catalog = _localIndex.getCatalog(variantId: query.variantId);
    return _engine.executeSearch(query, catalog);
  }

  @override
  List<MapEntry<String, String>> getSuggestions(String prefix, {int limit = 8}) {
    return _localIndex.autocompleteEngine.suggest(prefix, limit: limit);
  }

  @override
  Future<SearchFacets> getFacets({int? variantId}) async {
    return _localIndex.getFacets(variantId: variantId);
  }

  @override
  Future<void> indexWord(SearchResult item) async {
    _localIndex.addWord(item);
  }

  @override
  Future<void> syncIndex({int? variantId}) async {
    final remoteItems = await _remoteDataSource.fetchDictionary(variantId: variantId);
    for (final item in remoteItems) {
      _localIndex.addWord(item);
    }
  }
}
