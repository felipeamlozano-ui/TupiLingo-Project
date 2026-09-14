import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_facets.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/autocomplete_engine.dart';

/// Local index holding canonical Tupi vocabulary and feeding AutocompleteEngine.
class SearchLocalIndex {
  final List<SearchResult> _catalog = [];
  final AutocompleteEngine autocompleteEngine = AutocompleteEngine();

  SearchLocalIndex() {
    _initCanonicalCatalog();
  }

  List<SearchResult> getCatalog({int? variantId}) {
    if (variantId == null) return List.unmodifiable(_catalog);
    return _catalog.where((item) => item.variantId == null || item.variantId == variantId).toList();
  }

  void addWord(SearchResult item) {
    _catalog.add(item);
    autocompleteEngine.insert(item.wordLabel, translation: item.translationPt);
  }

  SearchFacets getFacets({int? variantId}) {
    final cat = getCatalog(variantId: variantId);
    final biomes = cat.map((e) => e.biome).whereType<String>().toSet().toList()..sort();
    final categories = cat.map((e) => e.category).whereType<String>().toSet().toList()..sort();
    final roots = cat.map((e) => e.root).whereType<String>().toSet().toList()..sort();

    return SearchFacets(
      biomes: biomes,
      categories: categories,
      commonRoots: roots,
    );
  }

  void _initCanonicalCatalog() {
    final seed = [
      const SearchResult(
        id: 'voc_y',
        wordLabel: 'y',
        translationPt: 'água, rio',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Radical elementar para água e rios',
        root: 'y',
        ipa: '/ɨ/',
        category: 'Natureza',
        biome: 'Mata Atlântica',
      ),
      const SearchResult(
        id: 'voc_ygara',
        wordLabel: 'ygara',
        translationPt: 'canoa (recipiente de água)',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Composição: y (água) + gara (recipiente)',
        root: 'y',
        ipa: '/ɨ.ɡa.ɾa/',
        category: 'Utensílios',
        biome: 'Mata Atlântica',
      ),
      const SearchResult(
        id: 'voc_parana',
        wordLabel: 'paranã',
        translationPt: 'mar, rio grande',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Derivado hidrográfico de grande extensão',
        root: 'y',
        ipa: '/pa.ɾa.nã/',
        category: 'Geografia',
        biome: 'Litoral',
      ),
      const SearchResult(
        id: 'voc_igarape',
        wordLabel: 'igarapé',
        translationPt: 'caminho de canoa, riacho',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Composição: ygara (canoa) + pé (caminho)',
        root: 'y',
        ipa: '/i.ɡa.ɾa.pɛ/',
        category: 'Geografia',
        biome: 'Amazônia',
      ),
      const SearchResult(
        id: 'voc_oka',
        wordLabel: 'oka',
        translationPt: 'casa, aldeia, habitação',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Habitação tradicional indígena',
        root: 'oka',
        ipa: '/ɔ.ka/',
        category: 'Sociedade',
        biome: 'Mata Atlântica',
      ),
      const SearchResult(
        id: 'voc_aba',
        wordLabel: 'abá',
        translationPt: 'homem, ser humano, pessoa',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Ser humano indígena',
        root: 'abá',
        ipa: '/a.ba/',
        category: 'Pessoas',
        biome: 'Geral',
      ),
      const SearchResult(
        id: 'voc_kunha',
        wordLabel: 'kunhã',
        translationPt: 'mulher',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Mulher',
        root: 'kunhã',
        ipa: '/ku.ɲã/',
        category: 'Pessoas',
        biome: 'Geral',
      ),
      const SearchResult(
        id: 'voc_ita',
        wordLabel: 'itá',
        translationPt: 'pedra, metal, rocha',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Elemento mineral lítico',
        root: 'itá',
        ipa: '/i.ta/',
        category: 'Mineralogia',
        biome: 'Geral',
      ),
      const SearchResult(
        id: 'voc_tata',
        wordLabel: 'tatá',
        translationPt: 'fogo',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Elemento ígneo primordial',
        root: 'tatá',
        ipa: '/ta.ta/',
        category: 'Natureza',
        biome: 'Geral',
      ),
      const SearchResult(
        id: 'voc_pira',
        wordLabel: 'pira',
        translationPt: 'peixe',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Fauna aquática',
        root: 'pira',
        ipa: '/pi.ɾa/',
        category: 'Fauna',
        biome: 'Rios',
      ),
      const SearchResult(
        id: 'voc_morubixaba',
        wordLabel: 'morubixaba',
        translationPt: 'cacique, líder supremo, chefe',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Líder da comunidade e guerreiro',
        root: 'abá',
        ipa: '/mɔ.ɾu.bi.ʃa.ba/',
        category: 'Sociedade',
        biome: 'Mata Atlântica',
      ),
      const SearchResult(
        id: 'voc_tupa',
        wordLabel: 'tupã',
        translationPt: 'trovão, divindade celestial',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Entidade do trovão e da tempestade',
        root: 'tupã',
        ipa: '/tu.pã/',
        category: 'Mitologia',
        biome: 'Geral',
      ),
      const SearchResult(
        id: 'voc_jaci',
        wordLabel: 'jaci',
        translationPt: 'lua',
        score: 1.0,
        matchingAxis: SearchAxis.lexical,
        explanation: 'Entidade lunar e guardiã da noite',
        root: 'jaci',
        ipa: '/ja.si/',
        category: 'Mitologia',
        biome: 'Geral',
      ),
    ];

    for (final item in seed) {
      addWord(item);
    }
  }
}
