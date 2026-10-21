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

  /// Atualiza dinamicamente a URL base buscando a configuração mais recente do Supabase Storage.
  /// Valida a conectividade e sincroniza dotenv, SharedPreferences e reseta os circuit breakers.
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
            dotenv.env['API_URL'] = cleanUrl;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('tupilingo_last_winning_api_url', cleanUrl);
            if (kIsWeb) {
              WebNetworkDeduplicator.instance.clear();
            }
            if (kDebugMode) {
              debugPrint('[AppConfig] URL de backend atualizada dinamicamente para: $cleanUrl');
            }
            return cleanUrl;
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
}
