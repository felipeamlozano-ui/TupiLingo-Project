import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';

/// Result emitted by an individual Truth Layer gate.
class GateResult {
  final bool isPass;
  final String gateId;
  final String? failureReason;
  final double confidence;

  const GateResult({
    required this.isPass,
    required this.gateId,
    this.failureReason,
    this.confidence = 1.0,
  });

  static GateResult pass(String gateId, [double confidence = 1.0]) {
    return GateResult(isPass: true, gateId: gateId, confidence: confidence);
  }

  static GateResult fail(String gateId, String reason, [double confidence = 0.95]) {
    return GateResult(isPass: false, gateId: gateId, failureReason: reason, confidence: confidence);
  }
}

/// Abstract contract for sequential Truth Layer validation gates.
abstract class TruthGateValidator {
  String get gateId;

  /// Validates candidate question. Returns [GateResult.pass] or [GateResult.fail].
  Future<GateResult> validate(TruthQuestionCandidate candidate);
}
