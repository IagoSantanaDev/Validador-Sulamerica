import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository_impl.dart';

String _xmlGuia({required String procedimentos}) => '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>001</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosAutorizacao>
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

String _procedimento(String codigo, {String quantidade = '1'}) => '''
<ans:procedimentoExecutado>
  <ans:procedimento>
    <ans:codigoProcedimento>$codigo</ans:codigoProcedimento>
  </ans:procedimento>
  <ans:quantidadeExecutada>$quantidade</ans:quantidadeExecutada>
</ans:procedimentoExecutado>
''';

void main() {
  final repository = ValidadorGuiasRepositoryImpl();

  test('aceita bilateral com quantidade 1', () {
    final resultado = repository.validarLote(
      _xmlGuia(procedimentos: _procedimento('40901360')),
    );

    expect(resultado.single.guia.procedimentos.single.quantidade, 1);
    expect(resultado.single.erros, isEmpty);
  });

  test('marca código bilateral com quantidade 2', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        procedimentos: _procedimento('40901360', quantidade: '2'),
      ),
    );

    expect(resultado.single.temErro, isTrue);
    expect(
      resultado.single.erros.single.mensagem,
      'Código Bilateral (40901360)',
    );
    expect(resultado.single.erros.single.campo, 'procedimentos');
  });

  test('marca todos os 16 códigos bilaterais quando quantidade maior que 1',
      () {
    const codigos = [
      '40103269',
      '40103609',
      '40201058',
      '40708063',
      '40801047',
      '40801055',
      '40801110',
      '40808033',
      '40808041',
      '40901025',
      '40901360',
      '40901378',
      '41101073',
      '41101081',
      '41101103',
      '41101480',
    ];

    for (final codigo in codigos) {
      final resultado = repository.validarLote(
        _xmlGuia(procedimentos: _procedimento(codigo, quantidade: '2')),
      );
      expect(
        resultado.single.erros.single.mensagem,
        'Código Bilateral ($codigo)',
      );
    }
  });

  test('não marca código não bilateral mesmo com quantidade maior que 1', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        procedimentos: _procedimento('99999999', quantidade: '5'),
      ),
    );

    expect(resultado.single.erros, isEmpty);
  });

  test('retorna o primeiro bilateral repetido na ordem do XML', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        procedimentos: _procedimento('40103269', quantidade: '1') +
            _procedimento('40901360', quantidade: '2') +
            _procedimento('41101073', quantidade: '2'),
      ),
    );

    expect(resultado.single.erros, hasLength(1));
    expect(
      resultado.single.erros.single.mensagem,
      'Código Bilateral (40901360)',
    );
  });

  test('assume quantidade 1 quando quantidadeExecutada está ausente', () {
    const procedimento = '''
<ans:procedimentoExecutado>
  <ans:procedimento>
    <ans:codigoProcedimento>40901360</ans:codigoProcedimento>
  </ans:procedimento>
</ans:procedimentoExecutado>
''';

    final resultado = repository.validarLote(
      _xmlGuia(procedimentos: procedimento),
    );

    expect(resultado.single.guia.procedimentos.single.quantidade, 1);
    expect(resultado.single.erros, isEmpty);
  });

  test('assume quantidade 1 quando quantidadeExecutada não é numérica', () {
    final resultado = repository.validarLote(
      _xmlGuia(
        procedimentos: _procedimento('40901360', quantidade: 'INVALIDO'),
      ),
    );

    expect(resultado.single.guia.procedimentos.single.quantidade, 1);
    expect(resultado.single.erros, isEmpty);
  });
}
