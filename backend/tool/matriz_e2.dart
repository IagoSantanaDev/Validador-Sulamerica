import 'dart:async';

import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

import 'matriz_dados.dart';

typedef FabricaSessaoE2 = SessaoPortal Function();

Future<List<ResultadoMatriz>> executarE2Independente({
  required CredenciaisPortal credenciais,
  required ConsultaMatriz consulta,
  required FabricaSessaoE2 fabricaSessao,
}) async {
  if (consulta.tipo != 'elegibilidade') {
    throw const FormatException('E2 requer uma consulta de elegibilidade.');
  }

  final List<ResultadoMatriz> resultados = <ResultadoMatriz>[];
  int proximoUsuario = 0;
  for (final int quantidade in <int>[2, 4]) {
    final List<SessaoPortal> sessoes = List<SessaoPortal>.generate(
      quantidade,
      (_) => fabricaSessao(),
      growable: false,
    );
    final List<int> usuarios = List<int>.generate(
      quantidade,
      (_) => ++proximoUsuario,
      growable: false,
    );
    try {
      final bool primeiraAutenticada = await _loginE2(
        sessoes.first,
        credenciais,
        quantidade,
        usuarios.first,
        resultados,
      );
      if (!primeiraAutenticada) continue;

      await _consultarE2(
        sessoes.first,
        consulta,
        quantidade,
        usuarios.first,
        'e2_antes_${quantidade}_sessoes',
        resultados,
      );

      for (int indice = 1; indice < quantidade; indice++) {
        await _loginE2(
          sessoes[indice],
          credenciais,
          quantidade,
          usuarios[indice],
          resultados,
        );
      }

      await _consultarE2(
        sessoes.first,
        consulta,
        quantidade,
        usuarios.first,
        'e2_depois_${quantidade}_sessoes',
        resultados,
      );
    } finally {
      await Future.wait<void>(
        sessoes.map((SessaoPortal sessao) => sessao.encerrar()),
      );
    }
  }
  return resultados;
}

Future<bool> _loginE2(
  SessaoPortal sessao,
  CredenciaisPortal credenciais,
  int quantidade,
  int usuario,
  List<ResultadoMatriz> resultados,
) async {
  final Stopwatch relogio = Stopwatch()..start();
  final ResultadoLogin login = await sessao.login(
    code: credenciais.code,
    user: credenciais.user,
    senha: credenciais.senha,
  );
  relogio.stop();
  resultados.add(
    ResultadoMatriz(
      usuario: usuario,
      indice: quantidade,
      tipo: 'sessao_e2_${quantidade}_independente',
      sucesso: login.autenticada,
      latenciaMs: relogio.elapsedMilliseconds,
      statusHttp: null,
      erro: login.autenticada ? null : 'login_${login.motivo?.name ?? 'falha'}',
      origem502: null,
    ),
  );
  return login.autenticada;
}

Future<void> _consultarE2(
  SessaoPortal sessao,
  ConsultaMatriz consulta,
  int quantidade,
  int usuario,
  String tipoResultado,
  List<ResultadoMatriz> resultados,
) async {
  final Stopwatch relogio = Stopwatch()..start();
  final ResultadoConsultaPortal<String> resposta =
      await sessao.consultarBeneficiario(
    carteirinhaCompleta: consulta.chave,
    recuperarFalhaSessao: false,
  );
  relogio.stop();
  resultados.add(
    ResultadoMatriz(
      usuario: usuario,
      indice: quantidade,
      tipo: tipoResultado,
      sucesso: resposta.sucesso,
      latenciaMs: relogio.elapsedMilliseconds,
      statusHttp: resposta.status,
      erro: resposta.sucesso ? null : _erroSeguro(resposta),
      origem502: null,
    ),
  );
}

String _erroSeguro<T>(ResultadoConsultaPortal<T> resposta) =>
    switch (resposta.categoria) {
      CategoriaFalhaConsultaPortal.sessao =>
        'sessao_http_${resposta.status ?? 'sem_status'}',
      CategoriaFalhaConsultaPortal.transporte => 'falha_transporte',
      CategoriaFalhaConsultaPortal.http =>
        'http_${resposta.status ?? 'sem_status'}',
      CategoriaFalhaConsultaPortal.respostaInesperada => 'resposta_inesperada',
      CategoriaFalhaConsultaPortal.cancelada => 'cancelada',
      null => 'consulta_falhou',
    };
