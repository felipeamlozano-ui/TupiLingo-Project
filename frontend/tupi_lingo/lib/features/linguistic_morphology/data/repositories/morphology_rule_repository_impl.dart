import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_family.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/repositories/morphology_rule_repository.dart';
import 'package:tupi_lingo/features/linguistic_morphology/data/datasources/morphology_rule_local_datasource.dart';
import 'package:tupi_lingo/features/linguistic_morphology/data/datasources/morphology_rule_remote_datasource.dart';

/// Implementation of MorphologyRuleRepository with local-first caching and fallback.
class MorphologyRuleRepositoryImpl implements MorphologyRuleRepository {
  final MorphologyRuleLocalDataSource _local;
  final MorphologyRuleRemoteDataSource _remote;

  MorphologyRuleRepositoryImpl({
    MorphologyRuleLocalDataSource? local,
    MorphologyRuleRemoteDataSource? remote,
  })  : _local = local ?? MorphologyRuleLocalDataSource(),
        _remote = remote ?? MorphologyRuleRemoteDataSource();

  @override
  Future<List<MorphologicalRule>> getRules({int? variantId}) async {
    return _local.getRules(variantId: variantId);
  }

  @override
  Future<MorphologicalAnalysis?> getAnalysis(String wordLabel, {int? variantId}) async {
    final local = _local.getAnalysis(wordLabel, variantId: variantId);
    if (local != null) return local;

    final remote = await _remote.fetchAnalysis(wordLabel, variantId: variantId);
    if (remote != null) {
      await _local.saveAnalysis(remote);
      return remote;
    }
    return null;
  }

  @override
  Future<void> saveAnalysis(MorphologicalAnalysis analysis) async {
    await _local.saveAnalysis(analysis);
  }

  @override
  Future<MorphologicalFamily?> getFamily(String rootSurface, {int? variantId}) async {
    final local = _local.getFamily(rootSurface, variantId: variantId);
    if (local != null) return local;

    final remote = await _remote.fetchFamily(rootSurface, variantId: variantId);
    return remote;
  }

  @override
  Future<void> syncRules({int? variantId}) async {
    final remote = await _remote.fetchRules(variantId: variantId);
    if (remote.isNotEmpty) {
      await _local.saveRules(remote);
    }
  }
}
