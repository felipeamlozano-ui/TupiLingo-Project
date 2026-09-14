import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';

/// Estimates the structural complexity of a Tupi word for adaptive difficulty planning.
class MorphologicalDifficultyEstimator {
  /// Returns a difficulty score in range [0.0, 1.0].
  /// 0.0 = Simple bare root (e.g. oka, abá)
  /// 0.5 = Root + standard suffix (e.g. oka-gûasu)
  /// 1.0 = Highly compounded word with prefixes + suffixes + relational mutations
  double estimateDifficulty(MorphologicalAnalysis analysis) {
    if (analysis.morphemes.isEmpty) return 0.1;

    double score = 0.1;

    // Penalty for affix depth
    score += analysis.prefixes.length * 0.25;
    score += analysis.suffixes.length * 0.20;

    // Penalty for word length
    if (analysis.wordLabel.length > 8) {
      score += 0.15;
    }
    if (analysis.wordLabel.length > 12) {
      score += 0.20;
    }

    // Cap score at 1.0
    return score.clamp(0.0, 1.0);
  }
}
