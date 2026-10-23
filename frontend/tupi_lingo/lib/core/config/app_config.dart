import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/core/platform/web/web_network_deduplicator.dart';

/// Configurações centrais da aplicação e endpoints de backend
class AppConfig {
  AppConfig._();

  static const String fallbackTunnelConfigUrl =
      'https://pcquxppvheodcrdkwqhh.supabase.co/storage/v1/object/public/public-config/tunnel_url.json';

  static String get backendBaseUrl {
    final url = dotenv.env['API_URL']?.trim();
    if (url != null && url.isNotEmpty) {
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    return 'http://127.0.0.1:8000';
  }

  /// Testa a conectividade real com um endpoint através de /api/health/
  static Future<bool> checkHealth(String url, {Duration timeout = const Duration(milliseconds: 2500)}) async {
    try {
      final clean = url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) return false;
      final res = await http.get(Uri.parse('$clean/api/health/')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Atualiza dinamicamente a URL base buscando a configuração mais recente do Supabase Storage.
  /// Valida ativamente a conectividade (/api/health/) antes de aceitar o túnel.
  static Future<String?> refreshTunnelUrl() async {
    try {
      final res = await http
          .get(Uri.parse(fallbackTunnelConfigUrl))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawUrl = data['url']?.toString().trim();
        if (rawUrl != null && rawUrl.startsWith('http')) {
          final cleanUrl = rawUrl.endsWith('/') ? rawUrl.substring(0, rawUrl.length - 1) : rawUrl;
          final isHttpsWeb = kIsWeb && Uri.base.scheme == 'https';
          if (!isHttpsWeb || cleanUrl.startsWith('https://')) {
            final isHealthy = await checkHealth(cleanUrl);
            if (isHealthy) {
              dotenv.env['API_URL'] = cleanUrl;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('tupilingo_last_winning_api_url', cleanUrl);
              if (kIsWeb) {
                WebNetworkDeduplicator.instance.clear();
              }
              if (kDebugMode) {
                debugPrint('[AppConfig] Túnel Cloudflare validado e ativo: $cleanUrl');
              }
              return cleanUrl;
            } else {
              if (kDebugMode) {
                debugPrint('[AppConfig] Túnel obtido do Supabase ($cleanUrl) está inacessível/offline. Descartando.');
              }
              final prefs = await SharedPreferences.getInstance();
              final cached = prefs.getString('tupilingo_last_winning_api_url');
              if (cached == cleanUrl) {
                await prefs.remove('tupilingo_last_winning_api_url');
              }
              if (dotenv.env['API_URL'] == cleanUrl) {
                dotenv.env['API_URL'] = isHttpsWeb ? '' : 'http://127.0.0.1:8000';
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppConfig] Falha ao renovar tunnel URL: $e');
      }
    }
    return null;
  }

  /// Descobre o endpoint de backend ativo testando os candidatos (local e remoto) com tolerância a falhas.
  static Future<String> discoverWorkingBackendUrl() async {
    final isHttpsWeb = kIsWeb && Uri.base.scheme == 'https';
    final current = backendBaseUrl;

    if (await checkHealth(current)) {
      return current;
    }

    final candidates = <String>{
      if (!isHttpsWeb) ...[
        'http://127.0.0.1:8000',
        'http://localhost:8000',
        'http://10.0.2.2:8000',
      ],
      current,
    }.where((u) => !isHttpsWeb || u.startsWith('https://')).toList();

    for (final candidate in candidates) {
      if (await checkHealth(candidate)) {
        dotenv.env['API_URL'] = candidate;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tupilingo_last_winning_api_url', candidate);
        if (kIsWeb) {
          WebNetworkDeduplicator.instance.clear();
        }
        if (kDebugMode) {
          debugPrint('[AppConfig] Endpoint de backend ativo detectado: $candidate');
        }
        return candidate;
      }
    }

    // Se os candidatos locais não responderem, tenta obter túnel do Supabase
    final tunnelUrl = await refreshTunnelUrl();
    if (tunnelUrl != null && tunnelUrl.isNotEmpty) {
      return tunnelUrl;
    }

    return backendBaseUrl;
  }
}
