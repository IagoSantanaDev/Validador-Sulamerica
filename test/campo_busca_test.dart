import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/widgets/campo_busca.dart';

void main() {
  Widget monta(TextEditingController controller) {
    return MaterialApp(
      home: Scaffold(
        body: CampoBusca(controller: controller, total: 7, dica: 'Buscar'),
      ),
    );
  }

  testWidgets('mostra a dica quando o campo está vazio', (tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(monta(controller));

    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('digitar mostra o botão de limpar e atualiza o total', (
    tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(monta(controller));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.byIcon(Icons.cancel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}