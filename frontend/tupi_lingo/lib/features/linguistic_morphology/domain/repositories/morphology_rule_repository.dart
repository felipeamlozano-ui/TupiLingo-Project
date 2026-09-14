import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_family.dart';

/// Contract for accessing morphology rules and precomputed analyses.
abstract class MorphologyRuleRepository {
  /// Fetches all morphological rules for a given variant (or all if variantId is null).
  Future<List<MorphologicalRule>> getRules({int? variantId});

  /// Finds precomputed analysis for a word if available.
  Future<MorphologicalAnalysis?> getAnalysis(String wordLabel, {int? variantId});

  /// Saves a morphological analysis to local/remote cache.
  Future<void> saveAnalysis(MorphologicalAnalysis analysis);

  /// Gets all words in a morphological family given a root surface.
  Future<MorphologicalFamily?> getFamily(String rootSurface, {int? variantId});

  /// Synchronizes morphology rules from remote Supabase database.
  Future<void> syncRules({int? variantId});
}
