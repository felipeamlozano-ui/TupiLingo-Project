import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';

/// Gate 4: VariantGuard
/// Ensures zero cross-variant contamination (e.g. Guarani terms leaking into Old Tupi lessons).
class VariantGuard implements TruthGateValidator {
  // Known cross-variant false cognates / dialect-specific markers
  static final Map<int, List<String>> _prohibitedTermsPerVariant = {
    // Old Tupi (id: 1) prohibits modern Nheengatu loanwords or Guarani modernisms
    1: ['puranga', 'reko', 'nhanduti', 'tapejhá'],
  };

  @override
  String get gateId => 'gate_4_variant';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    final vId = candidate.variantId ?? 1;
    final prohibited = _prohibitedTermsPerVariant[vId];
    if (prohibited == null || prohibited.isEmpty) {
      return GateResult.pass(gateId);
    }

    final combinedText = '${candidate.questionText} ${candidate.answerKey} ${candidate.distractors.join(" ")}'.toLowerCase();

    for (final term in prohibited) {
      if (combinedText.contains(term.toLowerCase())) {
        return GateResult.fail(
          gateId,
          'Contaminação entre variantes detectada: o termo "$term" pertence a outro dialeto/ramo e é proibido na variante $vId.',
        );
      }
    }

    return GateResult.pass(gateId);
  }
}
