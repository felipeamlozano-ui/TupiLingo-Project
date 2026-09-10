import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/concurrency/background_execution_engine.dart';
import 'package:tupi_lingo/core/audit/performance_audit_engine.dart';

void main() {
  group('RFC-009C Web Runtime Compatibility & Performance Audit Tests', () {
    test('BackgroundExecutionEngine executes compute and run safely', () async {
      final engine = BackgroundExecutionEngine.instance;

      // 1. Compute execution
      final computed = await engine.compute<int, int>((val) => val * 2, 21);
      expect(computed, 42);

      // 2. Run async execution
      final result = await engine.run<String>(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'tupi_ok';
      });
      expect(result, 'tupi_ok');
    });

    test('PerformanceAuditEngine tracks widget rebuilds and warmup deduplication', () {
      final auditor = PerformanceAuditEngine.instance;

      // 1. Rebuild tracking
      auditor.recordRebuild('TrailScreen');
      auditor.recordRebuild('TrailScreen');
      expect(auditor.getRebuildCount('TrailScreen'), 2);

      // 2. Warmup deduplication
      final firstWarmup = auditor.shouldWarmupRoute('/trail/licao_1');
      expect(firstWarmup, isTrue);

      final duplicateWarmup = auditor.shouldWarmupRoute('/trail/licao_1');
      expect(duplicateWarmup, isFalse); // Deduplicated!
    });

    test('PerformanceAuditEngine request locking lifecycle', () {
      final auditor = PerformanceAuditEngine.instance;

      final lock1 = auditor.tryAcquireRequestLock('licao_101');
      expect(lock1, isTrue);

      final lock2 = auditor.tryAcquireRequestLock('licao_101');
      expect(lock2, isFalse); // Já travado

      auditor.releaseRequestLock('licao_101');
      final lock3 = auditor.tryAcquireRequestLock('licao_101');
      expect(lock3, isTrue); // Liberado
      auditor.releaseRequestLock('licao_101');
    });
  });
}
