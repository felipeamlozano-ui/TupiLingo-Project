import 'dart:math';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/difficulty_target.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';

/// Item Response Theory (TRI 3PL) Planner and Adaptive Difficulty Optimizer (RFC-012A Chapter 7).
class DifficultyPlanner {
  /// Computes the probability of correct response under TRI 3PL model:
  /// $P(\theta) = c + \frac{1 - c}{1 + e^{-1.7 \cdot a \cdot (\theta - b)}}$
  double computeProbability({
    required double theta,
    required double difficultyB,
    double discriminationA = 1.0,
    double pseudoGuessingC = 0.20,
  }) {
    final expArg = -1.7 * discriminationA * (theta - difficultyB);
    final clampedArg = expArg.clamp(-20.0, 20.0);
    final logistic = 1.0 / (1.0 + exp(clampedArg));
    return pseudoGuessingC + ((1.0 - pseudoGuessingC) * logistic);
  }

  /// Calculates target difficulty range for a session given a cognitive profile and goal.
  DifficultyTarget computeTargetDifficulty(CognitiveProfile profile, {String sessionGoal = 'adaptive'}) {
    // Overall proficiency theta mapped to standard score [-2.5, +2.5]
    final theta = (profile.overallMastery - 0.5) * 4.0;
    return DifficultyTarget.fromTheta(theta, sessionGoal: sessionGoal);
  }

  /// Scores candidate item suitability for the user based on target probability of success (target 75%).
  double scoreItemSuitability({
    required double theta,
    required double itemDifficultyB,
    double itemDiscriminationA = 1.0,
    double targetSuccessProb = 0.75,
  }) {
    final p = computeProbability(
      theta: theta,
      difficultyB: itemDifficultyB,
      discriminationA: itemDiscriminationA,
    );

    // Closer to target success rate is better (Zone of Proximal Development)
    final distance = (p - targetSuccessProb).abs();
    return (1.0 - distance).clamp(0.0, 1.0);
  }
}
