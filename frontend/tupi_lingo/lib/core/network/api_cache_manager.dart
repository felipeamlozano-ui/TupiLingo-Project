import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/security/crypto_engine.dart';

/// Gerenciador de Cache HTTP Local-First e Criptografado (AES-256-GCM).
///
/// Matriz de Segurança de Dados Locais:
/// - PERMITIDO E CIFRADO OFFLINE:
///   - Trilha, capítulos e lições desbloqueadas (`/api/v1/trilha/*`, `/api/v1/pedagogico/*`)
///   - Fila SRS e vocabulário (`/api/v1/revisao/*`)
///   - Catálogo canônico da loja (`/api/v1/store/catalog/`)
/// - ESTRITAMENTE PROIBIDO CACHEAR EM DISCO:
///   - Rotas administrativas (`/api/v1/admin/*`)
///   - Configurações de plataforma e flags (`/api/v1/platform/*`)
///   - Testes oficiais de nivelamento que definam ranking sem servidor (`/api/v1/nivelamento/*`)
///   - Logs de outros usuários e dados de sessão sensíveis
class ApiCacheManager {
  ApiCacheManager._();
  static final ApiCacheManager instance = ApiCacheManager._();

  static const String _prefix = 'enc_http_cache_';
  static const String _timePrefix = 'http_cache_time_';
  static const int _maxLruEntries = 50;

  /// Cache em memória RAM (LRU) para resposta instantânea em 0ms após a primeira decifração
  final LinkedHashMap<String, String> _lruRamCache = LinkedHashMap<String, String>();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Verifica se a URL é proibida de ser armazenada em cache local de acordo com a Matriz de Segurança
  bool _isCacheForbidden(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/api/v1/admin/') ||
        lower.contains('/api/v1/platform/') ||
        lower.contains('/api/v1/nivelamento/questoes/') ||
        lower.contains('/api/v1/nivelamento/responder/')) {
      return true;
    }
    return false;
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

  /// Retorna a resposta em cache se existir (0ms se em RAM, decifra se em disco)
  Future<String?> getCachedResponse(String url) async {
    if (_isCacheForbidden(url)) return null;

    final cacheKey = _scopedKey(url);

    // 1. Consulta em memória RAM (LRU): 0ms sem I/O de disco nem decifração
    if (_lruRamCache.containsKey(cacheKey)) {
      final value = _lruRamCache.remove(cacheKey)!;
      _lruRamCache[cacheKey] = value; // Move para o mais recente
      return value;
    }

    // 2. Consulta em disco cifrada (AES-256-GCM)
    try {
      final prefs = await _getPrefs();
      final encryptedPayload = prefs.getString(cacheKey);
      if (encryptedPayload == null || encryptedPayload.isEmpty) {
        return null;
      }

      final decrypted = await CryptoEngine.instance.decryptAesGcm(encryptedPayload);
      if (decrypted != null) {
        _putInRamCache(cacheKey, decrypted);
        return decrypted;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao ler/decifrar cache de $url: $e');
      return null;
    }
  }

  /// Salva a resposta cifrada com AES-256-GCM no disco e na memória RAM (LRU)
  Future<void> saveResponse(String url, String body) async {
    if (_isCacheForbidden(url)) {
      debugPrint('[ApiCacheManager] Cache rejeitado por política de segurança Zero-Trust: $url');
      return;
    }

    final cacheKey = _scopedKey(url);

    // 1. Atualiza imediatamente a memória RAM (LRU)
    _putInRamCache(cacheKey, body);

    // 2. Cifra o conteúdo com AES-256-GCM e salva no SharedPreferences
    try {
      final encryptedPayload = await CryptoEngine.instance.encryptAesGcm(body);
      final prefs = await _getPrefs();
      await prefs.setString(cacheKey, encryptedPayload);
      await prefs.setInt(_scopedTimeKey(url), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao cifrar/gravar cache de $url: $e');
    }
  }

  void _putInRamCache(String key, String value) {
    if (_lruRamCache.length >= _maxLruEntries) {
      _lruRamCache.remove(_lruRamCache.keys.first); // Evita saturação de RAM
    }
    _lruRamCache[key] = value;
  }

  /// Invalida o cache de uma URL específica ou padrão de rota
  Future<void> invalidate(String urlPattern) async {
    _lruRamCache.removeWhere((k, _) => k.contains(urlPattern));
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

  /// Limpa todo o cache em memória e em disco
  Future<void> clearAll() async {
    _lruRamCache.clear();
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith('http_cache_') || k.startsWith(_timePrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[ApiCacheManager] Erro ao limpar cache: $e');
    }
  }

  Future<void> clearCache() => clearAll();

  /// Executa requisição com política Stale-While-Revalidate:
  /// 1. Se houver cache local, dispara callback `onCacheAvailable(cachedJson)` imediatamente (0ms).
  /// 2. Executa a requisição real de rede em paralelo.
  /// 3. Se a rede retornar com sucesso, atualiza o cache cifrado e dispara `onFreshData(freshJson)`.
  Future<http.Response> getStaleWhileRevalidate(
    String url, {
    Map<String, String>? extraHeaders,
    void Function(String cachedBody)? onCacheAvailable,
    void Function(String freshBody)? onFreshData,
  }) async {
    // 1. Tenta carregar cache instantâneo (0ms)
    final cached = await getCachedResponse(url);
    if (cached != null && cached.isNotEmpty && onCacheAvailable != null) {
      onCacheAvailable(cached);
    }

    // 2. Executa request de rede
    try {
      final response = await ApiClient.get(url, extraHeaders: extraHeaders);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Grava cifrado no cache para acessos futuros
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
