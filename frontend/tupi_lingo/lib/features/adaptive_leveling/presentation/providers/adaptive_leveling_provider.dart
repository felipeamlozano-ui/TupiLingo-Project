import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/repositories/adaptive_leveling_repository.dart';
import 'package:tupi_lingo/features/adaptive_leveling/data/repositories/adaptive_leveling_repository_impl.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/services/knowledge_tracing_engine.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/services/difficulty_planner.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/policies/mastery_transition_policy.dart';

final adaptiveLevelingRepositoryProvider = Provider<AdaptiveLevelingRepository>((ref) {
  return AdaptiveLevelingRepositoryImpl();
});

final knowledgeTracingEngineProvider = Provider<KnowledgeTracingEngine>((ref) {
  return const KnowledgeTracingEngine();
});

final difficultyPlannerProvider = Provider<DifficultyPlanner>((ref) {
  return DifficultyPlanner();
});

final masteryTransitionPolicyProvider = Provider<MasteryTransitionPolicy>((ref) {
  return MasteryTransitionPolicy();
});

/// AsyncNotifier for the user's CognitiveProfile scoped by variantId.
class CognitiveProfileNotifier extends AsyncNotifier<CognitiveProfile> {
  final String userId;
  final int variantId;

  CognitiveProfileNotifier({required this.userId, required this.variantId});

  @override
  Future<CognitiveProfile> build() async {
    final repo = ref.read(adaptiveLevelingRepositoryProvider);
    return repo.getCognitiveProfile(userId: userId, variantId: variantId);
  }

  Future<void> recordResponse({
    required String nodeId,
    required String dimension, // 'vocabulary', 'grammar', 'reading', etc.
    required bool isCorrect,
    double? latencySeconds,
  }) async {
    final profile = state.value;
    if (profile == null) return;

    final bkt = ref.read(knowledgeTracingEngineProvider);
    final repo = ref.read(adaptiveLevelingRepositoryProvider);
    final policy = ref.read(masteryTransitionPolicyProvider);

    // 1. Fetch or create node knowledge state
    final existing = await repo.getKnowledgeState(userId: userId, nodeId: nodeId) ??
        KnowledgeState(nodeId: nodeId, lastReviewedAt: DateTime.now());

    // 2. Compute new posterior with BKT
    final newPosterior = bkt.updatePosterior(
      priorL: existing.pMastery,
      isCorrect: isCorrect,
    );

    final newStreak = isCorrect ? existing.consecutiveStreak + 1 : 0;
    final newState = bkt.evaluateTransition(
      currentState: existing.state,
      pMastery: newPosterior,
      exposures: existing.totalExposures + 1,
      consecutiveStreak: newStreak,
    );

    final newHalfLife = policy.computeNewHalfLife(
      currentHalfLife: existing.halfLifeDays,
      isCorrect: isCorrect,
      pMastery: newPosterior,
    );

    final updatedKnowledge = existing.copyWith(
      state: newState,
      pMastery: newPosterior,
      totalExposures: existing.totalExposures + 1,
      correctResponses: existing.correctResponses + (isCorrect ? 1 : 0),
      consecutiveStreak: newStreak,
      lastReviewedAt: DateTime.now(),
      halfLifeDays: newHalfLife,
    );

    await repo.saveKnowledgeState(userId: userId, state: updatedKnowledge);

    // 3. Update dimension mastery in CognitiveProfile
    final delta = isCorrect ? 0.04 : -0.02;
    double newVocab = profile.vocabulary;
    double newGrammar = profile.grammar;
    double newCultural = profile.cultural;
    double newMorph = profile.morphology;
    double newReading = profile.reading;

    switch (dimension) {
      case 'grammar':
        newGrammar = (newGrammar + delta).clamp(0.0, 1.0);
        break;
      case 'cultural':
      case 'mythology':
        newCultural = (newCultural + delta).clamp(0.0, 1.0);
        break;
      case 'morphology':
        newMorph = (newMorph + delta).clamp(0.0, 1.0);
        break;
      case 'reading':
        newReading = (newReading + delta).clamp(0.0, 1.0);
        break;
      case 'vocabulary':
      default:
        newVocab = (newVocab + delta).clamp(0.0, 1.0);
        break;
    }

    final updatedProfile = profile.copyWith(
      vocabulary: newVocab,
      grammar: newGrammar,
      cultural: newCultural,
      morphology: newMorph,
      reading: newReading,
      updatedAt: DateTime.now(),
    );

    await repo.saveCognitiveProfile(updatedProfile);
    state = AsyncValue.data(updatedProfile);
  }
}

final cognitiveProfileNotifierProvider =
    AsyncNotifierProvider.family<CognitiveProfileNotifier, CognitiveProfile, ({String userId, int variantId})>(
  (arg) => CognitiveProfileNotifier(userId: arg.userId, variantId: arg.variantId),
);
