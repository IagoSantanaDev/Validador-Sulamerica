import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

import '../tool/matriz_dados.dart';
import '../tool/matriz_e2.dart';

class _ContaSimulada {
  final List<bool> sessaoValida = <bool>[];
  int encerradas = 0;
  final List<bool> recuperacoesSolicitadas = <bool>[];
}

class _SessaoE2Fake extends SessaoPortal {
  _SessaoE2Fake(this.conta)
      : indice = conta.sessaoValida.length,
        super(logger: Logger(level: Level.off)) {
    conta.sessaoValida.add(false);
  }

  final _ContaSimulada conta;
  final int indice;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    for (int i = 0; i < conta.sessaoValida.length; i++) {
      conta.sessaoValida[i] = false;
    }
    conta.sessaoValida[indice] = true;
    return const ResultadoLogin.autenticado();
  }

  @override
  Future<ResultadoConsultaPortal<String>> consultarBeneficiario({
    required String carteirinhaCompleta,
    CancelToken? cancelToken,
    bool recuperarFalhaSessao = true,
  }) async {
    conta.recuperacoesSolicitadas.add(recuperarFalhaSessao);
    if (!conta.sessaoValida[indice]) {
      return const ResultadoConsultaPortal<String>.falha(
        categoria: CategoriaFalhaConsultaPortal.sessao,
        status: 401,
      );
    }
    return const ResultadoConsultaPortal<String>.sucesso(
      dados: '<html>elegivel</html>',
      status: 200,
    );
  }

  @override
  Future<void> encerrar() async {
    conta.encerradas++;
  }
}

CredenciaisPortal _credenciais() => CredenciaisPortal.resolver(
      'teste',
      ambiente: const <String, String>{
        'PORTAL_PRESTADOR_ID_TESTE_CODE': 'code',
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'user',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'password',
      },
    )!;

void main() {
  test('E2 usa logins independentes e não renova a sessão observada', () async {
    final _ContaSimulada conta = _ContaSimulada();
    final List<ResultadoMatriz> resultados = await executarE2Independente(
      credenciais: _credenciais(),
      consulta: const ConsultaMatriz(
        tipo: 'elegibilidade',
        chave: '12345678901234567890',
      ),
      fabricaSessao: () => _SessaoE2Fake(conta),
    );
    final Map<String, ResultadoMatriz> sondas = <String, ResultadoMatriz>{
      for (final ResultadoMatriz resultado in resultados)
        if (resultado.tipo.startsWith('e2_')) resultado.tipo: resultado,
    };

    expect(sondas['e2_antes_2_sessoes']?.sucesso, isTrue);
    expect(sondas['e2_depois_2_sessoes']?.sucesso, isFalse);
    expect(sondas['e2_depois_2_sessoes']?.statusHttp, 401);
    expect(sondas['e2_antes_4_sessoes']?.sucesso, isTrue);
    expect(sondas['e2_depois_4_sessoes']?.sucesso, isFalse);
    expect(sondas['e2_depois_4_sessoes']?.statusHttp, 401);
    expect(conta.sessaoValida, hasLength(6));
    expect(conta.encerradas, 6);
    expect(conta.recuperacoesSolicitadas, everyElement(isFalse));
  });

  test('E2 rejeita cenário sem consulta de elegibilidade', () async {
    await expectLater(
      executarE2Independente(
        credenciais: _credenciais(),
        consulta: const ConsultaMatriz(tipo: 'senha', chave: '5000000000'),
        fabricaSessao: () => _SessaoE2Fake(_ContaSimulada()),
      ),
      throwsFormatException,
    );
  });
}
