import 'package:test/test.dart';

import '../tool/matriz_carga.dart'
    show filtrarMetricasResumo, nomeCampoLatenciaResumo, resumoRespostasDominio;
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
    expect(consultas.map((ConsultaMatriz item) => item.tipo), <String>[
      'elegibilidade',
      'senha',
      'senha',
    ]);
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

  test('preserva erro seguro do item sem fabricar falha em sucesso', () {
    expect(
      extrairErroResultadoConsulta(<String, dynamic>{
        'sucesso': false,
        'erro': 'Falha de rede ao acessar o portal SulAmerica.',
      }),
      'Falha de rede ao acessar o portal SulAmerica.',
    );
    expect(
      extrairErroResultadoConsulta(<String, dynamic>{'sucesso': false}),
      'consulta_falhou',
    );
    expect(
      extrairErroResultadoConsulta(<String, dynamic>{'sucesso': true}),
      isNull,
    );
  });

  test('exige resultado de domínio determinado por tipo de consulta', () {
    expect(
      respostaDominioDeterminada('elegibilidade', <String, dynamic>{
        'sucesso': true,
        'elegivel': true,
      }),
      isTrue,
    );
    expect(
      respostaDominioDeterminada('elegibilidade', <String, dynamic>{
        'sucesso': true,
        'elegivel': false,
      }),
      isTrue,
    );
    expect(
      respostaDominioDeterminada('elegibilidade', <String, dynamic>{
        'sucesso': true,
        'elegivel': null,
      }),
      isFalse,
    );
    expect(
      respostaDominioDeterminada('senha', <String, dynamic>{
        'sucesso': true,
        'statusSenha': 'Autorizado',
      }),
      isTrue,
    );
    expect(
      respostaDominioDeterminada('senha', <String, dynamic>{
        'sucesso': true,
        'statusSenha': '  ',
      }),
      isFalse,
    );
    expect(
      respostaDominioDeterminada('senha', <String, dynamic>{
        'sucesso': false,
        'statusSenha': 'Autorizado',
      }),
      isFalse,
    );
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
        dominioDeterminado: false,
      ),
    ]);

    expect(csv, contains('usuario,indice,tipo'));
    expect(csv, contains('dominio_determinado'));
    expect(csv, contains('"bad ""gateway"""'));
    expect(csv, contains('"false"'));
    expect(csv, isNot(contains('token')));
  });

  test(
    'resume respostas de domínio e conta consultas sem resposta como ausentes',
    () {
      final Map<String, Object> resumo = resumoRespostasDominio(
        const <ConsultaMatriz>[
          ConsultaMatriz(tipo: 'elegibilidade', chave: 'x'),
          ConsultaMatriz(tipo: 'senha', chave: 'y'),
        ],
        const <ResultadoMatriz>[
          ResultadoMatriz(
            usuario: 1,
            indice: 1,
            tipo: 'elegibilidade',
            sucesso: true,
            latenciaMs: null,
            statusHttp: 202,
            erro: null,
            origem502: null,
            dominioDeterminado: true,
          ),
          ResultadoMatriz(
            usuario: 1,
            indice: 2,
            tipo: 'senha',
            sucesso: true,
            latenciaMs: null,
            statusHttp: 202,
            erro: null,
            origem502: null,
            dominioDeterminado: false,
          ),
          ResultadoMatriz(
            usuario: 1,
            indice: 3,
            tipo: 'elegibilidade',
            sucesso: true,
            latenciaMs: null,
            statusHttp: 202,
            erro: null,
            origem502: null,
            dominioDeterminado: true,
          ),
        ],
        1,
        4,
      );

      expect(resumo['elegibilidade'], <String, int>{
        'esperadas': 2,
        'determinadas': 2,
        'indeterminadas': 0,
      });
      expect(resumo['senha'], <String, int>{
        'esperadas': 2,
        'determinadas': 0,
        'indeterminadas': 2,
      });
      expect(resumo['total'], <String, int>{
        'esperadas': 4,
        'determinadas': 2,
        'indeterminadas': 2,
      });
    },
  );

  test('resumo E3 inclui sessões e E2 exclui sessões das métricas', () {
    const List<ResultadoMatriz> resultados = <ResultadoMatriz>[
      ResultadoMatriz(
        usuario: 1,
        indice: 1,
        tipo: 'sessao_e3_rajada',
        sucesso: true,
        latenciaMs: 40,
        statusHttp: 201,
        erro: null,
        origem502: null,
      ),
      ResultadoMatriz(
        usuario: 1,
        indice: 1,
        tipo: 'e2_antes_2_sessoes',
        sucesso: true,
        latenciaMs: 50,
        statusHttp: 202,
        erro: null,
        origem502: null,
      ),
      ResultadoMatriz(
        usuario: 0,
        indice: 0,
        tipo: 'lote_resumo',
        sucesso: true,
        latenciaMs: 90,
        statusHttp: 202,
        erro: null,
        origem502: null,
      ),
    ];

    expect(filtrarMetricasResumo('e3', resultados), hasLength(2));
    expect(filtrarMetricasResumo('e2', resultados), hasLength(1));
    expect(
      filtrarMetricasResumo('e2', resultados).single.tipo,
      'e2_antes_2_sessoes',
    );
  });

  test('resumo nomeia a latência conforme o cenário medido', () {
    expect(nomeCampoLatenciaResumo('e2', 'lote'), 'latenciaConsultaMs');
    expect(nomeCampoLatenciaResumo('e3', 'lote'), 'latenciaSessaoMs');
    expect(nomeCampoLatenciaResumo('matriz', 'item'), 'latenciaConsultaMs');
    expect(nomeCampoLatenciaResumo('matriz', 'lote'), 'latenciaLoteMs');
  });
}
