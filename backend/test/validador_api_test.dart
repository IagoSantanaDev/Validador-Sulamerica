import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show CancelToken;
import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/disjuntor_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/motivo_bloqueio_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/repositorio_sessoes.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';
import 'package:validador_backend/validador_api.dart';

const Map<String, String> _ambiente = <String, String>{
  'PORTAL_PRESTADOR_ID_TESTE_CODE': '000000000000',
  'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario-teste',
  'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha-teste',
  'CORS_ORIGIN': 'https://app.example,https://validador-sulamerica.pages.dev,https://iagosantanadev.github.io',
};

class _LogMudo implements LogOutput {
  const _LogMudo();

  @override
  void output(OutputEvent event) {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> init() async {}
}

class _SessaoFake extends SessaoPortal {
  _SessaoFake({
    this.gate,
    this.loginResult,
    this.beneficiaryResult,
    this.supportIdMarkers = 0,
  }) : super(logger: Logger(level: Level.off));

  final Completer<void>? gate;
  final ResultadoLogin? loginResult;
  final ResultadoConsultaPortal<String>? beneficiaryResult;
  final int supportIdMarkers;
  bool _autenticada = false;
  int logins = 0;
  int consultas = 0;
  final List<CancelToken?> tokensCancelamento = <CancelToken?>[];

  @override
  Map<String, int> get diagnosticoSessao => <String, int>{
    ...super.diagnosticoSessao,
    if (supportIdMarkers > 0) 'assinaturaF5MarkerSupportId': supportIdMarkers,
  };

  @override
  bool get autenticada => _autenticada;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    logins++;
    final ResultadoLogin resultado =
        loginResult ?? const ResultadoLogin.autenticado();
    _autenticada = resultado.autenticada;
    return resultado;
  }

  @override
  Future<ResultadoLogin> garantirAutenticada() async {
    if (_autenticada) return const ResultadoLogin.autenticado();
    return login(code: 'code', user: 'user', senha: 'senha');
  }

  @override
  Future<ResultadoConsultaPortal<String>> consultarBeneficiario({
    required String carteirinhaCompleta,
    CancelToken? cancelToken,
    bool recuperarFalhaSessao = true,
  }) async {
    consultas++;
    tokensCancelamento.add(cancelToken);
    await gate?.future;
    return beneficiaryResult ??
        const ResultadoConsultaPortal<String>.sucesso(
          dados: '<html>elegivel</html>',
          status: 200,
        );
  }

  @override
  Future<ResultadoConsultaPortal<Map<String, dynamic>>> consultarSenha({
    required String senha,
    CancelToken? cancelToken,
  }) async {
    consultas++;
    tokensCancelamento.add(cancelToken);
    await gate?.future;
    return const ResultadoConsultaPortal<Map<String, dynamic>>.sucesso(
      dados: <String, dynamic>{'registros': <dynamic>[]},
      status: 200,
    );
  }

  @override
  Future<void> encerrar() async {}
}

class _ContextoApi {
  _ContextoApi({required this.api, required this.sessoes, required this.gate});

  final ValidadorApi api;
  final List<_SessaoFake> sessoes;
  final Completer<void> gate;
}

_ContextoApi _criarApi({
  int limitePorChave = 100,
  int limiteGlobal = 500,
  int limiteExecucoes = 24,
  int limiteSessoesPorIdentificador = 4,
  RepositorioSessoes? repositorio,
  ResultadoLogin? loginResult,
  ResultadoConsultaPortal<String>? beneficiaryResult,
  DisjuntorPortal? disjuntor,
  Map<String, String> ambiente = _ambiente,
  int supportIdMarkers = 0,
}) {
  final Completer<void> gate = Completer<void>();
  final List<_SessaoFake> sessoes = <_SessaoFake>[];
  final ValidadorApi api = ValidadorApi(
    logger: Logger(output: const _LogMudo(), level: Level.off),
    ambiente: ambiente,
    fabricaSessao: (_) {
      final _SessaoFake sessao = _SessaoFake(
        gate: gate,
        loginResult: loginResult,
        beneficiaryResult: beneficiaryResult,
        supportIdMarkers: supportIdMarkers,
      );
      sessoes.add(sessao);
      return sessao;
    },
    sondaPortal: () async => 200,
    repositorio: repositorio,
    disjuntor: disjuntor,
    limiteRequisicoesPorChave: limitePorChave,
    limiteRequisicoesGlobal: limiteGlobal,
    limiteSessoesPorIdentificador: limiteSessoesPorIdentificador,
    limiteExecucoes: limiteExecucoes,
  );
  return _ContextoApi(api: api, sessoes: sessoes, gate: gate);
}

