import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/semantic_search/data/datasources/search_local_index.dart';

/// Gate 1: LexicalValidator
/// Verifies that words in [answerKey] exist in the canonical lexicon / KG.
class LexicalValidator implements TruthGateValidator {
  final SearchLocalIndex _localIndex;

  LexicalValidator({SearchLocalIndex? localIndex})
      : _localIndex = localIndex ?? SearchLocalIndex();

  @override
  String get gateId => 'gate_1_lexical';

  @override
  Future<GateResult> validate(TruthQuestionCandidate candidate) async {
    final answer = candidate.answerKey.trim().toLowerCase();
    if (answer.isEmpty) {
      return GateResult.fail(gateId, 'Chave de resposta está vazia.');
    }

    final catalog = _localIndex.getCatalog(variantId: candidate.variantId);
    final exists = catalog.any((item) =>
        item.wordLabel.toLowerCase() == answer ||
        item.translationPt.toLowerCase().contains(answer) ||
        answer.contains(item.wordLabel.toLowerCase()));

    if (!exists) {
      return GateResult.fail(
        gateId,
        'O termo "$answer" não foi atestado no acervo léxico canônico ou no Knowledge Graph para esta variante.',
      );
    }

    return GateResult.pass(gateId);
  }
}
