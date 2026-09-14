import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/repositories/adaptive_leveling_repository.dart';

/// In-memory and local cache implementation of AdaptiveLevelingRepository.
class AdaptiveLevelingRepositoryImpl implements AdaptiveLevelingRepository {
  final Map<String, CognitiveProfile> _profileCache = {};
  final Map<String, KnowledgeState> _stateCache = {};

  @override
  Future<CognitiveProfile> getCognitiveProfile({required String userId, required int variantId}) async {
    final key = '${userId}_v$variantId';
    if (!_profileCache.containsKey(key)) {
      _profileCache[key] = CognitiveProfile.initial(userId: userId, variantId: variantId);
    }
    return _profileCache[key]!;
  }

  @override
  Future<void> saveCognitiveProfile(CognitiveProfile profile) async {
    final key = '${profile.userId}_v${profile.variantId}';
    _profileCache[key] = profile;
  }

  @override
  Future<KnowledgeState?> getKnowledgeState({required String userId, required String nodeId}) async {
    final key = '${userId}_node_$nodeId';
    return _stateCache[key];
  }

  @override
  Future<void> saveKnowledgeState({required String userId, required KnowledgeState state}) async {
    final key = '${userId}_node_${state.nodeId}';
    _stateCache[key] = state;
  }

  @override
  Future<List<KnowledgeState>> getDecayingKnowledgeStates({required String userId, required int variantId}) async {
    return _stateCache.values
        .where((s) => s.state == KnowledgeStateType.decaying || s.state == KnowledgeStateType.forgotten)
        .toList();
  }
}
