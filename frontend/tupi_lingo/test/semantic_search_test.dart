import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/autocomplete_engine.dart';
import 'package:tupi_lingo/features/semantic_search/data/repositories/search_index_repository_impl.dart';

void main() {
  group('Semantic Search Platform (RFC-012B Ch.29)', () {
    late SearchIndexRepositoryImpl repository;
    late AutocompleteEngine autocomplete;

    setUp(() {
      repository = SearchIndexRepositoryImpl();
      autocomplete = AutocompleteEngine();
      autocomplete.insert('ygara', translation: 'canoa');
      autocomplete.insert('y', translation: 'água');
      autocomplete.insert('igarapé', translation: 'riacho');
      autocomplete.insert('oka', translation: 'casa');
    });

    test('Trie autocomplete returns prefix suggestions with high performance', () {
      final suggestions = autocomplete.suggest('y');
      final words = suggestions.map((s) => s.key).toList();

      expect(words, contains('y'));
      expect(words, contains('ygara'));
      expect(words, isNot(contains('oka')));
    });

    test('multi-axis search finds direct lexical match (oka)', () async {
      const query = SearchQuery(rawQuery: 'oka');
      final results = await repository.search(query);

      expect(results.isNotEmpty, isTrue);
      expect(results.first.wordLabel, equals('oka'));
      expect(results.first.matchingAxis, equals(SearchAxis.lexical));
      expect(results.first.score, greaterThanOrEqualTo(0.95));
    });

    test('multi-axis search finds Portuguese translation match (água)', () async {
      const query = SearchQuery(rawQuery: 'água');
      final results = await repository.search(query);

      expect(results.isNotEmpty, isTrue);
      final matchedWords = results.map((r) => r.wordLabel).toList();
      expect(matchedWords, contains('y'));
    });

    test('multi-axis search discovers words via shared morphological root (y -> ygara, paranã)', () async {
      const query = SearchQuery(
        rawQuery: 'y',
        enabledAxes: {SearchAxis.lexical, SearchAxis.morphological},
      );
      final results = await repository.search(query);

      final matchedLabels = results.map((r) => r.wordLabel).toList();
      expect(matchedLabels, contains('y'));
      expect(matchedLabels, contains('ygara'));
    });

    test('biome filter respects metadata constraints', () async {
      const queryAmazonia = SearchQuery(
        rawQuery: 'igarapé',
        biomeFilter: 'Amazônia',
      );
      final results = await repository.search(queryAmazonia);

      expect(results.isNotEmpty, isTrue);
      expect(results.first.wordLabel, equals('igarapé'));

      const queryMismatch = SearchQuery(
        rawQuery: 'igarapé',
        biomeFilter: 'Pampa', // Mismatched biome
      );
      final emptyResults = await repository.search(queryMismatch);
      expect(emptyResults.isEmpty, isTrue);
    });

    test('search facets return populated categories, biomes, and roots', () async {
      final facets = await repository.getFacets();
      expect(facets.biomes, contains('Mata Atlântica'));
      expect(facets.categories, contains('Natureza'));
      expect(facets.commonRoots, contains('y'));
    });
  });
}
