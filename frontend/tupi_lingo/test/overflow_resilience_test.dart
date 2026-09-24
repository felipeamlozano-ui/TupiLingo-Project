import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/platform_suite_shell.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/developer_console/developer_console_screen.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/security_console/security_console_screen.dart';
import 'package:tupi_lingo/features/admin/presentation/platform_suite/world_builder/world_builder_screen.dart';
import 'package:tupi_lingo/features/dashboard/presentation/widgets/mastery_radar_chart.dart';
import 'package:tupi_lingo/features/historical_map/domain/services/curriculum_world_graph.dart';
import 'package:tupi_lingo/features/historical_map/presentation/widgets/historical_timeline_slider.dart';
import 'package:tupi_lingo/features/historical_map/presentation/widgets/pindorama_expressive_hud.dart';

void main() {
  group('UI Overflow Resilience Tests', () {
    testWidgets('MasteryRadarChart renders safely in narrow width without overflow', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: MasteryRadarChart(
                dimensions: MasteryRadarChart.defaultDimensions,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Domínio Multidimensional'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow should occur');
    });

    testWidgets('PindoramaExpressiveHud pill renders without overflow with long names on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final baseTerritory = CurriculumWorldGraph().allTerritories.first;
      final territory = baseTerritory.copyWith(
        name: 'Planalto de Piratininga Extremo e Aldeamentos Circunvizinhos de Grande Extensão',
        primaryDialect: 'Tupi Paulista Antigo e Suas Múltiplas Ramificações Históricas',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PindoramaExpressiveHud(
              currentTerritory: territory,
              currentEpoch: HistoricalEpoch.pre1500,
              onBack: () {},
              onRecenter: () {},
              onToggleQuests: () {},
              onOpenNarrative: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Planalto de Piratininga Extremo e Aldeamentos Circunvizinhos de Grande Extensão'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Top pill must truncate smoothly with ellipsis and not overflow');
    });
    testWidgets('WorldBuilderScreen renders cleanly on mobile screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: WorldBuilderScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in WorldBuilderScreen');
    });

    testWidgets('DeveloperConsoleScreen renders cleanly on mobile screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: DeveloperConsoleScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in DeveloperConsoleScreen');
    });

    testWidgets('SecurityConsoleScreen renders cleanly on mobile screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SecurityConsoleScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in SecurityConsoleScreen');
    });

    testWidgets('PlatformSuiteShell renders cleanly on mobile screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlatformSuiteShell(initialIndex: 2),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in PlatformSuiteShell on mobile');
    });

    testWidgets('PlatformSuiteShell renders cleanly on desktop screen (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlatformSuiteShell(initialIndex: 0),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in PlatformSuiteShell on desktop');
    });
  });
}
