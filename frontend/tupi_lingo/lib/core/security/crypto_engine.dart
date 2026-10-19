import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/core/security/secure_vault.dart';

/// Motor criptográfico seguro do TupiLingo para proteção de dados em repouso e trânsito.
///
/// Arquitetura:
/// - AES-256-GCM: Cifragem simétrica com nonce de 96 bits (12 bytes) e MAC tag de autenticação de 128 bits (16 bytes).
/// - HMAC-SHA256: Assinatura de integridade anti-tampering e anti-replay para itens do Outbox offline.
/// - Chaves mestras geradas com CSPRNG de alta entropia e isoladas em hardware seguro via [SecureVault].
class CryptoEngine {
  CryptoEngine._();
  static final CryptoEngine instance = CryptoEngine._();

  static const String _keyMasterKeyHex = 'tupilingo_crypto_master_key_v1';
  static const String _keyHmacKeyHex = 'tupilingo_crypto_hmac_key_v1';
  static const String _payloadPrefixV1 = 'AES256GCM_V1:';

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hmac _hmac = Hmac.sha256();

  List<int>? _cachedMasterKeyBytes;
  List<int>? _cachedHmacKeyBytes;
  bool _initialized = false;

  /// Inicializa e garante a presença das chaves criptográficas no cofre de hardware.
  Future<void> init() async {
    if (_initialized && _cachedMasterKeyBytes != null && _cachedHmacKeyBytes != null) {
      return;
    }
    await _getMasterKeyBytes();
    await _getHmacKeyBytes();
    _initialized = true;
  }

  /// Recupera ou gera chave simétrica de 256 bits (32 bytes) no SecureVault
  Future<List<int>> _getMasterKeyBytes() async {
    if (_cachedMasterKeyBytes != null) return _cachedMasterKeyBytes!;

    String? keyHex = await SecureVault.readSecret(_keyMasterKeyHex);
    if (keyHex == null || keyHex.length != 64) {
      // Gera nova chave segura de 32 bytes usando CSPRNG
      final random = Random.secure();
      final bytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        bytes[i] = random.nextInt(256);
      }
      keyHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await SecureVault.writeSecret(_keyMasterKeyHex, keyHex);
    }

    _cachedMasterKeyBytes = _hexToBytes(keyHex);
    return _cachedMasterKeyBytes!;
  }

  /// Recupera ou gera chave de assinatura HMAC-SHA256 (32 bytes) no SecureVault
  Future<List<int>> _getHmacKeyBytes() async {
    if (_cachedHmacKeyBytes != null) return _cachedHmacKeyBytes!;

    String? keyHex = await SecureVault.readSecret(_keyHmacKeyHex);
    if (keyHex == null || keyHex.length != 64) {
      final random = Random.secure();
      final bytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        bytes[i] = random.nextInt(256);
      }
      keyHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await SecureVault.writeSecret(_keyHmacKeyHex, keyHex);
    }

    _cachedHmacKeyBytes = _hexToBytes(keyHex);
    return _cachedHmacKeyBytes!;
  }

  /// Cifra texto puro usando AES-256-GCM.
  /// Formato do payload retornado:
  /// `AES256GCM_V1:<base64(12 bytes nonce + 16 bytes MAC tag + ciphertext)>`
  Future<String> encryptAesGcm(String plaintext) async {
    try {
      final keyBytes = await _getMasterKeyBytes();
      final secretKey = SecretKey(keyBytes);
      final clearBytes = utf8.encode(plaintext);

      // Gera nonce aleatório de 12 bytes (96 bits) recomendado para GCM
      final nonce = _aesGcm.newNonce();

      final secretBox = await _aesGcm.encrypt(
        clearBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      // Pacote: [12 bytes nonce] + [16 bytes tag MAC] + [N bytes ciphertext]
      final combined = Uint8List(
        secretBox.nonce.length + secretBox.mac.bytes.length + secretBox.cipherText.length,
      );
      int offset = 0;

      combined.setRange(offset, offset + secretBox.nonce.length, secretBox.nonce);
      offset += secretBox.nonce.length;

      combined.setRange(offset, offset + secretBox.mac.bytes.length, secretBox.mac.bytes);
      offset += secretBox.mac.bytes.length;

      combined.setRange(offset, offset + secretBox.cipherText.length, secretBox.cipherText);

      return '$_payloadPrefixV1${base64Encode(combined)}';
    } catch (e) {
      debugPrint('[CryptoEngine] Erro fatal ao cifrar dados AES-GCM: $e');
      rethrow;
    }
  }

  /// Decifra payload AES-256-GCM verificando a tag de autenticação.
  /// Se o payload estiver adulterado ou a chave for incorreta, falha na verificação de MAC.
  Future<String?> decryptAesGcm(String payload) async {
    try {
      if (!payload.startsWith(_payloadPrefixV1)) {
        // Fallback defensivo para migração suave se payload não foi cifrado
        return payload;
      }

      final rawBase64 = payload.substring(_payloadPrefixV1.length);
      final combined = base64Decode(rawBase64);

      if (combined.length < 28) {
        debugPrint('[CryptoEngine] Payload inválido (menor que nonce + MAC tag).');
        return null;
      }

      final nonce = combined.sublist(0, 12);
      final macBytes = combined.sublist(12, 28);
      final cipherText = combined.sublist(28);

      final keyBytes = await _getMasterKeyBytes();
      final secretKey = SecretKey(keyBytes);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(clearBytes);
    } catch (e) {
      debugPrint('[CryptoEngine] Falha ao decifrar ou autenticar dados (possível adulteração): $e');
      return null;
    }
  }

  /// Gera assinatura digital HMAC-SHA256 para integridade de pacotes offline
  Future<String> signHmacSha256(String message) async {
    final keyBytes = await _getHmacKeyBytes();
    final secretKey = SecretKey(keyBytes);
    final mac = await _hmac.calculateMac(
      utf8.encode(message),
      secretKey: secretKey,
    );
    return mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Valida assinatura HMAC-SHA256 de forma constante no tempo
  Future<bool> verifyHmacSha256(String message, String signatureHex) async {
    final expectedHex = await signHmacSha256(message);
    if (expectedHex.length != signatureHex.length) return false;

    int diff = 0;
    for (int i = 0; i < expectedHex.length; i++) {
      diff |= expectedHex.codeUnitAt(i) ^ signatureHex.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Assina formalmente um item de conclusão de lição offline para o Outbox
  Future<String> signOutboxLesson({
    required String userId,
    required int lessonId,
    required int xpEarned,
    required int timestamp,
    required String nonce,
  }) async {
    final canonical = 'OUTBOX:$userId:LESSON:$lessonId:XP:$xpEarned:TS:$timestamp:NONCE:$nonce';
    return await signHmacSha256(canonical);
  }

  /// Utilitário seguro para gerar nonces aleatórios de 128 bits (16 bytes hex)
  String generateNonce() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
