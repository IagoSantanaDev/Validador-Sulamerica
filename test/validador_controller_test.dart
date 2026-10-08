import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/controllers/validador_controller.dart';

class _FakeValidadorGuiasRepository implements ValidadorGuiasRepository {
  _FakeValidadorGuiasRepository(this.retorno);

  final List<GuiaValidada> retorno;
  List<GuiaTiss>? guiasValidadas;

  @override
  List<GuiaValidada> validarLote(String conteudoXml) => retorno;

  @override
  List<GuiaValidada> validarGuias(List<GuiaTiss> guias) {
    guiasValidadas = guias;
    return retorno;
  }
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
            ErroValidacao(
              campo: 'senha',
              mensagem: 'senha deve começar com 5',
            ),
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
      bytes: Uint8List.fromList(
        '<mensagemTISS><guiaSP-SADT/></mensagemTISS>'.codeUnits,
      ),
    );
    await controller.validar();
    return controller;
  }

  group('ValidadorController - exibição de erros', () {
    test('preserva metadados do XML extraído com as guias', () async {
      final _FakeValidadorGuiasRepository repository =
          _FakeValidadorGuiasRepository(const [
        GuiaValidada(guia: guiaValida, erros: []),
      ]);
      final ValidadorController controller =
          ValidadorController(repository: repository);
      const String xml = '''
<mensagemTISS>
  <cabecalho>
    <identificacaoTransacao><tipoTransacao>ENVIO_LOTE</tipoTransacao></identificacaoTransacao>
    <Padrao>4.01.00</Padrao>
    <origem><CNPJ>27372066000673</CNPJ></origem>
    <destino><registroANS>999999</registroANS></destino>
  </cabecalho>
  <loteGuias>
    <numeroLote>LOTE-9</numeroLote>
    <valorTotalGeral>10.00</valorTotalGeral>
    <guiaSP-SADT><cabecalhoGuia><numeroGuiaPrestador>222</numeroGuiaPrestador></cabecalhoGuia></guiaSP-SADT>
  </loteGuias>
</mensagemTISS>
''';
      controller.definirArquivo(
        nomeArquivo: 'metadados.xml',
        bytes: Uint8List.fromList(xml.codeUnits),
      );

      await controller.validar();

      expect(controller.informacoes.versao, '4.01.00');
      expect(controller.informacoes.tipoTransacao, 'ENVIO_LOTE');
      expect(controller.informacoes.prestadorCnpjCpf, '27372066000673');
      expect(controller.informacoes.operadoraRegistroANS, '999999');
      expect(controller.informacoes.numeroLote, 'LOTE-9');
      expect(repository.guiasValidadas, hasLength(1));
    });

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
