import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/select_level_screen.dart';

void main() {
  testWidgets('SelectLevelScreen renders levels and options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeVariante = {
      'id': 1,
      'nome': 'Tupi Antigo',
      'icone': '🌿',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: SelectLevelScreen(variante: fakeVariante),
      ),
    );

    expect(find.text('Qual seu nível em Tupi Antigo?'), findsOneWidget);
    expect(find.text('Novo por aqui'), findsOneWidget);
    expect(find.text('Iniciante'), findsOneWidget);
    expect(find.text('Intermediário'), findsOneWidget);
    expect(find.text('Avançado'), findsOneWidget);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });
}
