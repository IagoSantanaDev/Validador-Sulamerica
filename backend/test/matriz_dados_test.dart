import 'package:test/test.dart';
import '../tool/matriz_dados.dart';

void main() {
  const String xml = '''
<ans:mensagemTISS xmlns:ans="urn:tiss">
  <ans:cabecalho><ans:origem><ans:identificacaoPrestador>
    <ans:CNPJ>27372066000169</ans:CNPJ>
  </ans:identificacaoPrestador></ans:origem></ans:cabecalho>
  <ans:guiaSP-SADT>
    <ans:dadosBeneficiario><ans:numeroCarteira>00000000000000000001</ans:numeroCarteira></ans:dadosBeneficiario>
    <ans:dadosAutorizacao><ans:senha>5000000001</ans:senha></ans:dadosAutorizacao>
  </ans:guiaSP-SADT>
  <ans:guiaSP-SADT>
    <ans:dadosBeneficiario><ans:numeroCarteira>00000000000000000001</ans:numeroCarteira></ans:dadosBeneficiario>
    <ans:dadosAutorizacao><ans:senha>5000000002</ans:senha></ans:dadosAutorizacao>
  </ans:guiaSP-SADT>
</ans:mensagemTISS>
''';

  test('extrai dados TISS por namespace e elimina duplicatas', () {
    final List<ConsultaMatriz> consultas = extrairConsultasXml(xml);

    expect(extrairIdentificadorPrestadorXml(xml), '27372066000169');
    expect(consultas, hasLength(3));
    expect(
      consultas.map((ConsultaMatriz item) => item.tipo),
      <String>['elegibilidade', 'senha', 'senha'],
    );
    expect(consultas.first.chave, '00000000000000000001');
  });

  test('interpreta eventos SSE JSON', () {
    final List<Map<String, dynamic>> eventos = extrairEventosSse(
      'event: progresso\ndata: {"concluidas":1}\n\n'
      'event: resultado\ndata: {"status":"ok"}\n\n',
    );

    expect(eventos, hasLength(2));
    expect(eventos.last['event'], 'resultado');
    expect((eventos.last['data'] as Map)['status'], 'ok');
  });

  test('CSV escapa aspas e não precisa serializar consulta ou token', () {
    final String csv = codificarCsv(<ResultadoMatriz>[
      const ResultadoMatriz(
        usuario: 2,
        indice: 1,
        tipo: 'lote',
        sucesso: false,
        latenciaMs: 120,
        statusHttp: 502,
        erro: 'bad "gateway"',
        origem502: 'indeterminada',
      ),
    ]);

    expect(csv, contains('usuario,indice,tipo'));
    expect(csv, contains('"bad ""gateway"""'));
    expect(csv, isNot(contains('token')));
  });
}
