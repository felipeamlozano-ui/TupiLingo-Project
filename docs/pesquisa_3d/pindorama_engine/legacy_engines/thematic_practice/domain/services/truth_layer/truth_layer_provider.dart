import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_layer_orchestrator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_repository.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_repository_impl.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';

/// Truth repository singleton provider.
final truthRepositoryProvider = Provider<TruthRepository>((ref) {
  return TruthRepositoryImpl();
});

/// Truth Layer Orchestrator provider.
final truthLayerOrchestratorProvider = Provider<TruthLayerOrchestrator>((ref) {
  final repo = ref.watch(truthRepositoryProvider);
  return TruthLayerOrchestrator(repository: repo);
});

/// Future provider to validate a candidate question through the Truth Layer.
final validateQuestionCandidateProvider =
    FutureProvider.family<TruthValidationSummary, TruthQuestionCandidate>((ref, candidate) async {
  final orchestrator = ref.watch(truthLayerOrchestratorProvider);
  return orchestrator.validateQuestion(candidate);
});
