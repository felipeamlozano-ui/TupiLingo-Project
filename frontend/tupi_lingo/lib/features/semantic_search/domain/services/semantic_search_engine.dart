import 'package:tupi_lingo/features/semantic_search/domain/entities/search_query.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/similarity_ranking_engine.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_similarity_engine.dart';

/// Core multi-axis search orchestrator operating without LLM invocation (ADR-009).
class SemanticSearchEngine {
  final SimilarityRankingEngine _ranker;
  final MorphologyParser _parser;
  final MorphologySimilarityEngine _morphSimilarity;

  SemanticSearchEngine({
    SimilarityRankingEngine? ranker,
    MorphologyParser? parser,
    MorphologySimilarityEngine? morphSimilarity,
  })  : _ranker = ranker ?? SimilarityRankingEngine(),
        _parser = parser ?? MorphologyParser(),
        _morphSimilarity = morphSimilarity ?? MorphologySimilarityEngine();

  /// Executes multi-axis search over candidate [catalog].
  List<SearchResult> executeSearch(SearchQuery query, List<SearchResult> catalog) {
    if (query.isEmpty) return const [];

    final q = query.normalizedText;
    final List<SearchResult> candidates = [];

    // Pre-parse query morphology if enabled
    final queryAnalysis = query.enabledAxes.contains(SearchAxis.morphological)
        ? _parser.parse(q, variantId: query.variantId)
        : null;

    for (final item in catalog) {
      // 1. Variant scoping check
      if (query.variantId != null && item.variantId != null && item.variantId != query.variantId) {
        continue;
      }

      // 2. Biome filter check
      if (query.biomeFilter != null && query.biomeFilter!.isNotEmpty) {
        if (item.biome == null || !item.biome!.toLowerCase().contains(query.biomeFilter!.toLowerCase())) {
          continue;
        }
      }

      // 3. Category filter check
      if (query.categoryFilter != null && query.categoryFilter!.isNotEmpty) {
        if (item.category == null || !item.category!.toLowerCase().contains(query.categoryFilter!.toLowerCase())) {
          continue;
        }
      }

      // ── AXIS 1: Lexical (Tupi word label) ──
      if (query.enabledAxes.contains(SearchAxis.lexical)) {
        final score = _ranker.computeTextScore(q, item.wordLabel);
        if (score >= 0.50) {
          candidates.add(SearchResult(
            id: item.id,
            wordLabel: item.wordLabel,
            translationPt: item.translationPt,
            score: score,
            matchingAxis: SearchAxis.lexical,
            explanation: score >= 0.99
                ? 'Correspondência exata em Tupi'
                : 'Correspondência lexical em Tupi (${(score * 100).toInt()}%)',
            root: item.root,
            ipa: item.ipa,
            category: item.category,
            biome: item.biome,
            variantId: item.variantId,
          ));
          continue;
        }
      }

      // ── AXIS 2: Portuguese Translation ──
      if (query.enabledAxes.contains(SearchAxis.translation)) {
        final score = _ranker.computeTextScore(q, item.translationPt);
        if (score >= 0.50) {
          candidates.add(SearchResult(
            id: item.id,
            wordLabel: item.wordLabel,
            translationPt: item.translationPt,
            score: score * 0.95, // slight discount vs exact native label
            matchingAxis: SearchAxis.translation,
            explanation: 'Correspondência de tradução em Português',
            root: item.root,
            ipa: item.ipa,
            category: item.category,
            biome: item.biome,
            variantId: item.variantId,
          ));
          continue;
        }
      }

      // ── AXIS 3: Morphological Root & Family ──
      if (query.enabledAxes.contains(SearchAxis.morphological) && queryAnalysis != null) {
        // Check if item shares root with query, or if item word contains the query root
        if (item.root != null && item.root!.isNotEmpty && item.root == queryAnalysis.rootSurface) {
          candidates.add(SearchResult(
            id: item.id,
            wordLabel: item.wordLabel,
            translationPt: item.translationPt,
            score: 0.85,
            matchingAxis: SearchAxis.morphological,
            explanation: 'Mesmo radical morfológico ("${queryAnalysis.rootSurface}")',
            root: item.root,
            ipa: item.ipa,
            category: item.category,
            biome: item.biome,
            variantId: item.variantId,
          ));
          continue;
        }

        // Morphological similarity engine check
        final morphSim = _morphSimilarity.calculateSimilarity(q, item.wordLabel, variantId: query.variantId);
        if (morphSim >= 0.70) {
          candidates.add(SearchResult(
            id: item.id,
            wordLabel: item.wordLabel,
            translationPt: item.translationPt,
            score: morphSim * 0.90,
            matchingAxis: SearchAxis.morphological,
            explanation: 'Similaridade morfológica (${(morphSim * 100).toInt()}%)',
            root: item.root,
            ipa: item.ipa,
            category: item.category,
            biome: item.biome,
            variantId: item.variantId,
          ));
        }
      }
    }

    return _ranker.rankAndDeduplicate(candidates, limit: query.limit);
  }
}
