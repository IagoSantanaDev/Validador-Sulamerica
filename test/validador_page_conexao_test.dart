import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:validador_xml_sulamerica/globals/constants/app_strings.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/pages/validador_page.dart';

void main() {
  testWidgets('API indisponível não bloqueia a seleção de XML', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ValidadorPage()));
    await tester.pump();

    expect(find.text(AppStrings.apiIndisponivelTitulo), findsOneWidget);
    expect(find.text(AppStrings.apiTentarNovamente), findsOneWidget);
    expect(find.text(AppStrings.dropZoneTexto), findsOneWidget);
  });
}
