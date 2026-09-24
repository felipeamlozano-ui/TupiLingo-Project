import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/security/encryption_center.dart';

void main() {
  group('Post-Quantum Cryptography Suite (NIST FIPS 203 / 204)', () {
    test('PQC Key Generation produces valid fingerprint', () {
      final fingerprint = EncryptionCenter.instance.activeFingerprint;
      expect(fingerprint, isNotEmpty);
      expect(fingerprint.length, greaterThanOrEqualTo(8));
      expect(EncryptionCenter.instance.isHardwareEnclaveBacked, isTrue);
    });

    test('PQC Seal and Unseal roundtrip with ML-KEM-768 and ML-DSA-65', () {
      const plaintext = 'Dados Ultrassecretos da Aldeia Pindorama 2026';
      final envelope = EncryptionCenter.instance.pqcSealData(plaintext, customContext: 'TEST_ROUNDTRIP');

      expect(envelope.algorithm, contains('ML-KEM-768'));
      expect(envelope.ciphertext, isNotEmpty);
      expect(envelope.kemCiphertext, contains('::'));
      expect(envelope.pqcSignature, isNotEmpty);
      expect(envelope.mac, isNotEmpty);

      // Decapsulation and verification
      final unsealed = EncryptionCenter.instance.pqcUnsealData(envelope, customContext: 'TEST_ROUNDTRIP');
      expect(unsealed, equals(plaintext));
    });

    test('PQC Armored string serialization and deserialization', () {
      const payload = 'Token_Enclave_Admin_Session_Valid_30m';
      final envelope = EncryptionCenter.instance.pqcSealData(payload);
      final armored = envelope.toArmoredString();

      expect(armored.startsWith('PQC:v1:'), isTrue);

      final restoredEnvelope = PqcSealedEnvelope.fromArmoredString(armored);
      expect(restoredEnvelope.algorithm, equals(envelope.algorithm));
      expect(restoredEnvelope.mac, equals(envelope.mac));

      final restoredText = EncryptionCenter.instance.pqcUnsealData(restoredEnvelope);
      expect(restoredText, equals(payload));
    });

    test('PQC Self-Test / Benchmark executes successfully with zero failures', () {
      final benchmark = EncryptionCenter.instance.runPqcSelfTest();
      expect(benchmark.success, isTrue);
      expect(benchmark.securityStrengthBits, 192);
      expect(benchmark.algorithmName, contains('ML-KEM-768'));
      expect(benchmark.statusMessage, contains('verificada com sucesso'));
    });

    test('Emergency Memory Wipe clears active keys', () {
      EncryptionCenter.instance.emergencyMemoryWipe();
      expect(EncryptionCenter.instance.activeFingerprint, equals('WIPED_0x00000000'));

      // Rotates back for normal operation
      EncryptionCenter.instance.rotateEphemeralKeys();
      expect(EncryptionCenter.instance.activeFingerprint, isNot(equals('WIPED_0x00000000')));
    });
  });
}
