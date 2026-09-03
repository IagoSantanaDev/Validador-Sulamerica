import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository_impl.dart';

const String _xmlComCarteiraInvalida = '''
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
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

const String _xmlComCarteiraValida = '''
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
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

const String _xmlSemNumeroCarteira = '''
<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">
  <ans:prestadorParaOperadora>
    <ans:loteGuias>
      <ans:guiasTISS>
        <ans:guiaSP-SADT>
          <ans:cabecalhoGuia>
            <ans:numeroGuiaPrestador>333</ans:numeroGuiaPrestador>
          </ans:cabecalhoGuia>
          <ans:dadosBeneficiario>
          </ans:dadosBeneficiario>
        </ans:guiaSP-SADT>
      </ans:guiasTISS>
    </ans:loteGuias>
  </ans:prestadorParaOperadora>
</ans:mensagemTISS>
''';

void main() {
  group('ValidadorGuiasRepositoryImpl - regra numeroCarteira', () {
    final ValidadorGuiasRepositoryImpl repository =
        ValidadorGuiasRepositoryImpl();

    test('marca erro quando numeroCarteira não começa com 5', () {
      final resultado = repository.validarLote(_xmlComCarteiraInvalida);

      expect(resultado, hasLength(1));
      expect(resultado.first.temErro, isTrue);
      expect(
        resultado.first.erros.single.mensagem,
        contains('deve começar com 5'),
      );
    });

    test('não marca erro quando numeroCarteira começa com 5', () {
      final resultado = repository.validarLote(_xmlComCarteiraValida);

      expect(resultado.single.temErro, isFalse);
    });

    test('marca erro quando numeroCarteira não está presente', () {
      final resultado = repository.validarLote(_xmlSemNumeroCarteira);

      expect(resultado.single.temErro, isTrue);
      expect(
        resultado.single.erros.single.mensagem,
        contains('não informado'),
      );
    });
  });
}
