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
import 'package:tupi_lingo/features/store/presentation/store_screen.dart';

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

    testWidgets('StoreScreen renders cleanly on mobile screen (360x640) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: StoreScreen(initialConchas: 33),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica título e badge de conchas
      expect(find.text('Oca das Trocas & Conchas'), findsOneWidget);
      expect(find.text('33'), findsOneWidget);

      // Verifica abas
      expect(find.text('Temas'), findsOneWidget);
      expect(find.text('Avatares & Molduras'), findsOneWidget);
      expect(find.text('Lições'), findsOneWidget);

      // Verifica que itens aparecem na aba inicial (Temas)
      expect(find.text('Floresta de Jade'), findsOneWidget);
      expect(find.text('Areia Sagrada de Pindorama'), findsOneWidget);

      // Navega para aba de Avatares & Molduras
      await tester.tap(find.text('Avatares & Molduras'));
      await tester.pumpAndSettle();
      expect(find.text('Arara Canindé'), findsOneWidget);
      expect(find.text('Guerreiro Maraká'), findsOneWidget);

      // Navega para aba de Lições
      await tester.tap(find.text('Lições'));
      await tester.pumpAndSettle();
      expect(find.text('Cantos Sagrados dos Pajés'), findsOneWidget);

      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in StoreScreen on mobile');
    });

    testWidgets('StoreScreen renders cleanly on narrow screen (320x600) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: StoreScreen(initialConchas: 150),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Oca das Trocas & Conchas'), findsOneWidget);
      expect(find.text('Temas'), findsOneWidget);
      expect(find.text('Avatares & Molduras'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow in StoreScreen on narrow screen');
    });

    testWidgets('Thematic practice question header badges render on narrow screen (320x600) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Múltipla Escolha',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology_rounded, size: 13, color: Color(0xFF0E5D4E)),
                            SizedBox(width: 4),
                            Text(
                              'Reforço Inteligente',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Questão 1 de 5',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Múltipla Escolha'), findsOneWidget);
      expect(find.text('Reforço Inteligente'), findsOneWidget);
      expect(find.text('Questão 1 de 5'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on narrow device');
    });
  });
}

