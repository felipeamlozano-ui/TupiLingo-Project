/// Contract for audit logging and retrieval of Truth Layer validation events.
abstract class TruthRepository {
  /// Records an audit log for a validation event.
  Future<void> logValidation({
    required String candidateHash,
    int? variantId,
    required bool isPass,
    String? failedGate,
    String? failureReason,
    double? groundingConfidence,
  });

  /// Stores an authenticated claim in the canonical truth repository.
  Future<void> storeClaim({
    required String claimText,
    int? variantId,
    required String sourceType,
    String? sourceId,
    double confidence = 1.0,
  });
}
