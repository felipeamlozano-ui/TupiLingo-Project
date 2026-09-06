import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exceção lançada quando a sessão do Supabase expira e não pode ser renovada.
class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([this.message = 'Sua sessão expirou. Faça login novamente.']);

  @override
  String toString() => message;
}

/// Cliente HTTP padronizado do TupiLingo com injeção automática de Bearer token,
/// renovação automática de sessão JWT (FLUTTER-001) e timeout resiliente.
class ApiClient {
  static Future<http.Response> get(String url, {Map<String, String>? extraHeaders}) =>
      _withRetry(() => _buildGet(url, extraHeaders: extraHeaders));

  static Future<http.Response> post(String url, {Object? body, Map<String, String>? extraHeaders}) =>
      _withRetry(() => _buildPost(url, body: body, extraHeaders: extraHeaders));

  static Future<http.Response> put(String url, {Object? body, Map<String, String>? extraHeaders}) =>
      _withRetry(() => _buildPut(url, body: body, extraHeaders: extraHeaders));

  static Future<http.Response> delete(String url, {Map<String, String>? extraHeaders}) =>
      _withRetry(() => _buildDelete(url, extraHeaders: extraHeaders));

  static Future<http.Response> _withRetry(
    Future<http.Response> Function() request,
  ) async {
    final response = await request().timeout(const Duration(seconds: 20));
    if (response.statusCode != 401) {
      return response;
    }

    // Se receber 401, tenta renovar proativamente a sessão JWT via Supabase
    try {
      final authResponse = await Supabase.instance.client.auth.refreshSession();
      if (authResponse.session == null) {
        throw const SessionExpiredException();
      }
      // Reexecuta o request original com o novo token Bearer
      return await request().timeout(const Duration(seconds: 20));
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      throw const SessionExpiredException();
    }
  }

  static Future<http.Response> _buildGet(String url, {Map<String, String>? extraHeaders}) async {
    final headers = await _headers(extraHeaders);
    return http.get(Uri.parse(url), headers: headers);
  }

  static Future<http.Response> _buildPost(
    String url, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _headers(extraHeaders);
    return http.post(
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
    return http.put(
      Uri.parse(url),
      headers: headers,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    );
  }

  static Future<http.Response> _buildDelete(String url, {Map<String, String>? extraHeaders}) async {
    final headers = await _headers(extraHeaders);
    return http.delete(Uri.parse(url), headers: headers);
  }

  static Future<Map<String, String>> _headers([Map<String, String>? extraHeaders]) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const SessionExpiredException('Usuário não autenticado.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }
}
