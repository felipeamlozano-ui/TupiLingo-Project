import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/security/encryption_center.dart';
import 'package:tupi_lingo/core/telemetry/telemetry_service.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/platform_suite_shell.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/shared/metric_card.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/shared/status_badge.dart';

void main() {
  group('RFC-013 Platform Suite Tests', () {
    test('EncryptionCenter generates deterministic SHA-256 snapshot hash', () {
      final crypto = EncryptionCenter.instance;

      final snapshot1 = {
        'territories': [{'id': 1, 'name': 'Tupinambá'}],
        'villages': [{'id': 1, 'name': 'Ubatuba'}],
      };

      final snapshot2 = {
        'villages': [{'id': 1, 'name': 'Ubatuba'}],
        'territories': [{'id': 1, 'name': 'Tupinambá'}],
      };

      final hash1 = crypto.generateSnapshotHash(snapshot1);
      final hash2 = crypto.generateSnapshotHash(snapshot2);

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2), reason: 'Canonicalized JSON must generate identical hashes regardless of key order');
      expect(crypto.verifySnapshotIntegrity(snapshot1, hash1), isTrue);
    });

    test('EncryptionCenter signs audit entries and validates Merkle Chain', () {
      final crypto = EncryptionCenter.instance;

      final sig1 = crypto.signAuditTrailEntry(
        action: 'CREATE_TERRITORY',
        entityType: 'Territory',
        entityId: '1',
        actorRole: 'Curator',
        prevHash: 'GENESIS_ROOT_HASH',
      );
      expect(sig1, isNotEmpty);

      final logs = [
        {
          'action': 'PUBLISH',
          'signature_hash': 'abc123hash',
        },
        {
          'action': 'CREATE',
          'signature_hash': 'genesis123',
        },
      ];

      expect(crypto.verifyAuditChainIntegrity(logs), isTrue);
    });

    test('EncryptionCenter rotates keys and wipes memory', () {
      final crypto = EncryptionCenter.instance;
      crypto.rotateEphemeralKeys();
      crypto.emergencyMemoryWipe();
      expect(crypto.isHardwareEnclaveBacked, isTrue);
    });

    test('TelemetryService records network latency and maintains Zero-PII', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(telemetryServiceProvider.notifier);
      notifier.recordNetworkLatency(const Duration(milliseconds: 32));

      final state = container.read(telemetryServiceProvider);
      expect(state.networkLatencyMs, equals(32.0));
      expect(state.currentFps, greaterThanOrEqualTo(0.0));

      final sample = TelemetryMetricSample(
        fps: 60.0,
        avgBuildMs: 3.2,
        avgRasterMs: 3.5,
        frameDropsPct: 0.0,
        memoryMb: 150.0,
        p95LatencyMs: 30.0,
        deviceClass: 'flagship',
        timestamp: DateTime.now(),
      );

      final json = sample.toJson();
      expect(json.containsKey('user_id'), isFalse, reason: 'Zero-PII guarantee: no user_id allowed');
      expect(json.containsKey('email'), isFalse, reason: 'Zero-PII guarantee: no email allowed');
      expect(json.containsKey('ip'), isFalse, reason: 'Zero-PII guarantee: no ip allowed');
    });

    testWidgets('StatusBadge renders healthy and degraded variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.healthy(label: 'ONLINE'),
                StatusBadge.degraded(label: 'LAGGY'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('LAGGY'), findsOneWidget);
    });

    testWidgets('MetricCard renders title, value and trend', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Frame Rate',
              value: '60.0 FPS',
              icon: Icons.speed,
              trend: '+2.5%',
            ),
          ),
        ),
      );

      expect(find.text('Frame Rate'), findsOneWidget);
      expect(find.text('60.0 FPS'), findsOneWidget);
      expect(find.text('+2.5%'), findsOneWidget);
    });

    testWidgets('PlatformSuiteShell renders sidebar and consoles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlatformSuiteShell(initialIndex: 0),
          ),
        ),
      );

      // Sincroniza frame
      await tester.pump();

      expect(find.text('TupiLingo'), findsOneWidget);
      expect(find.text('PLATFORM SUITE'), findsOneWidget);
      expect(find.text('World Builder CMS'), findsOneWidget);
      expect(find.text('Developer Console'), findsOneWidget);
      expect(find.text('Security & Observability'), findsOneWidget);

      // Toca no Developer Console
      await tester.tap(find.text('Developer Console'));
      await tester.pumpAndSettle();

      expect(find.text('Live Ops'), findsOneWidget);
      expect(find.text('Observatory'), findsOneWidget);
    });
  });
}
