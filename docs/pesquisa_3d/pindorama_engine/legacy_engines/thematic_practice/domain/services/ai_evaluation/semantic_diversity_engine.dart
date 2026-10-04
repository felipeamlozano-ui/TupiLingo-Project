import 'dart:math';

/// Semantic Diversity Engine ensuring varied cluster distribution in practice sessions (ADR-020).
class SemanticDiversityEngine {
  static const double maxClusterConcentration = 0.40; // Max 40% per cluster

  /// Checks whether adding [candidateCluster] violates the maximum 40% concentration limit.
  bool canIncludeCluster(List<String> currentSessionClusters, String candidateCluster) {
    if (currentSessionClusters.isEmpty) return true;

    final total = currentSessionClusters.length + 1;
    final count = currentSessionClusters.where((c) => c == candidateCluster).length + 1;

    return (count / total) <= maxClusterConcentration;
  }

  /// Computes Shannon entropy of the session cluster distribution:
  /// $H(X) = -\sum P(x) \log_2 P(x)$
  double computeEntropy(List<String> sessionClusters) {
    if (sessionClusters.isEmpty) return 0.0;

    final counts = <String, int>{};
    for (final c in sessionClusters) {
      counts[c] = (counts[c] ?? 0) + 1;
    }

    final total = sessionClusters.length;
    double entropy = 0.0;

    for (final count in counts.values) {
      final p = count / total;
      entropy -= p * (log(p) / ln2);
    }

    return entropy;
  }
}
