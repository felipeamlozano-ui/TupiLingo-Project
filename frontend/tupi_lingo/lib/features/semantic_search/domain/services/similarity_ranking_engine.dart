import 'dart:math';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';

/// Scores and ranks candidate search results across multiple axes.
class SimilarityRankingEngine {
  /// Sorts candidate [results] in descending order of confidence and relevance.
  List<SearchResult> rankAndDeduplicate(List<SearchResult> candidates, {int limit = 20}) {
    final Map<String, SearchResult> deduped = {};

    for (final cand in candidates) {
      final key = cand.wordLabel.trim().toLowerCase();
      if (!deduped.containsKey(key) || deduped[key]!.score < cand.score) {
        deduped[key] = cand;
      }
    }

    final sorted = deduped.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }

  /// Calculates text match score between query and target string.
  double computeTextScore(String query, String target) {
    final q = query.trim().toLowerCase();
    final t = target.trim().toLowerCase();

    if (q == t) return 1.0;
    if (t.startsWith(q)) return 0.92;
    if (t.contains(q)) return 0.78;

    // Levenshtein similarity
    final distance = _levenshtein(q, t);
    final maxLen = max(q.length, t.length);
    if (maxLen == 0) return 0.0;

    final ratio = 1.0 - (distance / maxLen);
    return (ratio * 0.70).clamp(0.0, 1.0);
  }

  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }
}
