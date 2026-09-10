import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cofre seguro para armazenamento de credenciais, tokens JWT e material criptográfico.
///
/// Arquitetura de Hardware:
/// - Android: Chaves mestras AES-256 respaldadas por hardware no Android Keystore (TEE/StrongBox)
///   via EncryptedSharedPreferences.
/// - iOS: Keychain Services com isolamento no Secure Enclave (kSecAttrAccessibleAfterFirstUnlock).
class SecureVault {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  // Chaves de armazenamento canônicas
  static const String keyAccessToken = 'tupilingo_auth_access_token';
  static const String keyRefreshToken = 'tupilingo_auth_refresh_token';
  static const String keySessionSecret = 'tupilingo_session_ephemeral_secret';

  /// Salva um segredo no cofre respaldado por hardware
  static Future<void> writeSecret(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Lê um segredo do cofre
  static Future<String?> readSecret(String key) async {
    return await _storage.read(key: key);
  }

  /// Remove um segredo específico
  static Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  /// Higiene de Memória: limpa e sobrescreve todas as credenciais sensíveis (ex: no Logout ou Root Breach)
  static Future<void> wipeAllSecrets() async {
    await _storage.deleteAll();
  }
}
