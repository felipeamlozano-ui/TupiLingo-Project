import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_family.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/repositories/morphology_rule_repository.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_validator.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_explanation_engine.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_similarity_engine.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphological_difficulty_estimator.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_generator.dart';
import 'package:tupi_lingo/features/linguistic_morphology/data/repositories/morphology_rule_repository_impl.dart';

/// Morphology Rule Repository singleton provider.
final morphologyRepositoryProvider = Provider<MorphologyRuleRepository>((ref) {
  return MorphologyRuleRepositoryImpl();
});

/// Morphology Parser provider.
final morphologyParserProvider = Provider<MorphologyParser>((ref) {
  return MorphologyParser();
});

/// Morphology Validator provider.
final morphologyValidatorProvider = Provider<MorphologyValidator>((ref) {
  final parser = ref.watch(morphologyParserProvider);
  return MorphologyValidator(parser: parser);
});

/// Morphology Explanation Engine provider.
final morphologyExplanationEngineProvider = Provider<MorphologyExplanationEngine>((ref) {
  final parser = ref.watch(morphologyParserProvider);
  return MorphologyExplanationEngine(parser: parser);
});

/// Morphology Similarity Engine provider.
final morphologySimilarityEngineProvider = Provider<MorphologySimilarityEngine>((ref) {
  final parser = ref.watch(morphologyParserProvider);
  return MorphologySimilarityEngine(parser: parser);
});

/// Morphological Difficulty Estimator provider.
final morphologicalDifficultyEstimatorProvider = Provider<MorphologicalDifficultyEstimator>((ref) {
  return MorphologicalDifficultyEstimator();
});

/// Morphology Generator provider.
final morphologyGeneratorProvider = Provider<MorphologyGenerator>((ref) {
  return MorphologyGenerator();
});

/// Future provider to parse and retrieve morphological analysis for a given word.
final wordMorphologyAnalysisProvider =
    FutureProvider.family<MorphologicalAnalysis, String>((ref, word) async {
  final repo = ref.watch(morphologyRepositoryProvider);
  final cached = await repo.getAnalysis(word);
  if (cached != null) return cached;

  final parser = ref.watch(morphologyParserProvider);
  final analysis = parser.parse(word);
  await repo.saveAnalysis(analysis);
  return analysis;
});

/// Future provider to fetch a morphological family for a root.
final morphologicalFamilyProvider =
    FutureProvider.family<MorphologicalFamily?, String>((ref, root) async {
  final repo = ref.watch(morphologyRepositoryProvider);
  return repo.getFamily(root);
});
