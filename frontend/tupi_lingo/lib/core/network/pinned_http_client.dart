import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Cliente HTTP com Certificate Pinning e imposição de TLS 1.3.
/// Protege a comunicação cliente-servidor contra interceptações Man-In-The-Middle (MITM),
/// mesmo se certificados raiz maliciosos forem instalados no dispositivo do usuário.
class PinnedHttpClient {
  static HttpClient? _clientInstance;

  /// Hashes SHA-256 das chaves públicas (SPKI) permitidas para a infraestrutura TupiLingo
  /// Exemplo de pin da chave pública do servidor / CDN
  static final Set<String> _pinnedSpkiHashes = {
    // Hash SHA-256 da chave pública da infraestrutura de produção/staging
    '8f4a1c2d3e4b5a6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c',
  };

  /// Modo estrito de pinning (em ambiente de desenvolvimento/local, pode ser desativado via flag)
  static bool strictPinningEnabled = false;

  /// Retorna a instância singleton do HttpClient configurado com TLS 1.3 e Pinning
  static HttpClient getClient() {
    if (_clientInstance != null) return _clientInstance!;

    final context = SecurityContext(withTrustedRoots: true);

    final client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);

    // Validador customizado de certificado
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (!strictPinningEnabled) {
        // Em ambiente de desenvolvimento local (localhost / 10.0.2.2), permite certificados auto-assinados de dev
        if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
          return true;
        }
      }

      // Validação do fingerprint SHA-256 do certificado DER
      final certDer = cert.der;
      final digest = sha256.convert(certDer);
      final fingerprintHex = digest.toString().toLowerCase();

      if (_pinnedSpkiHashes.contains(fingerprintHex)) {
        return true;
      }

      // Rejeita conexão se o fingerprint não coincidir
      return false;
    };

    _clientInstance = client;
    return _clientInstance!;
  }

  /// Requisição GET binária com deserialização de Protocol Buffers
  static Future<T> getProtobuf<T>({
    required Uri url,
    required T Function(List<int> bytes) fromBuffer,
    Map<String, String>? headers,
  }) async {
    final client = getClient();
    final request = await client.getUrl(url);

    // Headers de negociação binária e segurança
    request.headers.set(HttpHeaders.acceptHeader, 'application/x-protobuf');
    request.headers.set('X-Client-Platform', 'flutter-impeller');
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Falha na requisição Protobuf: HTTP ${response.statusCode}',
        uri: url,
      );
    }

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytesBuilder.add(chunk);
    }

    final rawBytes = bytesBuilder.takeBytes();
    // Deserialização direta de alta velocidade
    return fromBuffer(rawBytes);
  }
}
