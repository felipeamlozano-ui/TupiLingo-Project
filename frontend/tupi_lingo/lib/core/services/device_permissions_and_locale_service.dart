import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço de Gerenciamento Elegante de Permissões e Resolução de País Zero-PII.
/// Cumpre estritamente a política de privacidade Zero-PII:
/// Coordenadas de latitude/longitude e dados de GPS NUNCA são persistidos ou enviados a servidores.
/// Apenas o código ISO 3166-1 alfa-2 do país (ex: 'BR', 'US', 'PT') e seu nome representativo
/// são resolvidos e utilizados em telemetria e presença.
class DevicePermissionsAndLocaleService {
  DevicePermissionsAndLocaleService._();
  static final DevicePermissionsAndLocaleService instance = DevicePermissionsAndLocaleService._();

  String _currentCountryCode = 'BR';
  String _currentCountryName = 'Brasil';
  bool _permissionsRequested = false;

  String get currentCountryCode => _currentCountryCode;
  String get currentCountryName => _currentCountryName;

  /// Mapeamento ISO para nomes legíveis comuns
  static const Map<String, String> _countryNames = {
    'BR': 'Brasil',
    'PT': 'Portugal',
    'US': 'Estados Unidos',
    'ES': 'Espanha',
    'FR': 'França',
    'DE': 'Alemanha',
    'GB': 'Reino Unido',
    'IT': 'Itália',
    'CA': 'Canadá',
    'AR': 'Argentina',
    'UY': 'Uruguai',
    'PY': 'Paraguai',
    'CL': 'Chile',
    'CO': 'Colômbia',
    'PE': 'Peru',
    'MX': 'México',
    'AO': 'Angola',
    'MZ': 'Moçambique',
  };

  /// Solicita permissões essenciais de Notificação e Localização Aproximada de forma elegante.
  Future<void> requestPermissionsAndResolveLocale() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    try {
      if (!kIsWeb) {
        // 1. Notificações (Android 13+ / iOS)
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await Permission.notification.request();
        }

        // 2. Localização aproximada para país (Zero-PII)
        final locationStatus = await Permission.locationWhenInUse.status;
        if (!locationStatus.isGranted) {
          await Permission.locationWhenInUse.request();
        }
      }

      // 3. Resolução segura de país (Zero-PII)
      _resolveCountryZeroPii();
    } catch (e) {
      debugPrint('[DevicePermissionsAndLocaleService] Falha na requisição de permissões: $e');
      _resolveCountryZeroPii();
    }
  }

  /// Resolve o país a partir da configuração do sistema operacional (Locale)
  /// sem reter ou armazenar nenhuma coordenada de geolocalização.
  void _resolveCountryZeroPii() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final code = locale.countryCode?.toUpperCase();
      if (code != null && code.length == 2) {
        _currentCountryCode = code;
        _currentCountryName = _countryNames[code] ?? code;
        debugPrint('[DevicePermissionsAndLocaleService] País Zero-PII resolvido: $_currentCountryCode ($_currentCountryName)');
        return;
      }
    } catch (_) {}

    // Fallback padrão seguro
    _currentCountryCode = 'BR';
    _currentCountryName = 'Brasil';
  }

  /// Força atualização do país (ex: quando o usuário altera o idioma do sistema)
  void refreshLocale() {
    _resolveCountryZeroPii();
  }
}
