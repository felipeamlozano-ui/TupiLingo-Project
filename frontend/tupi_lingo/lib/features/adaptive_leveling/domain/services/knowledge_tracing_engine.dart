import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';

/// Bayesian Knowledge Tracing (BKT) Engine for deterministic real-time tracking (RFC-012A Chapter 6).
class KnowledgeTracingEngine {
  // Default Bayesian Knowledge Tracing priors calibrated for indigenous language acquisition
  final double defaultPInit;  // P(L_0) = 0.15
  final double defaultPTransit; // P(T) = 0.25
  final double defaultPGuess;   // P(G) = 0.20
  final double defaultPSlip;    // P(S) = 0.10

  const KnowledgeTracingEngine({
    this.defaultPInit = 0.15,
    this.defaultPTransit = 0.25,
    this.defaultPGuess = 0.20,
    this.defaultPSlip = 0.10,
  });

  /// Computes the posterior mastery probability $P(L_{t+1})$ after observing a response.
  double updatePosterior({
    required double priorL,
    required bool isCorrect,
    double? pGuess,
    double? pSlip,
    double? pTransit,
  }) {
    final g = pGuess ?? defaultPGuess;
    final s = pSlip ?? defaultPSlip;
    final t = pTransit ?? defaultPTransit;

    final pL = priorL.clamp(0.001, 0.999);

    double pObservationGivenL;
    if (isCorrect) {
      // P(L_t | Correct) = (P(L_{t-1}) * (1 - S)) / (P(L_{t-1}) * (1 - S) + (1 - P(L_{t-1})) * G)
      final numerator = pL * (1.0 - s);
      final denominator = numerator + ((1.0 - pL) * g);
      pObservationGivenL = numerator / denominator;
    } else {
      // P(L_t | Incorrect) = (P(L_{t-1}) * S) / (P(L_{t-1}) * S + (1 - P(L_{t-1})) * (1 - G))
      final numerator = pL * s;
      final denominator = numerator + ((1.0 - pL) * (1.0 - g));
      pObservationGivenL = numerator / denominator;
    }

    // Step 2: Learning transition update for next interaction opportunity:
    // P(L_{t+1}) = P(L_t | obs) + (1 - P(L_t | obs)) * P(T)
    final nextPosterior = pObservationGivenL + ((1.0 - pObservationGivenL) * t);

    return nextPosterior.clamp(0.0, 1.0);
  }

  /// Evaluates state machine transition according to BKT thresholds and streaks.
  KnowledgeStateType evaluateTransition({
    required KnowledgeStateType currentState,
    required double pMastery,
    required int exposures,
    required int consecutiveStreak,
  }) {
    if (exposures == 0) return KnowledgeStateType.unknown;

    if (pMastery >= 0.85 && exposures >= 3 && consecutiveStreak >= 2) {
      return KnowledgeStateType.mastered;
    } else if (pMastery >= 0.65) {
      return KnowledgeStateType.retained;
    } else if (pMastery >= 0.40) {
      return KnowledgeStateType.learning;
    } else if (pMastery >= 0.20 || exposures >= 1) {
      return KnowledgeStateType.recognized;
    }

    return KnowledgeStateType.exposed;
  }
}
