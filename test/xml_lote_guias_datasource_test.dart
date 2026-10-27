import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/xml_lote_guias_datasource.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/xml_lote_guias_exceptions.dart';

void main() {
  const XmlLoteGuiasDatasource datasource = XmlLoteGuiasDatasource();

  group('XmlLoteGuiasDatasource', () {
    test('extrai metadados e múltiplas guias do mesmo documento ans', () {
      const String xml = '''
<ans:mensagemTISS xmlns:ans="urn:ans">
  <ans:cabecalho>
    <ans:identificacaoTransacao><ans:tipoTransacao>ENVIO_LOTE</ans:tipoTransacao></ans:identificacaoTransacao>
    <ans:Padrao>4.01.00</ans:Padrao>
    <ans:origem><ans:CNPJ>12345678000199</ans:CNPJ></ans:origem>
    <ans:destino><ans:registroANS>999999</ans:registroANS></ans:destino>
  </ans:cabecalho>
  <ans:loteGuias>
    <ans:numeroLote>LOTE-42</ans:numeroLote>
    <ans:guiasTISS>
      <ans:guiaSP-SADT>
        <ans:cabecalhoGuia><ans:numeroGuiaPrestador>G-1</ans:numeroGuiaPrestador></ans:cabecalhoGuia>
        <ans:dadosBeneficiario><ans:numeroCarteira> 00123 </ans:numeroCarteira></ans:dadosBeneficiario>
        <ans:dadosAutorizacao><ans:senha> 5000000001 </ans:senha></ans:dadosAutorizacao>
        <ans:valorTotalGuia>10.00</ans:valorTotalGuia>
        <ans:procedimentosExecutados><ans:procedimentoExecutado>
          <ans:procedimento><ans:codigoProcedimento>0040301281</ans:codigoProcedimento><ans:codigoTabela> 22 </ans:codigoTabela></ans:procedimento>
          <ans:quantidadeExecutada>2</ans:quantidadeExecutada>
        </ans:procedimentoExecutado></ans:procedimentosExecutados>
      </ans:guiaSP-SADT>
      <ans:guiaSP-SADT>
        <ans:cabecalhoGuia><ans:numeroGuiaPrestador>G-2</ans:numeroGuiaPrestador></ans:cabecalhoGuia>
        <ans:valorTotalGuia>20.00</ans:valorTotalGuia>
      </ans:guiaSP-SADT>
    </ans:guiasTISS>
    <ans:valorTotalGeral>30.00</ans:valorTotalGeral>
  </ans:loteGuias>
</ans:mensagemTISS>
''';

      final lote = datasource.extrairLote(xml);

      expect(lote.informacoes.versao, '4.01.00');
      expect(lote.informacoes.tipoTransacao, 'ENVIO_LOTE');
      expect(lote.informacoes.prestadorCnpjCpf, '12345678000199');
      expect(lote.informacoes.operadoraRegistroANS, '999999');
      expect(lote.informacoes.numeroLote, 'LOTE-42');
      expect(lote.informacoes.qtdGuias, lote.guias.length);
      expect(lote.informacoes.qtdGuias, 2);
      expect(lote.informacoes.valorTotalInformado, '30.00');
      expect(
        lote.guias.map((guia) => guia.numeroGuiaPrestador),
        ['G-1', 'G-2'],
      );
      expect(lote.guias.first.numeroCarteira, ' 00123 ');
      expect(lote.guias.first.senha, ' 5000000001 ');
      expect(lote.guias.first.procedimentos.single.codigo, '0040301281');
      expect(lote.guias.first.procedimentos.single.codigoTabela, '22');
      expect(lote.guias.first.procedimentos.single.quantidade, 2);
    });

    test('mantém codigoTabela nulo quando o XML não informa', () {
      const String xml = '''
<mensagemTISS>
  <guiaSP-SADT>
    <procedimentosExecutados><procedimentoExecutado>
      <procedimento><codigoProcedimento>30101492</codigoProcedimento></procedimento>
    </procedimentoExecutado></procedimentosExecutados>
  </guiaSP-SADT>
</mensagemTISS>
''';

      final procedimento =
          datasource.extrairLote(xml).guias.single.procedimentos.single;

      expect(procedimento.codigo, '30101492');
      expect(procedimento.codigoTabela, isNull);
    });

    test('extrai guia com prefixo tiss e preserva valores literais', () {
      const String xml = '''
<tiss:mensagemTISS xmlns:tiss="urn:tiss">
  <tiss:guiaSP-SADT>
    <tiss:cabecalhoGuia><tiss:numeroGuiaPrestador> 0007 </tiss:numeroGuiaPrestador></tiss:cabecalhoGuia>
    <tiss:dadosBeneficiario><tiss:numeroCarteira> 000123 </tiss:numeroCarteira></tiss:dadosBeneficiario>
  </tiss:guiaSP-SADT>
</tiss:mensagemTISS>
''';

      final guia = datasource.extrairLote(xml).guias.single;

      expect(guia.numeroGuiaPrestador, '0007');
      expect(guia.numeroCarteira, ' 000123 ');
    });

    test('aceita namespace default', () {
      const String xml = '''
<mensagemTISS xmlns="urn:tiss">
  <guiaSP-SADT>
    <cabecalhoGuia><numeroGuiaPrestador>G-DEFAULT</numeroGuiaPrestador></cabecalhoGuia>
  </guiaSP-SADT>
</mensagemTISS>
''';

      expect(
        datasource.extrairLote(xml).guias.single.numeroGuiaPrestador,
        'G-DEFAULT',
      );
    });

    test('mantém metadados opcionais nulos e distingue lote sem guias', () {
      const String xml =
          '<mensagemTISS><numeroLote>8</numeroLote></mensagemTISS>';

      final informacoes = datasource.extrairInformacoesDoLote(xml);

      expect(informacoes.numeroLote, '8');
      expect(informacoes.qtdGuias, isNull);
      expect(informacoes.valorTotalInformado, isNull);
      expect(
        () => datasource.extrairLote(xml),
        throwsA(isA<NenhumaGuiaEncontradaException>()),
      );
    });

    test('propaga XML malformado em ambas as APIs', () {
      const String xml = '<mensagemTISS><guiaSP-SADT>';

      expect(
        () => datasource.extrairInformacoesDoLote(xml),
        throwsA(isA<XmlMalFormadoException>()),
      );
      expect(
        () => datasource.extrairLote(xml),
        throwsA(isA<XmlMalFormadoException>()),
      );
    });
  });
}
