import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/memory/memory_residency_engine.dart';
import 'package:tupi_lingo/core/routing/predictive_preloading_engine.dart';
import 'package:tupi_lingo/core/telemetry/performance_telemetry_engine.dart';

void main() {
  group('Instant Loading Engine Core Unit Tests', () {
    test('MemoryResidencyEngine L1 Cache & Object Pool Lifecycle', () {
      final memory = MemoryResidencyEngine.instance;

      // 1. Teste de Cache L1
      memory.putL1('licao_test_1', {'id': 1, 'titulo': 'Saudações'});
      final cached = memory.getL1<Map<String, dynamic>>('licao_test_1');
      expect(cached, isNotNull);
      expect(cached!['titulo'], 'Saudações');

      // 2. Teste de Object Pool
      final pooledItem = memory.acquire<List<String>>(() => <String>[]);
      pooledItem.add('Tupi');
      pooledItem.clear();
      memory.release<List<String>>(pooledItem);

      final reacquired = memory.acquire<List<String>>(() => <String>[]);
      expect(identical(pooledItem, reacquired), isTrue);
    });

    test('PredictivePreloadingEngine Markov 1st-Order Routing', () {
      final router = PredictivePreloadingEngine.instance;

      // Registra dados pré-carregados
      router.storePreloadedData('licao_10', {'id': 10, 'status': 'ready'});

      final data = router.consumePreloadedData<Map<String, dynamic>>('licao_10');
      expect(data, isNotNull);
      expect(data!['status'], 'ready');

      // Consumo deve ser único (Zero Stale Data)
      final secondConsume = router.consumePreloadedData<Map<String, dynamic>>('licao_10');
      expect(secondConsume, isNull);
    });

    test('PerformanceTelemetryEngine metrics aggregation', () {
      final telemetry = PerformanceTelemetryEngine.instance;
      final report = telemetry.getReport();

      expect(report.containsKey('total_frames'), isTrue);
      expect(report.containsKey('dropped_frames'), isTrue);
      expect(report.containsKey('fps'), isTrue);
    });
  });
}
