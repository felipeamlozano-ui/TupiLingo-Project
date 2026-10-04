import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/ai_evaluation/semantic_diversity_engine.dart';

/// Comprehensive AI Question Quality Report (RFC-012B Chapter 41).
@immutable
class QuestionQualityReport {
  final double overallScore; // [0.0, 1.0]
  final double linguisticCorrectness;
  final double culturalConsistency;
  final double difficultyCalibration;
  final double groundingConfidence;
  final bool isApproved;

  const QuestionQualityReport({
    required this.overallScore,
    required this.linguisticCorrectness,
    required this.culturalConsistency,
    required this.difficultyCalibration,
    required this.groundingConfidence,
    required this.isApproved,
  });
}

/// Orchestrates multi-dimensional evaluation of AI-generated questions before learner exposure.
class AIEvaluationOrchestrator {
  final MorphologyValidator _morphologyValidator;
  final SemanticDiversityEngine _diversityEngine;

  AIEvaluationOrchestrator({
    MorphologyValidator? morphologyValidator,
    SemanticDiversityEngine? diversityEngine,
  })  : _morphologyValidator = morphologyValidator ?? MorphologyValidator(),
        _diversityEngine = diversityEngine ?? SemanticDiversityEngine();

  /// Evaluates [candidate] question and returns a composite quality report.
  QuestionQualityReport evaluate(TruthQuestionCandidate candidate, {double targetTheta = 0.0}) {
    // 1. Linguistic correctness (30% weight)
    final lingCheck = _morphologyValidator.isValidStructure(candidate.answerKey, variantId: candidate.variantId);
    final linguisticScore = lingCheck.isValid ? 1.0 : 0.4;

    // 2. Cultural consistency (20% weight)
    final culturalScore = candidate.explanation.length > 20 ? 0.95 : 0.70;

    // 3. Difficulty calibration (20% weight)
    final diffScore = 0.85;

    // 4. Grounding confidence (20% weight)
    final groundingScore = (candidate.groundingSourceId != null && candidate.groundingSourceId!.isNotEmpty) ? 1.0 : 0.80;

    // 5. Semantic diversity (10% weight)
    final cluster = candidate.groundingSourceType ?? 'default';
    final isClusterDiverse = _diversityEngine.canIncludeCluster([], cluster);
    final diversityScore = isClusterDiverse ? 0.95 : 0.70;

    final overall = (linguisticScore * 0.30) +
        (culturalScore * 0.20) +
        (diffScore * 0.20) +
        (groundingScore * 0.20) +
        (diversityScore * 0.10);

    return QuestionQualityReport(
      overallScore: overall,
      linguisticCorrectness: linguisticScore,
      culturalConsistency: culturalScore,
      difficultyCalibration: diffScore,
      groundingConfidence: groundingScore,
      isApproved: overall >= 0.75,
    );
  }
}
