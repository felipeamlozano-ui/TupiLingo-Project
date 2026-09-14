import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';

/// Gate 3: MorphologyGuard
/// Verifies that any morpheme decomposition cited in the explanation is internally consistent with parser output.
class MorphologyGuard implements TruthGateValidator {
  final MorphologyParser _parser;

  MorphologyGuard({MorphologyParser? parser})
      : _parser = parser ?? MorphologyParser();

  @override
  String get gateId => 'gate_3_morphology';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    final cleanAnswer = candidate.answerKey.trim().toLowerCase();
    final analysis = _parser.parse(cleanAnswer, variantId: candidate.variantId);

    // If explanation mentions morphemes or roots, ensure the root is accurately named
    final explanationLower = candidate.explanation.toLowerCase();
    if (explanationLower.contains('raiz') || explanationLower.contains('radical')) {
      if (analysis.rootSurface.isNotEmpty && !explanationLower.contains(analysis.rootSurface.toLowerCase())) {
        return GateResult.fail(
          gateId,
          'A explicação cita uma raiz incoerente com o parsing morfológico atestado ("${analysis.rootSurface}").',
        );
      }
    }

    return GateResult.pass(gateId);
  }
}
