import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_validator.dart';

/// Gate 2: GrammarGuard
/// Verifies that grammatical and morphological structure is permissible per academic rules.
class GrammarGuard implements TruthGateValidator {
  final MorphologyValidator _morphologyValidator;

  GrammarGuard({MorphologyValidator? morphologyValidator})
      : _morphologyValidator = morphologyValidator ?? MorphologyValidator();

  @override
  String get gateId => 'gate_2_grammar';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    // Check correct answer and each distractor
    final wordsToCheck = [candidate.answerKey, ...candidate.distractors];

    for (final word in wordsToCheck) {
      final tokens = word.split(RegExp(r'\s+'));
      for (final token in tokens) {
        final clean = token.replaceAll(RegExp(r"[^\w\u00C0-\u017F\-'~^]"), '').trim();
        if (clean.isEmpty) continue;

        final validation = _morphologyValidator.isValidStructure(
          clean,
          variantId: candidate.variantId,
        );

        if (!validation.isValid) {
          return GateResult.fail(
            gateId,
            'Estrutura gramatical/morfológica inválida para "$clean": ${validation.reason}',
            validation.confidence,
          );
        }
      }
    }

    return GateResult.pass(gateId);
  }
}
