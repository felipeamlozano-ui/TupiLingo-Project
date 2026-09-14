import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';

/// Remote datasource fetching feature flags from Supabase table `feature_flags`.
class FlagRemoteDataSource {
  final SupabaseClient? _supabase;

  FlagRemoteDataSource([this._supabase]);

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches all feature flags from Supabase.
  /// Returns empty map if offline or on error.
  Future<Map<String, FeatureFlag>> fetchFlags() async {
    final client = _client;
    if (client == null) return {};

    try {
      final response = await client
          .from('feature_flags')
          .select('flag_id, is_enabled, rollout_percent, experiment_id, description, pillar, updated_at');

      final List<dynamic> rows = response as List<dynamic>;
      final Map<String, FeatureFlag> flags = {};

      for (final row in rows) {
        if (row is Map<String, dynamic>) {
          final flag = FeatureFlag.fromJson(row);
          flags[flag.id] = flag;
        }
      }

      return flags;
    } catch (_) {
      // Graceful offline fallback
      return {};
    }
  }
}
