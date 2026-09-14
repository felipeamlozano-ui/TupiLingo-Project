import 'package:flutter/foundation.dart';

/// Target difficulty calibration parameters based on Item Response Theory (TRI 3PL).
@immutable
class DifficultyTarget {
  final double targetTheta; // Learner proficiency estimate [-3.0, +3.0]
  final double standardError;
  final double minDifficultyB;
  final double maxDifficultyB;
  final double targetDiscriminationA;
  final String sessionGoal; // 'reinforce', 'challenge', 'adaptive', 'review'

  const DifficultyTarget({
    required this.targetTheta,
    this.standardError = 0.35,
    this.minDifficultyB = -1.5,
    this.maxDifficultyB = 1.5,
    this.targetDiscriminationA = 1.2,
    this.sessionGoal = 'adaptive',
  });

  /// Factory creating an adaptive difficulty range matching learner proficiency theta.
  factory DifficultyTarget.fromTheta(double theta, {String sessionGoal = 'adaptive'}) {
    // Dynamic difficulty window centered around theta
    final delta = sessionGoal == 'challenge' ? 0.6 : (sessionGoal == 'reinforce' ? -0.4 : 0.2);
    return DifficultyTarget(
      targetTheta: theta,
      minDifficultyB: theta + delta - 0.5,
      maxDifficultyB: theta + delta + 0.5,
      sessionGoal: sessionGoal,
    );
  }
}
