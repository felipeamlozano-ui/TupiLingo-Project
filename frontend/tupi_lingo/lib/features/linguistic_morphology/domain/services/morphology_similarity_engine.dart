import 'dart:math';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';

/// Calculates structural and morphological similarity between two Tupi words.
class MorphologySimilarityEngine {
  final MorphologyParser _parser;

  MorphologySimilarityEngine({MorphologyParser? parser})
      : _parser = parser ?? MorphologyParser();

  /// Computes morphological similarity in range [0.0, 1.0].
  /// 1.0 = Same root and same affixes
  /// >= 0.7 = Shared root (same morphological family)
  /// < 0.3 = Unrelated roots and affixes
  double calculateSimilarity(String wordA, String wordB, {int? variantId}) {
    if (wordA.trim().toLowerCase() == wordB.trim().toLowerCase()) return 1.0;

    final analysisA = _parser.parse(wordA, variantId: variantId);
    final analysisB = _parser.parse(wordB, variantId: variantId);

    return calculateAnalysisSimilarity(analysisA, analysisB);
  }

  double calculateAnalysisSimilarity(
    MorphologicalAnalysis a,
    MorphologicalAnalysis b,
  ) {
    // If roots match, high base similarity
    if (a.rootSurface.isNotEmpty && a.rootSurface == b.rootSurface) {
      double score = 0.70;

      // Check shared affixes
      final affixesA = a.morphemes.where((m) => m.surface != a.rootSurface).map((m) => m.surface).toSet();
      final affixesB = b.morphemes.where((m) => m.surface != b.rootSurface).map((m) => m.surface).toSet();

      if (affixesA.isNotEmpty && affixesB.isNotEmpty) {
        final intersection = affixesA.intersection(affixesB).length;
        final union = affixesA.union(affixesB).length;
        score += 0.30 * (intersection / union);
      } else if (affixesA.isEmpty && affixesB.isEmpty) {
        score = 1.0;
      }
      return score.clamp(0.0, 1.0);
    }

    // Levenshtein ratio on root as fallback
    final rootDistance = _levenshteinDistance(a.rootSurface, b.rootSurface);
    final maxLen = max(a.rootSurface.length, b.rootSurface.length);
    if (maxLen == 0) return 0.0;

    final ratio = 1.0 - (rootDistance / maxLen);
    return (ratio * 0.40).clamp(0.0, 1.0);
  }

  int _levenshteinDistance(String s1, String s2) {
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
