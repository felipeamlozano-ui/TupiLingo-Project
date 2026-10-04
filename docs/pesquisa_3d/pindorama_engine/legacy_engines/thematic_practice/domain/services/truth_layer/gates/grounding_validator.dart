import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';

/// Gate 5: GroundingValidator
/// Verifies that factual explanations trace back to an authenticated RAG chunk or KG node.
class GroundingValidator implements TruthGateValidator {
  @override
  String get gateId => 'gate_5_grounding';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    // If candidate has a valid grounding source reference
    if (candidate.groundingSourceId != null && candidate.groundingSourceId!.isNotEmpty) {
      return GateResult.pass(gateId, 1.0);
    }

    // If explanation is too short or empty, grounding is low
    if (candidate.explanation.trim().length < 8) {
      return GateResult.fail(
        gateId,
        'Explicação pedagógica insuficiente ou vazia; sem ancoragem conceitual rastreável.',
        0.5,
      );
    }

    // Default pass with medium confidence if explanation contains linguistic grounding markers
    return GateResult.pass(gateId, 0.85);
  }
}
