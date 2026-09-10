import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/platform/web/web_network_deduplicator.dart';
import 'package:tupi_lingo/core/platform/web/web_engine_bootstrap.dart';
import 'package:tupi_lingo/core/platform/platform_web_bridge.dart';

void main() {
  group('HPWE (RFC-009B) Web & Network Engine Unit Tests', () {
    test('WebNetworkDeduplicator shares in-flight requests (Promise Sharing)', () async {
      final deduplicator = WebNetworkDeduplicator.instance;
      int executionCount = 0;

      Future<String> sampleRequest() async {
        executionCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success_payload';
      }

      // Dispara 3 requisições concorrentes com a mesma chave
      final f1 = deduplicator.execute(
        requestKey: 'licao_42_payload',
        requestFactory: sampleRequest,
      );
      final f2 = deduplicator.execute(
        requestKey: 'licao_42_payload',
        requestFactory: sampleRequest,
      );
      final f3 = deduplicator.execute(
        requestKey: 'licao_42_payload',
        requestFactory: sampleRequest,
      );

      final results = await Future.wait([f1, f2, f3]);

      // Todas devem ter recebido o mesmo payload
      expect(results[0], 'success_payload');
      expect(results[1], 'success_payload');
      expect(results[2], 'success_payload');

      // Mas o executor físico deve ter rodado EXATAMENTE 1 vez! (Zero tráfego repetido)
      expect(executionCount, 1);
    });

    test('PlatformWebBridge executes requests without throwing', () async {
      final bridge = PlatformWebBridge.instance;
      await bridge.initialize();

      final result = await bridge.executeRequest(
        key: 'test_key',
        action: () async => 42,
      );

      expect(result, 42);
    });

    test('WebEngineBootstrap metrics initialization', () async {
      final bootstrap = WebEngineBootstrap.instance;
      await bootstrap.initialize();
      final metrics = bootstrap.getWebMetrics();
      expect(metrics, isA<Map<String, dynamic>>());
    });
  });
}
