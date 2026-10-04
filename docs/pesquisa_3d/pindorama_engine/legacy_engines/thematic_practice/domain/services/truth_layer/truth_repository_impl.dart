import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_repository.dart';

/// Implementation of TruthRepository writing to Supabase `truth_validation_log` and `truth_repository`.
class TruthRepositoryImpl implements TruthRepository {
  final SupabaseClient? _supabase;
  final List<Map<String, dynamic>> _inMemoryAuditLog = [];

  TruthRepositoryImpl([this._supabase]);

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get inMemoryLogs => List.unmodifiable(_inMemoryAuditLog);

  @override
  Future<void> logValidation({
    required String candidateHash,
    int? variantId,
    required bool isPass,
    String? failedGate,
    String? failureReason,
    double? groundingConfidence,
  }) async {
    final entry = {
      'question_candidate_hash': candidateHash,
      'variante_id': variantId,
      'validation_result': isPass ? 'pass' : 'fail',
      'failed_gate': failedGate,
      'failure_reason': failureReason,
      'grounding_confidence': groundingConfidence,
      'validated_at': DateTime.now().toIso8601String(),
    };

    _inMemoryAuditLog.add(entry);

    final client = _client;
    if (client == null) return;

    try {
      await client.from('truth_validation_log').insert(entry);
    } catch (_) {
      // Best-effort audit logging
    }
  }

  @override
  Future<void> storeClaim({
    required String claimText,
    int? variantId,
    required String sourceType,
    String? sourceId,
    double confidence = 1.0,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('truth_repository').insert({
        'claim_text': claimText,
        'variante_id': variantId,
        'grounding_source_type': sourceType,
        'grounding_source_id': sourceId,
        'confidence': confidence,
      });
    } catch (_) {}
  }
}
