import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/network/api_client.dart';

/// Gerenciador de Cache HTTP Local-First isolado por usuário.
/// Evita que novos usuários ou contas recém-logadas recebam dados cacheados de sessões anteriores.
class ApiCacheManager {
  ApiCacheManager._();
  static final ApiCacheManager instance = ApiCacheManager._();

  static const String _prefix = 'http_cache_';
  static const String _timePrefix = 'http_cache_time_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _scopedKey(String url) {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) return '$_prefix${userId}_$url';
    } catch (_) {}
    return '${_prefix}guest_$url';
  }

  String _scopedTimeKey(String url) {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) return '$_timePrefix${userId}_$url';
    } catch (_) {}
    return '${_timePrefix}guest_$url';
  }

  /// Retorna o JSON em cache se existir para o usuário autenticado
  Future<String?> getCachedResponse(String url) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_scopedKey(url));
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao ler cache de $url: $e');
      return null;
    }
  }

  /// Salva a resposta no cache local vinculada ao usuário atual
  Future<void> saveResponse(String url, String body) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_scopedKey(url), body);
      await prefs.setInt(_scopedTimeKey(url), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao gravar cache de $url: $e');
    }
  }

  /// Invalida o cache de uma URL específica ou todas as chaves com um determinado prefixo
  Future<void> invalidate(String urlPattern) async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.contains(urlPattern)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao invalidar cache: $e');
    }
  }

  /// Limpa todo o cache de rede do navegador/app
  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_timePrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao limpar cache: $e');
    }
  }

  /// Alias para clearAll()
  Future<void> clearCache() => clearAll();

  /// Executa requisição com política Stale-While-Revalidate:
  /// 1. Se houver cache local, dispara callback `onCacheAvailable(cachedJson)` imediatamente (0ms).
  /// 2. Executa a requisição real de rede em paralelo.
  /// 3. Se a rede retornar com sucesso, atualiza o cache e dispara `onFreshData(freshJson)`.
  Future<http.Response> getStaleWhileRevalidate(
    String url, {
    Map<String, String>? extraHeaders,
    void Function(String cachedBody)? onCacheAvailable,
    void Function(String freshBody)? onFreshData,
  }) async {
    // 1. Tenta carregar cache instantâneo
    final cached = await getCachedResponse(url);
    if (cached != null && cached.isNotEmpty && onCacheAvailable != null) {
      onCacheAvailable(cached);
    }

    // 2. Executa request de rede
    try {
      final response = await ApiClient.get(url, extraHeaders: extraHeaders);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Grava no cache para acessos futuros
        await saveResponse(url, response.body);
        if (onFreshData != null) {
          onFreshData(response.body);
        }
      }
      return response;
    } catch (e) {
      // Se a rede falhar mas tínhamos cache, simula resposta 200 usando o cache local (Offline-First)
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[ApiCacheManager] Rede indisponível. Usando cache offline para $url');
        return http.Response(cached, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      rethrow;
    }
  }
}
