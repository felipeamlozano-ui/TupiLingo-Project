import 'dart:math';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';

/// Policy governing mastery state promotions and temporal memory decay (RFC-012A Chapter 8).
class MasteryTransitionPolicy {
  /// Evaluates whether a state has decayed over time according to Ebbinghaus forgetting curve.
  KnowledgeState checkTemporalDecay(KnowledgeState current, DateTime now) {
    if (current.state == KnowledgeStateType.unknown || current.state == KnowledgeStateType.forgotten) {
      return current;
    }

    final elapsedDays = now.difference(current.lastReviewedAt).inHours / 24.0;
    if (elapsedDays <= current.halfLifeDays) {
      return current; // Still within stability window
    }

    // Retrievability: $R = 2^{- \frac{\Delta t}{S}}$
    final retrievability = pow(2.0, -elapsedDays / current.halfLifeDays).toDouble();

    if (retrievability < 0.35) {
      return current.copyWith(
        state: KnowledgeStateType.forgotten,
        pMastery: (current.pMastery * 0.60).clamp(0.10, 1.0),
      );
    } else if (retrievability < 0.65 && current.state == KnowledgeStateType.mastered) {
      return current.copyWith(
        state: KnowledgeStateType.decaying,
      );
    }

    return current;
  }

  /// Calculates updated half-life in days following a successful or failed review.
  double computeNewHalfLife({
    required double currentHalfLife,
    required bool isCorrect,
    required double pMastery,
  }) {
    if (isCorrect) {
      // Exponential stability growth on correct recall
      final growthFactor = 1.0 + (pMastery * 1.5);
      return (currentHalfLife * growthFactor).clamp(1.0, 365.0);
    } else {
      // Half-life contraction on lapse
      return max(1.0, currentHalfLife * 0.5);
    }
  }
}
