import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import '../../domain/entities/user_progress_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../models/user_progress_stats_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  // Cache em memória de alta performance (TTL 30s) para garantir fluidez e 120 FPS
  static UserProgressStats? _cachedStats;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(seconds: 30);

  /// Retorna as estatísticas atualmente em cache para renderização em 0ms
  static UserProgressStats? getCachedStats() => _cachedStats;

  /// Invalida o cache para forçar requisição fresca (ex: pós conclusão de lição/baú)
  static void invalidateCache() {
    _cachedStats = null;
    _cacheTimestamp = null;
  }

  @override
  Future<UserProgressStats> getUserProgressStats({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (forceRefresh) {
      invalidateCache();
    } else if (_cachedStats != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheTtl) {
      return _cachedStats!;
    }

    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final query = forceRefresh ? '?refresh=1' : '';

    try {
      // 1. Tenta o endpoint otimizado de dashboard
      var response = await ApiClient.get('$baseUrl/api/v1/dashboard/stats/$query');
      if (response.statusCode != 200) {
        // 2. Fallback para rota de perfil compatível
        response = await ApiClient.get('$baseUrl/api/v1/profile/');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final stats = UserProgressStatsModel.fromJson(data);
        _cachedStats = stats;
        _cacheTimestamp = now;
        return stats;
      }
    } catch (_) {
      // Se houver falha de rede mas temos cache prévio, retorna cache
      if (_cachedStats != null) {
        return _cachedStats!;
      }
    }

    // Retorna modelo vazio autêntico (0 XP, 0 lições, dias zerados)
    return UserProgressStatsModel.fromJson(const {});
  }
}
