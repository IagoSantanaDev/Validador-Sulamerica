import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository_impl.dart';

String _xmlGuia({
  String? dataAutorizacao,
  required String procedimentos,
}) =>
    '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>001</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosAutorizacao>
            ${dataAutorizacao == null ? '' : '<ans:dataAutorizacao>$dataAutorizacao</ans:dataAutorizacao>'}
            <ans:senha>5056430843</ans:senha>
          </ans:dadosAutorizacao>
          <ans:procedimentosExecutados>
            $procedimentos
          </ans:procedimentosExecutados>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

String _procedimento(String codigo, {String? dataExecucao}) => '''
<ans:procedimentoExecutado>
  ${dataExecucao == null ? '' : '<ans:dataExecucao>$dataExecucao</ans:dataExecucao>'}
  <ans:procedimento>
    <ans:codigoProcedimento>$codigo</ans:codigoProcedimento>
  </ans:procedimento>
  <ans:quantidadeExecutada>1</ans:quantidadeExecutada>
</ans:procedimentoExecutado>
''';

void main() {
  final repository = ValidadorGuiasRepositoryImpl();

  test('aceita autorização anterior à execução', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: '2026-10-01',
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-14'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });

  test('aceita autorização no mesmo dia da execução', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: '2026-10-14',
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-14'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });

  test('acusa autorização posterior à execução', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: '2026-10-14',
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-01'),
      ),
    );

    expect(resultado.single.temErro, isTrue);
    expect(resultado.single.erros.single.campo, 'dataAutorizacao');
    expect(
      resultado.single.erros.single.mensagem,
      'Data de autorização (2026-10-14) posterior à execução (2026-10-01)',
    );
  });

  test('agrega execuções anteriores sem repetir datas', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: '2026-10-14',
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-01') +
            _procedimento('40301397', dataExecucao: '2026-10-05') +
            _procedimento('40301400', dataExecucao: '2026-10-01') +
            _procedimento('40301419', dataExecucao: '2026-10-20'),
      ),
    );

    expect(
      resultado.single.erros.single.mensagem,
      'Data de autorização (2026-10-14) posterior à execução '
      '(2026-10-01, 2026-10-05)',
    );
  });

  test('ignora guia sem dataAutorizacao', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-01'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });

  test('ignora procedimento sem dataExecucao', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: '2026-10-14',
        procedimentos: _procedimento('40301281'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });

  test('ignora datas inválidas', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        dataAutorizacao: 'INVALIDA',
        procedimentos: _procedimento('40301281', dataExecucao: '2026-10-01'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });
}
