import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_family.dart';

/// Remote datasource querying Supabase morphology tables.
class MorphologyRuleRemoteDataSource {
  final SupabaseClient? _supabase;

  MorphologyRuleRemoteDataSource([this._supabase]);

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<MorphologicalRule>> fetchRules({int? variantId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('morphology_rules').select('*');
      if (variantId != null) {
        query = query.or('variante_id.eq.$variantId,variante_id.is.null');
      }
      final response = await query;
      final list = response as List<dynamic>;
      return list.map((item) => MorphologicalRule.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<MorphologicalAnalysis?> fetchAnalysis(String wordLabel, {int? variantId}) async {
    final client = _client;
    if (client == null) return null;

    try {
      var query = client.from('morphological_analyses').select('*').eq('word_label', wordLabel);
      if (variantId != null) {
        query = query.eq('variante_id', variantId);
      }
      final response = await query.maybeSingle();
      if (response != null) {
        return MorphologicalAnalysis.fromJson(response);
      }
    } catch (_) {}
    return null;
  }

  Future<MorphologicalFamily?> fetchFamily(String rootSurface, {int? variantId}) async {
    final client = _client;
    if (client == null) return null;

    try {
      var query = client.from('morphological_families').select('*').eq('root_surface', rootSurface);
      if (variantId != null) {
        query = query.eq('variante_id', variantId);
      }
      final response = await query.maybeSingle();
      if (response != null) {
        return MorphologicalFamily.fromJson(response);
      }
    } catch (_) {}
    return null;
  }
}
