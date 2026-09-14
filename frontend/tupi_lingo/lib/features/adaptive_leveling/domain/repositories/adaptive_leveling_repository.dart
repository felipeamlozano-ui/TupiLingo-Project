import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';

/// Contract for Adaptive Leveling and Cognitive Profile persistence.
abstract class AdaptiveLevelingRepository {
  Future<CognitiveProfile> getCognitiveProfile({required String userId, required int variantId});
  Future<void> saveCognitiveProfile(CognitiveProfile profile);
  Future<KnowledgeState?> getKnowledgeState({required String userId, required String nodeId});
  Future<void> saveKnowledgeState({required String userId, required KnowledgeState state});
  Future<List<KnowledgeState>> getDecayingKnowledgeStates({required String userId, required int variantId});
}
