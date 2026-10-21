import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/platform/platform_web_bridge.dart';
import 'package:tupi_lingo/core/network/api_cache_manager.dart';
import 'package:tupi_lingo/core/security/session_manager.dart';

/// Exceção lançada quando a sessão do Supabase expira e não pode ser renovada.
class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([this.message = 'Sua sessão expirou. Faça login novamente.']);

  @override
  String toString() => message;
}

/// Cliente HTTP padronizado do TupiLingo com injeção automática de Bearer token,
/// renovação automática de sessão JWT (FLUTTER-001), pool de conexões persistentes (Keep-Alive)
/// e proteção com disjuntor (Circuit Breaker) para resiliência de rede.
class ApiClient {
  /// Instância reutilizável singleton de http.Client que mantém conexões TCP/TLS ativas (Keep-Alive)
  static final http.Client _client = http.Client();

  /// Timeout padrão para requisições de API (30s)
  static const Duration defaultTimeout = Duration(seconds: 30);

  // Circuit Breaker State
  static int _consecutiveFailures = 0;
  static DateTime? _circuitOpenUntil;
  static const int _maxFailuresBeforeTrip = 4;
  static const Duration _circuitCooldown = Duration(seconds: 8);

  static bool get isCircuitOpen {
    if (_circuitOpenUntil == null) return false;
    if (DateTime.now().isAfter(_circuitOpenUntil!)) {
      _circuitOpenUntil = null;
      _consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  static void _recordSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenUntil = null;
  }

  static void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxFailuresBeforeTrip) {
      _circuitOpenUntil = DateTime.now().add(_circuitCooldown);
    }
  }

  static Future<http.Response> get(
    String url, {
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      PlatformWebBridge.instance.executeRequest(
        key: 'GET_$url',
        action: () => _withRetry(() => _buildGet(url, extraHeaders: extraHeaders), timeout: timeout),
      );

  /// Retorna dados em cache instantaneamente (0ms) e revalida em segundo plano
  static Future<http.Response> getCached(
    String url, {
    Map<String, String>? extraHeaders,
    void Function(String cachedBody)? onCacheAvailable,
    void Function(String freshBody)? onFreshData,
  }) =>
      ApiCacheManager.instance.getStaleWhileRevalidate(
        url,
        extraHeaders: extraHeaders,
        onCacheAvailable: onCacheAvailable,
        onFreshData: onFreshData,
      );

  static Future<http.Response> post(
    String url, {
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _withRetry(() => _buildPost(url, body: body, extraHeaders: extraHeaders), timeout: timeout);

  static Future<http.Response> put(
    String url, {
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _withRetry(() => _buildPut(url, body: body, extraHeaders: extraHeaders), timeout: timeout);

  static Future<http.Response> delete(
    String url, {
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _withRetry(() => _buildDelete(url, extraHeaders: extraHeaders), timeout: timeout);

  static Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    if (isCircuitOpen) {
      throw http.ClientException('Circuit breaker aberto devido a sucessivas falhas de rede.');
    }

    final effectiveTimeout = timeout ?? defaultTimeout;

    try {
      final response = await request().timeout(effectiveTimeout);
      _recordSuccess();

      if (response.statusCode != 401) {
        return response;
      }

      // Se receber 401, tenta renovar proativamente a sessão JWT via Supabase / SessionManager
      try {
        final authResponse = await Supabase.instance.client.auth.refreshSession();
        if (authResponse.session == null) {
          throw const SessionExpiredException();
        }
        await SessionManager.instance.saveSession(authResponse.session!);

        // Reexecuta o request original com o novo token Bearer
        final retryRes = await request().timeout(effectiveTimeout);
        _recordSuccess();
        return retryRes;
      } on AuthException {
        // Apenas se Supabase confirmar falha definitiva de autenticação lançamos SessionExpiredException.
        // NUNCA chamamos signOut() destrutivo que apaga as credenciais locais em oscilações!
        throw const SessionExpiredException();
      } catch (e) {
        if (e is SessionExpiredException) rethrow;
        throw const SessionExpiredException('Instabilidade de conexão ao autenticar. Tente novamente.');
      }
    } catch (e) {
      if (e is! SessionExpiredException) {
        _recordFailure();
      }
      rethrow;
    }
  }

  static Future<http.Response> _buildGet(String url, {Map<String, String>? extraHeaders}) async {
    final headers = await _headers(extraHeaders);
    return _client.get(Uri.parse(url), headers: headers);
  }

  static Future<http.Response> _buildPost(
    String url, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _headers(extraHeaders);
    return _client.post(
      Uri.parse(url),
      headers: headers,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    );
  }

  static Future<http.Response> _buildPut(
    String url, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _headers(extraHeaders);
    return _client.put(
      Uri.parse(url),
      headers: headers,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    );
  }

  static Future<http.Response> _buildDelete(String url, {Map<String, String>? extraHeaders}) async {
    final headers = await _headers(extraHeaders);
    return _client.delete(Uri.parse(url), headers: headers);
  }

  static Future<Map<String, String>> _headers([Map<String, String>? extraHeaders]) async {
    final token = await SessionManager.instance.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw const SessionExpiredException('Usuário não autenticado.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }
}