Request _request(
  String method,
  String path, {
  Object? body,
  String? token,
  String? idempotencyKey,
  Map<String, String>? headers,
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  body: body == null ? null : jsonEncode(body),
  headers: <String, String>{
        if (token != null) 'authorization': 'Bearer $token',
        if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
        ...?headers,
  },
);

Future<String> _criarSessao(ValidadorApi api) async {
  final Response resposta = await api.handler(
    _request(
      'POST',
      '/api/sessoes',
      body: const <String, String>{'identificadorPrestador': 'teste'},
    ),
  );
  expect(resposta.statusCode, 201);
  return (jsonDecode(await resposta.readAsString()) as Map)['token'] as String;
}

Map<String, dynamic> _consulta({String tipo = 'elegibilidade'}) =>
    <String, dynamic>{
      'tipo': tipo,
      'chave': tipo == 'senha' ? '5000000000' : '12345678901234567890',
    };

Future<Response> _criarLote(
  ValidadorApi api,
  String token,
  String key, {
  List<Map<String, dynamic>>? consultas,
}) async => await api.handler(
  _request(
    'POST',
    '/api/lotes',
    token: token,
    idempotencyKey: key,
    body: <String, Object>{
      'consultas': consultas ?? <Map<String, dynamic>>[_consulta()],
    },
  ),
);

void main() {
  group('POST /api/sessoes', () {
    test(
      'cria token lógico opaco e autentica o pool sem autenticação pessoal',
      () async {
        final _ContextoApi contexto = _criarApi();
        final String token = await _criarSessao(contexto.api);
        expect(token, matches(RegExp(r'^[a-f0-9]{32}$')));
        expect(contexto.sessoes, hasLength(1));
        expect(contexto.sessoes.single.logins, 1);
      },
    );

    test(
      'retorna 503 com Retry-After enquanto o circuito está aberto',
      () async {
        DateTime agora = DateTime.utc(2026);
        int sondas = 0;
        final DisjuntorPortal disjuntor = DisjuntorPortal(
          sondarPortal: () async {
            sondas++;
            return const ResultadoSondaDisjuntor(status: 200);
          },
          agora: () => agora,
        );
        disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
        final _ContextoApi contexto = _criarApi(disjuntor: disjuntor);

        final Response aberta = await contexto.api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{'identificadorPrestador': 'teste'},
          ),
        );
        expect(aberta.statusCode, 503);
        expect(aberta.headers['retry-after'], '60');
        expect(contexto.sessoes, isEmpty);

        agora = agora.add(const Duration(seconds: 60));
        final Response recuperada = await contexto.api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{'identificadorPrestador': 'teste'},
          ),
        );
        expect(recuperada.statusCode, 201);
        expect(sondas, 1);
        expect(disjuntor.estado, EstadoDisjuntorPortal.fechado);
      },
    );

    test(
      'valida identificador e responde 401 quando não há credenciais',
      () async {
        final _ContextoApi contexto = _criarApi();
        final Response invalida = await contexto.api.handler(
          _request('POST', '/api/sessoes', body: <String, String>{}),
        );
        final Response desconhecida = await contexto.api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{
              'identificadorPrestador': 'nao-configurado',
            },
          ),
        );

        expect(invalida.statusCode, 400);
        expect(desconhecida.statusCode, 401);
        expect(contexto.sessoes, isEmpty);
      },
    );

    test(
      'bloqueio impede novas sessões mesmo com sessão autenticada no pool',
      () async {
        final DisjuntorPortal disjuntor = DisjuntorPortal(
          sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
        );
        final _ContextoApi contexto = _criarApi(disjuntor: disjuntor);
        await _criarSessao(contexto.api);
        disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);

        final Response reutilizada = await contexto.api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{'identificadorPrestador': 'teste'},
          ),
        );
        final Response status = await contexto.api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
        final Map<String, dynamic> dados =
            jsonDecode(await status.readAsString()) as Map<String, dynamic>;

        expect(reutilizada.statusCode, 503);
        expect(dados['status'], 'ok');
        expect(dados['bloqueio']['ativo'], isTrue);
      },
    );

    test('limite de capacidade retorna 429 sem Retry-After', () async {
      final _ContextoApi contexto = _criarApi(
        repositorio: RepositorioSessoes(limite: 1),
      );
      await _criarSessao(contexto.api);
      final Response cheia = await contexto.api.handler(
        _request(
          'POST',
          '/api/sessoes',
          body: const <String, String>{'identificadorPrestador': 'teste'},
        ),
      );

      expect(cheia.statusCode, 429);
      expect(cheia.headers.containsKey('retry-after'), isFalse);
    });

    test('limite de criação de sessão informa Retry-After da API', () async {
      final _ContextoApi contexto = _criarApi(limitePorChave: 1);
      await _criarSessao(contexto.api);
      final Response limitada = await contexto.api.handler(
        _request(
          'POST',
          '/api/sessoes',
          body: const <String, String>{'identificadorPrestador': 'teste'},
        ),
      );

      expect(limitada.statusCode, 429);
      expect(limitada.headers['retry-after'], '60');
    });

    test(
      'traduz falhas do login inicial sem expor detalhes internos',
      () async {
        final List<(MotivoFalhaLogin, int)> falhas = <(MotivoFalhaLogin, int)>[
          (MotivoFalhaLogin.credenciaisInvalidas, 401),
          (MotivoFalhaLogin.falhaInterna, 500),
          (MotivoFalhaLogin.respostaInesperada, 502),
          (MotivoFalhaLogin.falhaRede, 503),
        ];
        for (final (MotivoFalhaLogin motivo, int status) in falhas) {
          final _ContextoApi contexto = _criarApi(
            loginResult: ResultadoLogin.falha(
              motivo,
              detalhe: 'detalhe que nao pode vazar',
            ),
          );
          final Response resposta = await contexto.api.handler(
            _request(
              'POST',
              '/api/sessoes',
              body: const <String, String>{'identificadorPrestador': 'teste'},
            ),
          );

          expect(resposta.statusCode, status);
          expect(
            resposta.headers['x-validador-api-error-origin'],
            status == 502 ? 'api' : isNull,
          );
          expect(await resposta.readAsString(), isNot(contains('detalhe que')));
        }
      },
    );

    test(
      'responde 500 genérico para exceção interna ao criar sessão',
      () async {
        final ValidadorApi api = ValidadorApi(
          logger: Logger(output: const _LogMudo(), level: Level.off),
          ambiente: _ambiente,
          fabricaSessao: (_) => throw Exception('detalhe interno'),
        );
        final Response resposta = await api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{'identificadorPrestador': 'teste'},
          ),
        );

        expect(resposta.statusCode, 500);
        expect(
          await resposta.readAsString(),
          isNot(contains('detalhe interno')),
        );
      },
    );
  });

  group('POST /api/lotes', () {
    test(
      'falha de consulta bloqueia novas chamadas e cancela todos os lotes',
      () async {
        final _ContextoApi contexto = _criarApi(
          beneficiaryResult: const ResultadoConsultaPortal<String>.falha(
            categoria: CategoriaFalhaConsultaPortal.http,
            status: 429,
            falhaElegivelCircuito: true,
            motivoBloqueio: MotivoBloqueioPortal.limitePortal,
          ),
        );
        final String token = await _criarSessao(contexto.api);
        final List<(String, Response)> lotes = <(String, Response)>[];

        for (int i = 0; i < 2; i++) {
          final Response criado = await _criarLote(
            contexto.api,
            token,
            'bloqueio-$i',
          );
          final Map<String, dynamic> dados =
              jsonDecode(await criado.readAsString()) as Map<String, dynamic>;
          final String id = dados['id'] as String;
          final Response eventos = await contexto.api.handler(
            _request('GET', '/api/lotes/$id/eventos', token: token),
          );
          lotes.add((id, eventos));
        }

        contexto.gate.complete();
        final List<String> eventos = <String>[
          for (final (String _, Response resposta) in lotes)
            await resposta.readAsString(),
        ];

        expect(contexto.api.lotesAtivos, 0);
        expect(eventos, everyElement(contains('event: erro')));
        expect(eventos, everyElement(contains('"motivo":"limite_portal"')));
        expect(eventos, everyElement(isNot(contains('event: resultado'))));

        final Response replayEventos = await contexto.api.handler(
          _request('GET', '/api/lotes/${lotes.first.$1}/eventos', token: token),
        );
        expect(await replayEventos.readAsString(), contains('event: erro'));

        final Response novoLote = await _criarLote(
          contexto.api,
          token,
          'lote-bloqueado',
        );
        final Response novaSessao = await contexto.api.handler(
          _request(
            'POST',
            '/api/sessoes',
            body: const <String, String>{'identificadorPrestador': 'teste'},
          ),
        );
        expect(novoLote.statusCode, 503);
        expect(novaSessao.statusCode, 503);
        expect(
          jsonDecode(await novoLote.readAsString())['bloqueio']['ativo'],
          isTrue,
        );
        final Response status = await contexto.api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
        final Map<String, dynamic> estado =
            jsonDecode(await status.readAsString()) as Map<String, dynamic>;
        expect(status.statusCode, 200);
        expect(estado['bloqueio']['ativo'], isTrue);
        expect(estado['portalSulAmerica']['alcançavel'], isFalse);

        final Response replay = await _criarLote(
          contexto.api,
          token,
          'bloqueio-0',
        );
        expect(replay.statusCode, 202);
        expect(
          (jsonDecode(await replay.readAsString()) as Map)['estado'],
          'cancelado',
        );
      },
    );

    test(
      'rejeita novo lote com 503 e Retry-After quando o circuito abre',
      () async {
        final DisjuntorPortal disjuntor = DisjuntorPortal(
          sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
        );
        final _ContextoApi contexto = _criarApi(disjuntor: disjuntor);
        final String token = await _criarSessao(contexto.api);
        disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);

        final Response resposta = await _criarLote(
          contexto.api,
          token,
          'lote-enquanto-aberto',
        );

        expect(resposta.statusCode, 503);
        expect(resposta.headers['retry-after'], '60');
      },
    );

    test(
      'replay idempotente continua disponível com o circuito aberto',
      () async {
        final DisjuntorPortal disjuntor = DisjuntorPortal(
          sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
        );
        final _ContextoApi contexto = _criarApi(disjuntor: disjuntor);
        final String token = await _criarSessao(contexto.api);
        final Response original = await _criarLote(
          contexto.api,
          token,
          'chave-replay',
        );
        final String id =
            (jsonDecode(await original.readAsString()) as Map)['id'] as String;
        disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);

        final Response repetida = await _criarLote(
          contexto.api,
          token,
          'chave-replay',
        );
        final Map<String, dynamic> corpo =
            jsonDecode(await repetida.readAsString()) as Map<String, dynamic>;
        expect(repetida.statusCode, 202);
        expect(corpo['id'], id);
        contexto.gate.complete();
      },
    );

    test('valida o payload antes de exigir Bearer', () async {
      final _ContextoApi contexto = _criarApi();
      final Response resposta = await contexto.api.handler(
        _request(
          'POST',
          '/api/lotes',
          body: const <String, Object>{'consultas': <Object>[]},
        ),
      );
      expect(resposta.statusCode, 400);
    });

    test('exige Bearer e Idempotency-Key', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      final Response semToken = await contexto.api.handler(
        _request(
          'POST',
          '/api/lotes',
          body: {
            'consultas': <Map<String, dynamic>>[_consulta()],
          },
        ),
      );
      final Response semChave = await contexto.api.handler(
        _request(
          'POST',
          '/api/lotes',
          token: token,
          body: <String, Object>{
            'consultas': <Map<String, dynamic>>[_consulta()],
          },
        ),
      );

      expect(semToken.statusCode, 401);
      expect(semChave.statusCode, 400);
    });

    test('aceita lote e repete a mesma execução por idempotência', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      final Response primeira = await _criarLote(contexto.api, token, 'key-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final int consultasAntes = contexto.sessoes.fold<int>(
        0,
        (int total, _SessaoFake sessao) => total + sessao.consultas,
      );
      final Response repetida = await _criarLote(contexto.api, token, 'key-1');
      final Map primeiraJson = jsonDecode(await primeira.readAsString()) as Map;
      final Map repetidaJson = jsonDecode(await repetida.readAsString()) as Map;

      expect(primeira.statusCode, 202);
      expect(
        primeira.headers['location'],
        '/api/lotes/${primeiraJson['id']}/eventos',
      );
      expect(repetida.statusCode, 202);
      expect(repetidaJson['id'], primeiraJson['id']);
      expect(
        contexto.sessoes.fold<int>(
          0,
          (int total, _SessaoFake sessao) => total + sessao.consultas,
        ),
        consultasAntes,
      );

      contexto.gate.complete();
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test('payload diferente com a mesma chave devolve 409', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      final Response primeira = await _criarLote(contexto.api, token, 'same');
      final Response diferente = await _criarLote(
        contexto.api,
        token,
        'same',
        consultas: <Map<String, dynamic>>[_consulta(tipo: 'senha')],
      );

      expect(primeira.statusCode, 202);
      expect(diferente.statusCode, 409);
      contexto.gate.complete();
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test(
      'itens inválidos não adquirem sessão nem consultam o portal',
      () async {
        final _ContextoApi contexto = _criarApi();
        final String token = await _criarSessao(contexto.api);
        final Response resposta = await _criarLote(
          contexto.api,
          token,
          'invalid-items',
          consultas: <Map<String, dynamic>>[
            <String, dynamic>{'tipo': 'desconhecido', 'chave': 'x'},
            <String, dynamic>{'tipo': 'elegibilidade', 'chave': 'invalida'},
          ],
        );

        expect(resposta.statusCode, 202);
        await _aguardar(() async => await _ativos(contexto.api) == 0);
        expect(contexto.sessoes, hasLength(1));
        expect(contexto.sessoes.single.logins, 1);
        expect(contexto.sessoes.single.consultas, 0);
      },
    );

    test('mais de 300 itens e corpo acima de 1 MB retornam 413', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      final Response excessivo = await contexto.api.handler(
        _request(
          'POST',
          '/api/lotes',
          token: token,
          idempotencyKey: 'over-limit',
          body: <String, Object>{
            'consultas': List<Map<String, dynamic>>.generate(
              301,
              (_) => _consulta(),
            ),
          },
        ),
      );
      final Request grande = Request(
        'POST',
        Uri.parse('http://localhost/api/lotes'),
        body: Stream<List<int>>.value(
          utf8.encode(jsonEncode({'consultas': 'x' * (1 << 20)})),
        ),
        headers: <String, String>{
          'authorization': 'Bearer $token',
          'idempotency-key': 'large-body',
        },
      );
      final Response corpoGrande = await contexto.api.handler(grande);

      expect(excessivo.statusCode, 413);
      expect(corpoGrande.statusCode, 413);
    });
  });

  group('SSE e ownership', () {
    test('resultado HTTP inclui status sem expor chave da consulta', () async {
      final _ContextoApi contexto = _criarApi(
        beneficiaryResult: const ResultadoConsultaPortal<String>.falha(
          categoria: CategoriaFalhaConsultaPortal.http,
          status: 429,
        ),
      );
      final String token = await _criarSessao(contexto.api);
      final Response lote = await _criarLote(
        contexto.api,
        token,
        'http-status',
      );
      final String id =
          (jsonDecode(await lote.readAsString()) as Map)['id'] as String;
      final Response eventos = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos', token: token),
      );
      final Future<String> corpo = eventos.readAsString();
      contexto.gate.complete();
      final String sse = await corpo.timeout(const Duration(seconds: 2));
      final String blocoResultado = sse
          .split(RegExp(r'\r?\n\r?\n'))
          .firstWhere((String bloco) => bloco.contains('event: resultado'));
      final String dadosResultado = blocoResultado
          .split(RegExp(r'\r?\n'))
          .firstWhere((String linha) => linha.startsWith('data:'))
          .substring(5)
          .trimLeft();
      final Map<String, dynamic> payload =
          jsonDecode(dadosResultado) as Map<String, dynamic>;
      final List<dynamic> resultados = payload['resultados'] as List<dynamic>;
      final Map<String, dynamic> resultado =
          resultados.single as Map<String, dynamic>;
      final String erro = resultado['erro'] as String;

      expect(erro, 'Falha na consulta ao portal SulAmerica (HTTP 429).');
      expect(erro, isNot(contains('12345678901234567890')));
      for (final String campo in <String>[
        'tempoFilaMs',
        'tempoSessaoMs',
        'tempoPortalMs',
        'tempoRetryMs',
        'tempoExecucaoMs',
      ]) {
        expect(resultado[campo], isA<int>());
        expect(resultado[campo], greaterThanOrEqualTo(0));
      }
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test('status agrega falha HTTP terminal sem status', () async {
      final _ContextoApi contexto = _criarApi(
        beneficiaryResult: const ResultadoConsultaPortal<String>.falha(
          categoria: CategoriaFalhaConsultaPortal.http,
          status: null,
        ),
      );
      final String token = await _criarSessao(contexto.api);
      final Response lote = await _criarLote(
        contexto.api,
        token,
        'http-sem-status',
      );
      final String id =
          (jsonDecode(await lote.readAsString()) as Map)['id'] as String;
      final Response eventos = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos', token: token),
      );
      final Future<String> corpo = eventos.readAsString();
      contexto.gate.complete();
      final String sse = await corpo.timeout(const Duration(seconds: 2));
      final String blocoResultado = sse
          .split(RegExp(r'\r?\n\r?\n'))
          .firstWhere((String bloco) => bloco.contains('event: resultado'));
      final String dadosResultado = blocoResultado
          .split(RegExp(r'\r?\n'))
          .firstWhere((String linha) => linha.startsWith('data:'))
          .substring(5)
          .trimLeft();
      final Map<String, dynamic> payload =
          jsonDecode(dadosResultado) as Map<String, dynamic>;
      final List<dynamic> resultados = payload['resultados'] as List<dynamic>;

      expect(
        (resultados.single as Map<String, dynamic>)['erro'],
        'Falha na consulta ao portal SulAmerica.',
      );
      await _aguardar(() async => await _ativos(contexto.api) == 0);
      final Response status = await contexto.api.handler(
        Request('GET', Uri.parse('http://localhost/api/status')),
      );
      final Map dadosStatus = jsonDecode(await status.readAsString()) as Map;

      expect(dadosStatus['status'], 'ok');
      expect(dadosStatus.containsKey('falhasConsulta'), isFalse);
    });

    test('outro token não pode abrir eventos do lote', () async {
      final _ContextoApi contexto = _criarApi();
      final String dono = await _criarSessao(contexto.api);
      final String outro = await _criarSessao(contexto.api);
      final Response lote = await _criarLote(contexto.api, dono, 'owner');
      final String id =
          (jsonDecode(await lote.readAsString()) as Map)['id'] as String;

      final Response semDono = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos', token: outro),
      );
      final Response semAuth = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos'),
      );

      expect(semDono.statusCode, 404);
      expect(semAuth.statusCode, 401);
      contexto.gate.complete();
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test('stream usa replay SSE e substitui assinante anterior', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      final Response lote = await _criarLote(contexto.api, token, 'stream');
      final String id =
          (jsonDecode(await lote.readAsString()) as Map)['id'] as String;
      final Completer<void> primeiraFechada = Completer<void>();
      final Response primeira = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos', token: token),
      );
      primeira.read().listen(
        (_) {},
        onDone: () {
          if (!primeiraFechada.isCompleted) primeiraFechada.complete();
        },
      );
      final Response segunda = await contexto.api.handler(
        _request('GET', '/api/lotes/$id/eventos?desde=0', token: token),
      );
      final StringBuffer dados = StringBuffer();
      final Completer<void> segundaFechada = Completer<void>();
      segunda
          .read()
          .transform(utf8.decoder)
          .listen(
            dados.write,
            onDone: () {
              if (!segundaFechada.isCompleted) segundaFechada.complete();
            },
          );
      await primeiraFechada.future.timeout(const Duration(seconds: 1));
      expect(segunda.statusCode, 200);
      expect(segunda.headers['content-type'], contains('text/event-stream'));
      expect(segunda.context['shelf.io.buffer_output'], isFalse);

      contexto.gate.complete();
      await segundaFechada.future.timeout(const Duration(seconds: 2));
      expect(dados.toString(), contains('event: resultado'));
      expect(dados.toString(), contains('retry: 3000'));
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });
  });

  group('rotas desconhecidas e status', () {
    test('rota desconhecida retorna 404', () async {
      final ValidadorApi api = _criarApi().api;
      final Response resposta = await api.handler(
        Request('POST', Uri.parse('http://localhost/rota-desconhecida')),
      );

      expect(resposta.statusCode, 404);
    });

    test(
      'status informa contadores sem expor token ou identificador',
      () async {
        final _ContextoApi contexto = _criarApi();
        await _criarSessao(contexto.api);
        final Response resposta = await contexto.api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
        final String texto = await resposta.readAsString();
        final Map dados = jsonDecode(texto) as Map;

        expect(resposta.statusCode, 200);
        expect(
          dados.keys,
          containsAll(<String>[
            'status',
            'portalSulAmerica',
            'bloqueio',
            'timestamp',
          ]),
        );
        expect(dados.keys, hasLength(4));
        expect(dados['bloqueio'], <String, bool>{'ativo': false});
        expect(dados['portalSulAmerica'], isA<Map>());
        expect(dados['timestamp'], isA<String>());
        expect(texto, isNot(contains('usuario-teste')));
        expect(texto, isNot(contains('PORTAL_PRESTADOR')));
        expect(texto, isNot(contains('diagnosticoSessaoPortal')));
      },
    );

    test('status não expõe Support IDs', () async {
      final _ContextoApi contexto = _criarApi(
        ambiente: <String, String>{
          ..._ambiente,
          'PORTAL_ASSINATURAS_SUPPORT_IDS_ATIVAS': 'true',
        },
        supportIdMarkers: 1,
      );
      await _criarSessao(contexto.api);
      final Response resposta = await contexto.api.handler(
        Request('GET', Uri.parse('http://localhost/api/status')),
      );
      final String texto = await resposta.readAsString();

      expect(resposta.statusCode, 200);
      expect(texto, isNot(contains('supportIdsRespostaPortal')));
      expect(texto, isNot(contains('assinaturaF5MarkerSupportId')));
    });
  });

  group('limites e CORS', () {
    test('limite de criação de lote informa Retry-After da API', () async {
      final _ContextoApi contexto = _criarApi(limitePorChave: 1);
      final String token = await _criarSessao(contexto.api);
      final Response aceito = await _criarLote(contexto.api, token, 'batch-1');
      final Response limitada = await _criarLote(
        contexto.api,
        token,
        'batch-2',
      );

      expect(aceito.statusCode, 202);
      expect(limitada.statusCode, 429);
      expect(limitada.headers['retry-after'], '60');

      contexto.gate.complete();
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test('fila cheia responde 429 sem Retry-After', () async {
      final _ContextoApi contexto = _criarApi();
      final String token = await _criarSessao(contexto.api);
      for (int i = 0; i < 24; i++) {
        expect(
          (await _criarLote(contexto.api, token, 'batch-$i')).statusCode,
          202,
        );
      }
      final Response cheia = await _criarLote(contexto.api, token, 'batch-25');

      expect(cheia.statusCode, 429);
      expect(cheia.headers.containsKey('retry-after'), isFalse);
      expect(
        cheia.headers['access-control-allow-headers'],
        contains('Idempotency-Key'),
      );

      contexto.gate.complete();
      await _aguardar(() async => await _ativos(contexto.api) == 0);
    });

    test('CORS respeita allowlist e expõe Location', () async {
      final _ContextoApi contexto = _criarApi();
      final Response permitida = await contexto.api.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/status'),
          headers: const <String, String>{'origin': 'https://app.example'},
        ),
      );
      final Response bloqueada = await contexto.api.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/status'),
          headers: const <String, String>{'origin': 'https://other.example'},
        ),
      );
      final Response githubPages = await contexto.api.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/status'),
          headers: const <String, String>{
            'origin': 'https://iagosantanadev.github.io',
          },
        ),
      );

      expect(
        permitida.headers['access-control-allow-origin'],
        'https://app.example',
      );
      expect(
        githubPages.headers['access-control-allow-origin'],
        'https://iagosantanadev.github.io',
      );
      expect(
        permitida.headers['access-control-expose-headers'],
        'Location, Retry-After',
      );
      expect(
        bloqueada.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });
  });
}

Future<int> _ativos(ValidadorApi api) async => api.lotesAtivos;

Future<void> _aguardar(Future<bool> Function() condicao) async {
  for (int tentativa = 0; tentativa < 200; tentativa++) {
    if (await condicao()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('execuções assíncronas não finalizaram');
}
