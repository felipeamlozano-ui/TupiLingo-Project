import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/semantic_search/domain/entities/search_result.dart';

/// Remote datasource fetching dictionary terms from Supabase.
class SearchRemoteDataSource {
  final SupabaseClient? _supabase;

  SearchRemoteDataSource([this._supabase]);

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<SearchResult>> fetchDictionary({int? variantId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('trilha_conteudolicao').select('*');
      if (variantId != null) {
        query = query.eq('variante_id', variantId);
      }
      final response = await query.limit(100);
      final list = response as List<dynamic>;

      return list.map((item) {
        final row = item as Map<String, dynamic>;
        return SearchResult.fromJson(row);
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
