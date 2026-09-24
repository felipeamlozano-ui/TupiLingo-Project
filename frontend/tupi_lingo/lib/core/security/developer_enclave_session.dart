import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/security/secure_vault.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';

/// Gerenciador Global da Sessão do Enclave de Segurança do Desenvolvedor.
/// Preserva o estado de autorização por 30 minutos contínuos na aplicação,
/// garantindo expiração automática e limpeza de dados sensíveis após esse período.
class DeveloperEnclaveSession {
  static final DeveloperEnclaveSession instance = DeveloperEnclaveSession._();
  DeveloperEnclaveSession._();

  static const String _keyToken = 'enclave_session_token';
  static const String _keyExpiresAt = 'enclave_session_expires_at';
  static const int kSessionDurationSeconds = 1800; // 30 minutos

  final ValueNotifier<bool> isUnlockedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);

  bool _isUnlocked = false;
  String? _sessionToken;
  int _expiresAtMs = 0;
  Timer? _countdownTimer;
  bool _initialized = false;

  bool get isUnlocked => _isUnlocked;
  String? get sessionToken => _sessionToken;
  int get remainingSeconds => _calculateRemainingSeconds();

  String get formattedRemaining {
    final secs = remainingSeconds;
    if (secs <= 0) return '00:00';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Inicializa e valida se há uma sessão persistida no SecureVault dentro dos 30 minutos
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final savedToken = await SecureVault.readSecret(_keyToken);
      final savedExpStr = await SecureVault.readSecret(_keyExpiresAt);

      if (savedToken != null && savedToken.isNotEmpty && savedExpStr != null) {
        final exp = int.tryParse(savedExpStr) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now < exp) {
          _sessionToken = savedToken;
          _expiresAtMs = exp;
          _setUnlocked(true);
          _startTimer();
          AppLogger.sec('ENCLAVE_SESSION', 'Sessão do Enclave restaurada do cofre seguro ($formattedRemaining restantes).');
          return;
        }
      }
    } catch (e) {
      AppLogger.w('ENCLAVE_SESSION', 'Erro ao ler sessão do cofre: $e');
    }

    await lock();
  }

  /// Desbloqueia o Enclave por 30 minutos e persiste no SecureVault
  Future<void> unlock(String token, {int durationSeconds = kSessionDurationSeconds}) async {
    _sessionToken = token;
    _expiresAtMs = DateTime.now().millisecondsSinceEpoch + (durationSeconds * 1000);
    _setUnlocked(true);
    _startTimer();

    try {
      await SecureVault.writeSecret(_keyToken, token);
      await SecureVault.writeSecret(_keyExpiresAt, _expiresAtMs.toString());
      AppLogger.sec('ENCLAVE_SESSION', 'Nova sessão de 30 minutos autorizada no Enclave de Segurança.');
    } catch (e) {
      AppLogger.w('ENCLAVE_SESSION', 'Falha ao persistir sessão: $e');
    }
  }

  /// Bloqueia e revoga a sessão do Enclave
  Future<void> lock() async {
    _stopTimer();
    final tokenToRevoke = _sessionToken;
    _sessionToken = null;
    _expiresAtMs = 0;
    _setUnlocked(false);

    try {
      await SecureVault.deleteSecret(_keyToken);
      await SecureVault.deleteSecret(_keyExpiresAt);
    } catch (_) {}

    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      try {
        final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/auth/otp/revoke-session/');
        http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'session_token': tokenToRevoke}),
        ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
      } catch (_) {}
    }
  }

  void _setUnlocked(bool value) {
    _isUnlocked = value;
    isUnlockedNotifier.value = value;
    remainingSecondsNotifier.value = remainingSeconds;
  }

  int _calculateRemainingSeconds() {
    if (!_isUnlocked || _expiresAtMs <= 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = _expiresAtMs - now;
    return diffMs > 0 ? (diffMs / 1000).ceil() : 0;
  }

  void _startTimer() {
    _stopTimer();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final rem = _calculateRemainingSeconds();
      remainingSecondsNotifier.value = rem;
      if (rem <= 0) {
        AppLogger.sec('ENCLAVE_SESSION', 'Tempo de 30 minutos expirado. Enclave bloqueado por segurança.');
        lock();
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }
}
