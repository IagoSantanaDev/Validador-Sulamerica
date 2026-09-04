import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/controllers/validador_controller.dart';

/// Repositório falso: devolve um resultado pré-definido, sem parsing.
class _FakeValidadorGuiasRepository implements ValidadorGuiasRepository {
  _FakeValidadorGuiasRepository(this.retorno);

  final List<GuiaValidada> retorno;

  @override
  List<GuiaValidada> validarLote(String conteudoXml) => retorno;
}

void main() {
  const GuiaTiss guiaComErro = GuiaTiss(
    numeroGuiaPrestador: '111',
    numeroCarteira: '42509512809910100031',
    senha: null,
  );
  const GuiaTiss guiaValida = GuiaTiss(
    numeroGuiaPrestador: '222',
    numeroCarteira: '55788888482319470020',
    senha: '5056430843',
  );

  List<GuiaValidada> loteComErroEValida() => const [
        GuiaValidada(
          guia: guiaComErro,
          erros: [
            ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
          ],
        ),
        GuiaValidada(guia: guiaValida, erros: []),
      ];

  Future<ValidadorController> validarLote(
    List<GuiaValidada> retorno,
  ) async {
    final ValidadorController controller =
        ValidadorController(repository: _FakeValidadorGuiasRepository(retorno));
    controller.definirArquivo(
      nomeArquivo: 'lote.xml',
      bytes: Uint8List.fromList('<lote/>'.codeUnits),
    );
    await controller.validar();
    return controller;
  }

  group('ValidadorController - exibição de erros', () {
    test('expõe apenas as guias com erro, apesar do lote completo', () async {
      final ValidadorController controller =
          await validarLote(loteComErroEValida());

      expect(controller.status, StatusValidador.concluido);
      expect(controller.totalGuias, 2);
      expect(controller.totalGuiasComErro, 1);
      expect(controller.guiasComErro, hasLength(1));
      expect(controller.guiasComErro.single.numeroGuiaPrestador, '111');
    });

    test('lote sem erros fica com a lista de erros vazia', () async {
      final ValidadorController controller = await validarLote(
        const [GuiaValidada(guia: guiaValida, erros: [])],
      );

      expect(controller.status, StatusValidador.concluido);
      expect(controller.totalGuias, 1);
      expect(controller.guiasComErro, isEmpty);
    });
  });
}