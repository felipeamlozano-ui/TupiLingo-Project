import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gate_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/lexical_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/grammar_guard.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/morphology_guard.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/variant_guard.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/grounding_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/gates/semantic_validator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_repository.dart';

/// Comprehensive validation summary emitted by TruthLayerOrchestrator.
@immutable
class TruthValidationSummary {
  final bool isPass;
  final String? failedGate;
  final String? failureReason;
  final double confidence;
  final List<String> passedGates;

  const TruthValidationSummary({
    required this.isPass,
    this.failedGate,
    this.failureReason,
    this.confidence = 1.0,
    required this.passedGates,
  });

  factory TruthValidationSummary.pass(List<String> passedGates, [double confidence = 1.0]) {
    return TruthValidationSummary(
      isPass: true,
      passedGates: passedGates,
      confidence: confidence,
    );
  }

  factory TruthValidationSummary.fail({
    required String failedGate,
    required String reason,
    required List<String> passedGates,
    double confidence = 0.95,
  }) {
    return TruthValidationSummary(
      isPass: false,
      failedGate: failedGate,
      failureReason: reason,
      confidence: confidence,
      passedGates: passedGates,
    );
  }
}

/// Orchestrator running candidate questions through all 6 sequential validation gates.
class TruthLayerOrchestrator {
  final List<TruthGateValidator> _gates;
  final TruthRepository? repository;

  TruthLayerOrchestrator({
    List<TruthGateValidator>? gates,
    this.repository,
  }) : _gates = gates ?? _defaultGates;

  static List<TruthGateValidator> get _defaultGates => [
        LexicalValidator(),
        GrammarGuard(),
        MorphologyGuard(),
        VariantGuard(),
        GroundingValidator(),
        SemanticValidator(),
      ];

  /// Sequentially executes all gates. Halts and logs immediately upon first failure (fail-fast).
  Future<TruthValidationSummary> validateQuestion(TruthQuestionCandidate candidate) async {
    final List<String> passedGates = [];

    for (final gate in _gates) {
      final result = await gate.validate(candidate);
      if (!result.isPass) {
        final summary = TruthValidationSummary.fail(
          failedGate: gate.gateId,
          reason: result.failureReason ?? 'Validação reprovada.',
          passedGates: passedGates,
          confidence: result.confidence,
        );

        // Asynchronously log audit event
        if (repository != null) {
          repository!.logValidation(
            candidateHash: candidate.questionHash,
            variantId: candidate.variantId,
            isPass: false,
            failedGate: gate.gateId,
            failureReason: result.failureReason,
            groundingConfidence: result.confidence,
          );
        }

        return summary;
      }
      passedGates.add(gate.gateId);
    }

    final summary = TruthValidationSummary.pass(passedGates, 1.0);

    // Asynchronously log audit success
    if (repository != null) {
      repository!.logValidation(
        candidateHash: candidate.questionHash,
        variantId: candidate.variantId,
        isPass: true,
        groundingConfidence: 1.0,
      );
    }

    return summary;
  }
}
