import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/semantic_search/domain/services/similarity_ranking_engine.dart';

/// Gate 6: SemanticValidator
/// Computes distinctiveness between correct answer and distractors to prevent duplicates or trivial options.
class SemanticValidator implements TruthGateValidator {
  final SimilarityRankingEngine _rankingEngine;

  SemanticValidator({SimilarityRankingEngine? rankingEngine})
      : _rankingEngine = rankingEngine ?? SimilarityRankingEngine();

  @override
  String get gateId => 'gate_6_semantic';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    final answer = candidate.answerKey.trim().toLowerCase();

    if (candidate.distractors.isEmpty) {
      return GateResult.fail(gateId, 'Nenhum distrator foi fornecido.');
    }

    final seen = <String>{};
    for (final distractor in candidate.distractors) {
      final cleanD = distractor.trim().toLowerCase();

      // Check duplicate distractor
      if (cleanD == answer) {
        return GateResult.fail(
          gateId,
          'Distrator idêntico à resposta correta: "$distractor".',
        );
      }

      if (seen.contains(cleanD)) {
        return GateResult.fail(
          gateId,
          'Distratores duplicados detectados: "$distractor".',
        );
      }
      seen.add(cleanD);

      // Check text similarity: if too close (> 0.95), distractor is likely a typo of the answer
      final similarity = _rankingEngine.computeTextScore(answer, cleanD);
      if (similarity > 0.95) {
        return GateResult.fail(
          gateId,
          'Distrator "$distractor" excessivamente semelhante à resposta correta ($similarity), causando ambiguidade.',
        );
      }
    }

    return GateResult.pass(gateId);
  }
}
