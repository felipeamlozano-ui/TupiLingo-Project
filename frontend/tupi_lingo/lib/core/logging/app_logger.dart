import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/core/security/crypto_engine.dart';

enum LogLevel { debug, info, warning, error, security }

class EncryptedLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  EncryptedLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'tag': tag,
        'message': message,
      };

  factory EncryptedLogEntry.fromJson(Map<String, dynamic> json) => EncryptedLogEntry(
        timestamp: DateTime.parse(json['timestamp']),
        level: LogLevel.values.firstWhere(
          (e) => e.name.toUpperCase() == json['level'],
          orElse: () => LogLevel.info,
        ),
        tag: json['tag'] ?? '',
        message: json['message'] ?? '',
      );
}

/// Gerenciador centralizado de logs da aplicação com persistência cifrada AES-256-GCM.
class AppLogger {
  static final AppLogger instance = AppLogger._();
  AppLogger._();

  static const int _maxInMemoryEntries = 200;
  static const String _storageKeyEncryptedLogs = 'tupilingo_encrypted_app_logs_v1';

  final List<EncryptedLogEntry> _entries = [];
  bool _initialized = false;

  /// Notificador reativo para atualizar o console em tempo real
  final ValueNotifier<int> logChangeNotifier = ValueNotifier<int>(0);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedPayload = prefs.getString(_storageKeyEncryptedLogs);
      if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
        final decrypted = await CryptoEngine.instance.decryptAesGcm(encryptedPayload);
        if (decrypted != null && decrypted.isNotEmpty) {
          final decoded = jsonDecode(decrypted);
          if (decoded is List) {
            _entries.clear();
            for (final item in decoded) {
              try {
                _entries.add(EncryptedLogEntry.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AppLogger] Erro ao restaurar logs cifrados: $e');
    }

    if (_entries.isEmpty) {
      seedDefaultLogs();
    }
  }

  void seedDefaultLogs() {
    i('CORE_RUNTIME', 'Sessão do TupiLingo inicializada.');
    i('SECURITY', 'Motor criptográfico AES-256-GCM / HMAC-SHA256 ativo.');
  }

  void _log(LogLevel level, String tag, String message) {
    final entry = EncryptedLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );

    if (kDebugMode) {
      debugPrint('[${level.name.toUpperCase()}] [$tag] $message');
    }

    _entries.add(entry);
    if (_entries.length > _maxInMemoryEntries) {
      _entries.removeAt(0);
    }
    logChangeNotifier.value++;
  }

  static void d(String tag, String message) => instance._log(LogLevel.debug, tag, message);
  static void i(String tag, String message) => instance._log(LogLevel.info, tag, message);
  static void w(String tag, String message) => instance._log(LogLevel.warning, tag, message);
  static void e(String tag, String message) => instance._log(LogLevel.error, tag, message);
  static void sec(String tag, String message) => instance._log(LogLevel.security, tag, message);

  /// Retorna os registros em memória para o console de desenvolvedor
  Future<List<EncryptedLogEntry>> getDecryptedLogs([String? sessionToken]) async {
    await init();
    return List.unmodifiable(_entries.reversed);
  }

  Future<void> clearLogs() async {
    _entries.clear();
    logChangeNotifier.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyEncryptedLogs);
    } catch (_) {}
  }

  /// Persiste todos os logs em disco cifrados com AES-256-GCM
  Future<void> flushToDisk() async {
    try {
      if (_entries.isEmpty) return;
      final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());
      final encryptedPayload = await CryptoEngine.instance.encryptAesGcm(jsonStr);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKeyEncryptedLogs, encryptedPayload);
    } catch (e) {
      debugPrint('[AppLogger] Erro ao persistir logs cifrados no disco: $e');
    }
  }
}
