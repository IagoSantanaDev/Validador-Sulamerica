import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/themes/app_theme.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/widgets/erro_guia_card.dart';

/// DropzoneView (usado em ValidadorPage) só funciona no target web, então
/// os widget tests aqui cobrem os widgets de resultado isoladamente, sem
/// montar a árvore inteira do app — evita falhas de platform view ao
/// rodar `flutter test` na VM.
void main() {
  Widget montarComTema(Widget filho) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: filho),
    );
  }

  testWidgets('ErroGuiaCard mostra número da guia e mensagem de erro', (
    WidgetTester tester,
  ) async {
    const GuiaValidada guiaComErro = GuiaValidada(
      guia: GuiaTiss(
        numeroGuiaPrestador: '111',
        numeroCarteira: '42509512809910100031',
        senha: null,
      ),
      erros: [
        ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
      ],
    );

    await tester.pumpWidget(
      montarComTema(
        const ErroGuiaCard(
          guiaValidada: guiaComErro,
          corDoGrupo: Colors.white,
          primeiraDaSequencia: true,
        ),
      ),
    );

    expect(find.text('Guia: 111'), findsOneWidget);
    expect(find.text('• senha não informada'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('ErroGuiaCard mostra ícone de sucesso quando não há erro', (
    WidgetTester tester,
  ) async {
    const GuiaValidada guiaValida = GuiaValidada(
      guia: GuiaTiss(
        numeroGuiaPrestador: '222',
        numeroCarteira: '55788888482319470020',
        senha: '5056430843',
      ),
      erros: [],
    );

    await tester.pumpWidget(
      montarComTema(
        const ErroGuiaCard(
          guiaValidada: guiaValida,
          corDoGrupo: Colors.white,
          primeiraDaSequencia: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.textContaining('•'), findsNothing);
  });
}
