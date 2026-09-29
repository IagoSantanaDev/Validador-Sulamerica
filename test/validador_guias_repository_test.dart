import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository_impl.dart';

const String _xmlComSenhaInvalida = '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>111</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosBeneficiario>
            <ans:numeroCarteira>42509512809910100031</ans:numeroCarteira>
            <ans:senha>4250951280</ans:senha>
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

const String _xmlComSenhaValida = '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>222</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosBeneficiario>
            <ans:numeroCarteira>55788888482319470020</ans:numeroCarteira>
            <ans:senha>5056430843</ans:senha>
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

const String _xmlSemSenha = '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>333</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosBeneficiario>
            <ans:numeroCarteira>55788888482319470020</ans:numeroCarteira>
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

void main() {
  group('ValidadorGuiasRepositoryImpl - regra senha', () {
    final ValidadorGuiasRepositoryImpl repository =
        ValidadorGuiasRepositoryImpl();

    test('marca erro quando senha não começa com 5', () {
      final resultado = repository.validarLote(_xmlComSenhaInvalida);

      expect(resultado, hasLength(1));
      expect(resultado.first.temErro, isTrue);
      expect(
        resultado.first.erros.single.mensagem,
        contains('deve começar com 5'),
      );
    });

    test('não marca erro quando senha começa com 5', () {
      final resultado = repository.validarLote(_xmlComSenhaValida);

      expect(resultado.single.temErro, isFalse);
    });

    test('marca erro quando senha não está presente', () {
      final resultado = repository.validarLote(_xmlSemSenha);

      expect(resultado.single.temErro, isTrue);
      expect(resultado.single.erros.single.campo, 'senha');
      expect(
        resultado.single.erros.single.mensagem,
        contains('não informada'),
      );
    });

    test('marca erro quando senha não tem exatamente dez caracteres', () {
      final String xml = _xmlComSenhaValida.replaceFirst(
        '5056430843',
        '50564308431',
      );
      final resultado = repository.validarLote(xml);

      expect(resultado.single.temErro, isTrue);
      expect(
        resultado.single.erros.single.mensagem,
        contains('exatamente 10'),
      );
    });

    test('valida senha com dez caracteres começando com 5', () {
      final String xml = _xmlComSenhaValida.replaceFirst(
        '5056430843',
        '5234567890',
      );
      final resultado = repository.validarLote(xml);

      expect(resultado.single.temErro, isFalse);
    });

    test(
        'rejeita letras, pontuação, espaços, dígitos Unicode e tamanho inválido',
        () {
      for (final String senha in [
        '5ABCDEFGHI',
        '5!23456789',
        ' 500000000',
        '5000000000 ',
        '5\u06600000000',
        '505643084',
        '50564308431',
      ]) {
        final String xml = _xmlComSenhaValida.replaceFirst(
          '5056430843',
          senha,
        );
        final resultado = repository.validarLote(xml);

        expect(
          resultado.single.erros.any((erro) => erro.campo == 'senha'),
          isTrue,
          reason: 'A senha $senha deve ser rejeitada',
        );
      }
    });

    test('preserva carteira e senha exatamente como aparecem no XML', () {
      const String carteiraLiteral = ' 557888884823194700 20 ';
      const String senhaLiteral = ' 5056430843 ';
      final String xml = _xmlComSenhaValida
          .replaceFirst('55788888482319470020', carteiraLiteral)
          .replaceFirst('5056430843', senhaLiteral);

      final resultado = repository.validarLote(xml);

      expect(resultado.single.guia.numeroCarteira, carteiraLiteral);
      expect(resultado.single.guia.senha, senhaLiteral);
    });
  });
}
