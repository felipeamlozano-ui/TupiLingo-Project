import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/core/network/api_client.dart';

/// Gerenciador de Cache HTTP Local-First com padrão Stale-While-Revalidate.
/// Reduz a latência de carregamento percebida de ~1.5s para 0ms ao retornar dados
/// locais instantaneamente enquanto revalida silenciosamente em background.
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

  /// Retorna o JSON em cache se existir e não for nulo
  Future<String?> getCachedResponse(String url) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString('$_prefix$url');
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao ler cache de $url: $e');
      return null;
    }
  }

  /// Salva a resposta no cache local
  Future<void> saveResponse(String url, String body) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('$_prefix$url', body);
      await prefs.setInt('$_timePrefix$url', DateTime.now().millisecondsSinceEpoch);
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

  /// Limpa todo o cache de rede
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
