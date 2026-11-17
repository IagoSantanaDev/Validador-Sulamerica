import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:validador_xml_sulamerica/globals/constants/app_colors.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/widgets/barra_progresso_envio.dart';

void main() {
  testWidgets('exibe etapa e progresso indeterminado acessível', (
    WidgetTester tester,
  ) async {
    const String etapa = 'Consultando SulAmérica...';
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BarraProgressoEnvio(textoEtapa: etapa),
        ),
      ),
    );

    expect(find.text(etapa), findsOneWidget);
    final LinearProgressIndicator indicador =
        tester.widget(find.byType(LinearProgressIndicator));
    expect(indicador.value, isNull);
    expect(indicador.color, AppColors.petroleo);
    expect(indicador.backgroundColor, AppColors.track);
    expect(find.bySemanticsLabel(etapa), findsOneWidget);

    semantics.dispose();
  });
}
