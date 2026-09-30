import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';
import 'package:validador_backend/validador_api.dart';

/// Saida de log descartada: os testes nao devem poluir o console.
class _LogMudo implements LogOutput {
  const _LogMudo();

  @override
  void output(OutputEvent event) {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> init() async {}
}

/// `LogOutput` que guarda as mensagens para permitir assercao sobre o que foi
/// registrado no servidor.
class _LogCapturado implements LogOutput {
  _LogCapturado([List<String>? destino]) : mensagens = destino ?? <String>[];

  final List<String> mensagens;

  @override
  void output(OutputEvent event) => mensagens.addAll(event.lines);

  @override
  Future<void> destroy() async {}

  @override
  Future<void> init() async {}
}

/// `SessaoPortal` sem rede: `login` devolve um resultado controlado e guarda
/// as credenciais recebidas para permitir assercao sobre a resolucao feita
/// pelo servidor.
class _SessaoPortalFake extends SessaoPortal {
  _SessaoPortalFake(this.resultado)
      : super(
          logger: Logger(output: const _LogMudo()),
        );

  final ResultadoLogin resultado;
  final List<({String code, String user, String senha})> credenciaisRecebidas =
      <({String code, String user, String senha})>[];

  /// Quantas vezes `encerrar()` foi chamado: prova se a sessao foi descartada
  /// pelo servidor.
  int encerradas = 0;

  /// Quando preenchido, `consultarBeneficiario` fica parado ate o
  /// `Completer` completar, mantendo a sessao ocupada por um lote em voo.
  Completer<void>? consultaEmAndamento;

  /// Quantas vezes o lote chegou a usar esta sessao. E o sinal de que a
  /// sessao esta realmente ocupada, sem depender de `delay`.
  int consultasIniciadas = 0;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    credenciaisRecebidas.add((code: code, user: user, senha: senha));
    return resultado;
  }

  @override
  Future<String?> consultarBeneficiario({
    required String carteirinhaCompleta,
  }) async {
    consultasIniciadas++;
    await consultaEmAndamento?.future;
    return '<html>elegivel=true</html>';
  }

  @override
  Future<void> encerrar() async {
    encerradas++;
  }
}

/// Falso `HttpConnectionInfo` para exercitar o rate limit por IP real.
class _ConexaoFake implements HttpConnectionInfo {
  _ConexaoFake(this.remoteAddress);

  @override
  final InternetAddress remoteAddress;

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 51234;
}

const Map<String, String> _ambienteTeste = {
  'PORTAL_PRESTADOR_ID_TESTE_CODE': '000000000000',
  'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario-teste',
  'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha-teste',
};

/// Monta uma API cujas sessoes do portal sao [_SessaoPortalFake] e cuja sonda
/// de alcance e contada, sem tocar a rede.
ValidadorApi _apiDeTeste({
  required List<_SessaoPortalFake> sessoes,
  required List<String> log,
  Future<int> Function()? sonda,
  Duration janelaCacheAlcance = const Duration(seconds: 10),
  int limiteSessoes = 10,
}) {
  final List<_SessaoPortalFake> fila = List<_SessaoPortalFake>.of(sessoes);
  return ValidadorApi(
    logger: Logger(output: _LogCapturado(log)),
    ambiente: _ambienteTeste,
    fabricaSessao: (_) => fila.removeAt(0),
    sondaPortal: sonda ?? () async => 200,
    janelaCacheAlcance: janelaCacheAlcance,
    limiteSessoes: limiteSessoes,
  );
}

/// Monta uma API só para exercitar o CORS, com a sonda de alcance contada
/// (nenhum teste toca a rede). [corsOrigin] ausente = `CORS_ORIGIN` não
/// definida, que precisa continuar valendo `*`.
ValidadorApi _apiDeCors(String? corsOrigin) {
  return ValidadorApi(
    logger: Logger(output: _LogCapturado(<String>[])),
    ambiente: <String, String>{
      ..._ambienteTeste,
      if (corsOrigin != null) 'CORS_ORIGIN': corsOrigin,
    },
    fabricaSessao: (_) => _SessaoPortalFake(const ResultadoLogin.autenticado()),
    sondaPortal: () async => 200,
  );
}

/// Dispara a rota que só exercita o middleware de CORS: 404 sem tocar o
/// portal e sem rede.
Future<Response> _requisicaoDeCors(
  ValidadorApi api,
  String metodo,
  String? origin,
) async {
  return api.handler(
    Request(
      metodo,
      Uri.parse('http://localhost/api/login'),
      headers: origin == null ? null : <String, String>{'origin': origin},
    ),
  );
}

/// Aguarda o lote chegar de fato na consulta ao portal, sem depender de
/// `delay` fixo (a leitura do corpo e um await, nao e sincrona).
Future<void> _aguardaConsulta(_SessaoPortalFake sessao) async {
  for (int i = 0; i < 100 && sessao.consultasIniciadas == 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(
    sessao.consultasIniciadas,
    greaterThan(0),
    reason: 'o lote deveria ter alcancado o portal',
  );
}

/// Dispara um lote de uma elegibilidade e devolve a resposta sem aguardar,
/// para que o teste observe a sessao enquanto ela esta ocupada.
Future<Response> _loteDe(String token, ValidadorApi api) {
  final Request request = _requestConsultas({
    'token': token,
    'consultas': <dynamic>[
      {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
    ],
  });
  return Future<Response>.value(api.handler(request));
}

Future<String> _tokenDoLogin(ValidadorApi api) async {
  final response = await api.handler(
    _requestLogin(const {'identificadorPrestador': 'teste'}),
  );
  expect(response.statusCode, 200, reason: 'login deveria autenticar');
  final corpo = jsonDecode(await response.readAsString()) as Map;
  return corpo['token'] as String;
}

Request _requestLogin(
  Object corpo, {
  HttpConnectionInfo? conexao,
  Map<String, String>? headers,
}) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/login'),
    body: corpo is String ? corpo : jsonEncode(corpo),
    headers: headers,
    context: conexao == null
        ? const <String, Object>{}
        : <String, Object>{'shelf.io.connection_info': conexao},
  );
}

Request _requestConsultas(
  Object corpo, {
  HttpConnectionInfo? conexao,
  Map<String, String>? headers,
}) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/consultas'),
    body: corpo is String ? corpo : jsonEncode(corpo),
    headers: headers,
    context: conexao == null
        ? const <String, Object>{}
        : <String, Object>{'shelf.io.connection_info': conexao},
  );
}

void main() {
  group('ValidadorApi - login', () {
    late ValidadorApi api;

    setUp(() {
      api = ValidadorApi();
    });

    test('rejeita corpo JSON invalido com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: 'nao e json',
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificadorPrestador ausente com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'outro': 'campo'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificadorPrestador vazio com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': '  '}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificador desconhecido com 401', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'desconhecido'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });

    test('aceita apenas identificadorPrestador (sem code/user/senha)',
        () async {
      // Mesmo com code/user/senha no corpo, o backend deve ignorá-los
      // e resolver as credenciais no servidor. Como o identificador não
      // está configurado, deve retornar 401 (desconhecido).
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({
          'identificadorPrestador': 'nao-configurado',
          'code': '123',
          'user': 'user',
          'senha': 'senha',
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });
  });

  group('ValidadorApi - consultas', () {
    late ValidadorApi api;

    setUp(() {
      api = ValidadorApi();
    });

    test('rejeita token ausente com 401', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'consultas': [
            {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });

    test('rejeita consultas ausentes com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({'token': 'abc'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita consultas vazias com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': <dynamic>[],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item nao-objeto com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': ['invalido'],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item sem tipo com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item sem chave com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': 'elegibilidade'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item com tipo vazio com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': '', 'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item com chave vazia com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': 'elegibilidade', 'chave': ''},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test(
        'valida payload antes do token: payload invalido + token valido '
        'devolve 400', () async {
      // Ordem importa: com token legitimo e payload invalido, o erro
      // precisa ser de validacao (400), e nao de sessao (401).
      final sessao = _SessaoPortalFake(const ResultadoLogin.autenticado());
      final api = ValidadorApi(
        ambiente: const {
          'PORTAL_PRESTADOR_ID_TESTE_CODE': '000000000000',
          'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario-teste',
          'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha-teste',
        },
        fabricaSessao: (_) => sessao,
      );
      final login = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      expect(login.statusCode, 200);
      final loginCorpo = jsonDecode(await login.readAsString()) as Map;
      final token = loginCorpo['token'] as String;
      final response = await api.handler(
        _requestConsultas({'token': token, 'consultas': 'nao-e-lista'}),
      );
      expect(response.statusCode, 400);
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(corpo['mensagem'], 'Campo consultas e obrigatorio.');
    });

    test(
        'valida payload antes do token: payload valido + token invalido '
        'devolve 401', () async {
      final sessao = _SessaoPortalFake(const ResultadoLogin.autenticado());
      final api = ValidadorApi(fabricaSessao: (_) => sessao);
      final response = await api.handler(
        _requestConsultas({
          'token': 'token-que-nao-existe',
          'consultas': [
            {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
          ],
        }),
      );
      expect(response.statusCode, 401);
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(corpo['mensagem'], 'Token de sessao invalido ou ausente.');
    });

    test('rejeita lote acima de 300 itens com 413', () async {
      final consultas = List.generate(
        301,
        (i) => {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
      );
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({'token': 'abc', 'consultas': consultas}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 413);
    });

    test('rejeita corpo acima de 1 MB com 413', () async {
      // O limite precisa ser provado no handler: um corpo grande mas
      // sintaticamente invalido ("xxx...") so pode responder 413 se a
      // checagem de tamanho existir; sem o limite cairia em 400.
      final corpoGrande = 'x' * ((1 << 20) + 1);
      final request = _requestConsultas(corpoGrande);
      final response = await api.handler(request);
      expect(response.statusCode, 413);
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(corpo['mensagem'], contains('1 MB'));
    });

    test('aceita corpo dentro do limite e segue para a validacao normal',
        () async {
      // Corpo com o mesmo tamanho-limite, porem JSON valido: nao pode ser
      // barrado por tamanho, e sim reprovado pela regra de negocio
      // (identificador desconhecido => 401).
      final enchimento = 'x' * ((1 << 20) - 128);
      final corpo = jsonEncode(
        {'identificadorPrestador': 'inexistente', 'lixo': enchimento},
      );
      expect(corpo.length, lessThanOrEqualTo(1 << 20));

      final api = ValidadorApi();
      final response = await api.handler(_requestLogin(corpo));
      expect(response.statusCode, 401);
      final mapa = jsonDecode(await response.readAsString()) as Map;
      expect(mapa['mensagem'], isNot(contains('1 MB')));
    });
  });

  group('ValidadorApi - rate limit', () {
    test('retorna 429 apos exceder limite de requisicoes', () async {
      final api = ValidadorApi();
      const int limite = 40;

      // Identificador desconhecido responde 401 sem tocar a rede, o que
      // permite exercitar apenas o rate limit.
      for (int i = 0; i < limite; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'identificadorPrestador': 'inexistente'}),
        );
        final response = await api.handler(request);
        expect(response.statusCode, 401, reason: 'Falha na req $i');
      }

      // A próxima requisição deve ser bloqueada.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'inexistente'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 429);
    });

    test('nao confia em X-Forwarded-For arbitrario', () async {
      final api = ValidadorApi();
      const int limite = 40;

      // X-Forwarded-For variando deve continuar contando como o mesmo IP,
      // pois o backend usa apenas o endereco real de conexao.
      for (int i = 0; i < limite; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'identificadorPrestador': 'inexistente'}),
          headers: {'x-forwarded-for': '10.0.0.$i'},
        );
        final response = await api.handler(request);
        expect(response.statusCode, 401, reason: 'Falha na req $i');
      }

      // A próxima requisição deve ser bloqueada, mesmo com XFF diferente.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'inexistente'}),
        headers: {'x-forwarded-for': '10.0.0.999'},
      );
      final response = await api.handler(request);
      expect(response.statusCode, 429);
    });

    test('separa buckets de rate limit por IP de conexao real', () async {
      // Prova que o rate limit usa o IP real: um cliente exhausting o proprio
      // limite nao pode bloquear outro IP. Passaria com uma chave constante.
      final api = ValidadorApi();
      const int limite = 40;
      final conexaoA = _ConexaoFake(InternetAddress('203.0.113.10'));
      final conexaoB = _ConexaoFake(InternetAddress('203.0.113.11'));

      for (int i = 0; i < limite; i++) {
        final response = await api.handler(
          _requestLogin(
            const {'identificadorPrestador': 'inexistente'},
            conexao: conexaoA,
          ),
        );
        expect(response.statusCode, 401, reason: 'Falha na req $i do IP A');
      }

      // IP A esgotou: precisa estar bloqueado.
      final bloqueadoA = await api.handler(
        _requestLogin(
          const {'identificadorPrestador': 'inexistente'},
          conexao: conexaoA,
        ),
      );
      expect(bloqueadoA.statusCode, 429);

      // IP B tem o proprio bucket e nao pode ser afetado pelo IP A.
      final respostaB = await api.handler(
        _requestLogin(
          const {'identificadorPrestador': 'inexistente'},
          conexao: conexaoB,
        ),
      );
      expect(respostaB.statusCode, 401);
    });

    test('nao aplica rate limit em rotas fora do portal', () async {
      final api = ValidadorApi();
      for (int i = 0; i < 45; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/rota-inexistente'),
          body: '{}',
        );
        final response = await api.handler(request);
        expect(response.statusCode, 404, reason: 'Falha na req $i');
      }
    });
  });

  group('ValidadorApi - ambiente injetado', () {
    test('identificador desconhecido no ambiente injetado retorna 401',
        () async {
      final api = ValidadorApi(ambiente: const {});
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'teste'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(corpo['mensagem'], contains('nao autorizado'));
    });

    const Map<String, String> ambienteTeste = {
      'PORTAL_PRESTADOR_ID_TESTE_CODE': '000000000000',
      'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario-teste',
      'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha-teste',
    };

    test('identificador conhecido avanca para autenticacao no portal',
        () async {
      // O `SessaoPortal` e falso: nenhum acesso a rede. O que se prova e que
      // o identificador foi resolvido no servidor (as credenciais injetadas no
      // ambiente chegam intactas a sessao) e que a requisicao NAO foi recusada
      // na etapa de autorizacao.
      final sessao = _SessaoPortalFake(const ResultadoLogin.autenticado());
      final api = ValidadorApi(
        ambiente: ambienteTeste,
        fabricaSessao: (_) => sessao,
      );

      final response = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      final corpo = jsonDecode(await response.readAsString()) as Map;

      expect(corpo['status'], isNull);
      expect(corpo['autenticada'], isTrue);
      expect(corpo['token'], isA<String>());
      expect(corpo['mensagem'], isNull);

      // Prova de que a resolucao veio do ambiente, e nao do corpo.
      expect(sessao.credenciaisRecebidas, hasLength(1));
      expect(sessao.credenciaisRecebidas.single.code, '000000000000');
      expect(sessao.credenciaisRecebidas.single.user, 'usuario-teste');
      expect(sessao.credenciaisRecebidas.single.senha, 'senha-teste');
    });

    test(
        'identificador conhecido com credencial recusada pelo portal '
        'retorna 401 do portal, nao de autorizacao', () async {
      final sessao = _SessaoPortalFake(
        const ResultadoLogin.falha(MotivoFalhaLogin.credenciaisInvalidas),
      );
      final api = ValidadorApi(
        ambiente: ambienteTeste,
        fabricaSessao: (_) => sessao,
      );

      final response = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(response.statusCode, 401);
      expect(
        corpo['mensagem'],
        'Credenciais invalidas para o portal SulAmerica.',
      );
      expect(corpo['mensagem'], isNot(contains('nao autorizado')));
      expect(sessao.credenciaisRecebidas, hasLength(1));
    });

    test('identificador desconhecido nao chega a instanciar sessao do portal',
        () async {
      // Par do teste acima: sem configuracao no ambiente, a recusa acontece
      // antes de qualquer tentativa de portal.
      final sessao = _SessaoPortalFake(const ResultadoLogin.autenticado());
      final api = ValidadorApi(
        ambiente: ambienteTeste,
        fabricaSessao: (_) => sessao,
      );

      final response = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'nao-configurado'}),
      );
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(response.statusCode, 401);
      expect(corpo['mensagem'], contains('nao autorizado'));
      expect(sessao.credenciaisRecebidas, isEmpty);
    });

    test('credenciais do cliente no corpo sao ignoradas', () async {
      // Mesmo com ambiente injetado para 'teste', o body traz outros
      // identificadores: apenas o identificadorPrestador decide.
      final api = ValidadorApi(ambiente: const {});
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({
          'identificadorPrestador': 'outro',
          'code': '1',
          'user': 'u',
          'senha': 's',
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });
  });

  group('ValidadorApi - rota nao encontrada', () {
    test('retorna 404 para rota desconhecida', () async {
      final api = ValidadorApi();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/rota-desconhecida'),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 404);
    });
  });

  group('ValidadorApi - status', () {
    test('retorna 200 para /api/status', () async {
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(const ResultadoLogin.autenticado()),
        ],
        log: <String>[],
      );
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/status'),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 200);
    });
  });

  group('ValidadorApi - CORS', () {
    // Cenario do bug: CORS_ORIGIN com lista separada por virgula. Ecoar a
    // string inteira produz `Access-Control-Allow-Origin` com varias origens,
    // o que a spec rejeita e o navegador reporta como "contains multiple
    // values". O header precisa valer exatamente a origem que casou.
    const String producao = 'https://validador-sulamerica.pages.dev';
    const String local = 'http://localhost:3000';

    test('devolve so a origem que casa quando CORS_ORIGIN tem varias',
        () async {
      final api = _apiDeCors('$producao, $local');
      final response = await _requisicaoDeCors(api, 'GET', producao);
      expect(response.headers['access-control-allow-origin'], producao);
      expect(
        response.headers['access-control-allow-origin'],
        isNot(contains(',')),
      );
    });

    test('a segunda origem da lista tambem casa', () async {
      final api = _apiDeCors('$producao, $local');
      final response = await _requisicaoDeCors(api, 'GET', local);
      expect(response.headers['access-control-allow-origin'], local);
    });

    test('nao devolve Access-Control-Allow-Origin para origem fora da lista',
        () async {
      final api = _apiDeCors('$producao, $local');
      final response =
          await _requisicaoDeCors(api, 'GET', 'https://ataque.example');
      // Sem o header o navegador bloqueia: e o comportamento seguro.
      expect(
        response.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });

    test('aceita origem configurada com barra final', () async {
      // O header Origin do navegador nunca tem barra final; a configuracao
      // ingênua do operador tem. Os dois precisam casar.
      final api = _apiDeCors('$producao/, $local/');
      expect(
        (await _requisicaoDeCors(api, 'GET', producao))
            .headers['access-control-allow-origin'],
        producao,
      );
      expect(
        (await _requisicaoDeCors(api, 'GET', local))
            .headers['access-control-allow-origin'],
        local,
      );
    });

    test('ignora espacos em volta dos itens da lista', () async {
      final api = _apiDeCors('  $producao ,   $local  ');
      expect(
        (await _requisicaoDeCors(api, 'GET', producao))
            .headers['access-control-allow-origin'],
        producao,
      );
    });

    test('ignora item vazio de virgula dupla ou virgula no fim', () async {
      final api = _apiDeCors('$producao,, $local,');
      expect(
        (await _requisicaoDeCors(api, 'GET', local))
            .headers['access-control-allow-origin'],
        local,
      );
      // O item vazio nao pode virar uma origem extra aceita.
      expect(
        (await _requisicaoDeCors(api, 'GET', ''))
            .headers
            .containsKey('access-control-allow-origin'),
        isFalse,
      );
    });

    test('CORS_ORIGIN ausente mantem o wildcard', () async {
      final api = _apiDeCors(null);
      final response = await _requisicaoDeCors(api, 'GET', producao);
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('asterisco na lista devolve wildcard', () async {
      final api = _apiDeCors('$producao, *');
      expect(
        (await _requisicaoDeCors(api, 'GET', 'https://qualquer.example'))
            .headers['access-control-allow-origin'],
        '*',
      );
    });

    test('preflight OPTIONS segue a mesma logica de lista', () async {
      final api = _apiDeCors('$producao, $local');
      final permitido = await _requisicaoDeCors(api, 'OPTIONS', producao);
      expect(permitido.statusCode, 200);
      expect(
        permitido.headers['access-control-allow-origin'],
        producao,
      );
      expect(
        permitido.headers['access-control-allow-methods'],
        contains('POST'),
      );

      final bloqueado = await _requisicaoDeCors(
        api,
        'OPTIONS',
        'https://ataque.example',
      );
      expect(
        bloqueado.headers.containsKey('access-control-allow-origin'),
        isFalse,
        reason: 'preflight de origem nao permitida tambem nao pode echoar',
      );
    });

    test('a resposta real carrega o header, nao so o preflight', () async {
      // A resposta de login (nao preflight) tambem precisa do header, senao o
      // navegador bloqueia a leitura do corpo.
      final api = _apiDeCors('$producao, $local');
      final response = await api.handler(
        _requestLogin(
          const {'identificadorPrestador': 'desconhecido'},
          headers: <String, String>{'origin': producao},
        ),
      );
      expect(response.statusCode, 401);
      expect(response.headers['access-control-allow-origin'], producao);
    });

    test('marca Vary: Origin quando a resposta depende da origem', () async {
      // Sem Vary, um cache compartilhado (CDN/proxy do Render) pode servir a
      // resposta montada para uma origem para outra.
      final api = _apiDeCors('$producao, $local');
      expect(
        (await _requisicaoDeCors(api, 'GET', producao)).headers['vary'],
        'origin',
      );
      // Com wildcard a resposta nao varia por origem: nada a diferenciar.
      expect(
        (await _requisicaoDeCors(_apiDeCors(null), 'GET', producao))
            .headers
            .containsKey('vary'),
        isFalse,
      );
    });
  });

  group('ValidadorApi - cache do teste de alcance', () {
    test('duas chamadas dentro da janela sondam o portal uma vez', () async {
      // Sem cache, cada GET /api/status abriria um handshake TLS de saida.
      // O contador da sonda e o termometro: precisa crescer uma unica vez.
      int sondagens = 0;
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(const ResultadoLogin.autenticado()),
        ],
        log: <String>[],
        sonda: () async {
          sondagens++;
          return 200;
        },
      );

      for (int i = 0; i < 5; i++) {
        final response = await api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
        expect(response.statusCode, 200, reason: 'Falha na req $i');
      }
      expect(sondagens, 1);
    });

    test('apos a janela expirar volta a sondar o portal', () async {
      // Par do teste acima: o cache precisa expirar, senao o health check
      // passaria a mentir sobre o estado do portal para sempre.
      int sondagens = 0;
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(const ResultadoLogin.autenticado()),
        ],
        log: <String>[],
        janelaCacheAlcance: Duration.zero,
        sonda: () async {
          sondagens++;
          return 200;
        },
      );

      for (int i = 0; i < 3; i++) {
        await api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
      }
      expect(sondagens, 3);
    });

    test('/api/status nao responde 429 sob flood (health check do Render)',
        () async {
      // 429 conta como falha de saude para o Render, que para de rotear
      // trafego e reinicia a instancia. Entao /api/status fica de fora do
      // rate limit: a protecao e o cache da sonda, nao o 429.
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(const ResultadoLogin.autenticado()),
        ],
        log: <String>[],
      );
      for (int i = 0; i < 60; i++) {
        final response = await api.handler(
          Request('GET', Uri.parse('http://localhost/api/status')),
        );
        expect(response.statusCode, 200, reason: 'Falha na req $i');
      }
    });
  });

  group('ValidadorApi - detalhes internos nao vazam', () {
    test('falha de rede no login nao expoe o detalhe na resposta', () async {
      // O detalhe vem de `_detalheDioException` e carrega URL/fragmento de
      // requisicao. A resposta e entregue antes de qualquer autenticacao.
      final List<String> log = <String>[];
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(
            const ResultadoLogin.falha(
              MotivoFalhaLogin.falhaRede,
              detalhe: 'connectionError: https://saude.sulamericaseguros.com'
                  '.br/prestador/?token=SEGREDO',
            ),
          ),
        ],
        log: log,
      );

      final response = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      final corpo = jsonDecode(await response.readAsString()) as Map;

      expect(response.statusCode, 401);
      expect(corpo['mensagem'], isNot(contains('SEGREDO')));
      expect(corpo['mensagem'], isNot(contains('saude.sulamericaseguros')));
      expect(corpo['mensagem'], isNot(contains('Detalhe')));
      // O cliente ainda precisa saber que foi falha de rede.
      expect(corpo['mensagem'], contains('Falha de rede'));

      // O detalhe vai para o log do servidor.
      expect(log.join('\n'), contains('SEGREDO'));
    });

    test('falha interna no login nao se apresenta como falha de rede',
        () async {
      // Erro de codigo ou header inesperado nao e problema de rede. Antes de
      // separar os motivos, tudo caia em `falhaRede` e o cliente era
      // mandado investigar a rede quando o defeito estava no backend.
      final List<String> log = <String>[];
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(
            const ResultadoLogin.falha(
              MotivoFalhaLogin.falhaInterna,
              detalhe: 'location header has more than one value',
            ),
          ),
        ],
        log: log,
      );

      final response = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      final corpo = jsonDecode(await response.readAsString()) as Map;

      expect(response.statusCode, 401);
      expect(corpo['mensagem'], contains('Falha interna'));
      expect(corpo['mensagem'], isNot(contains('rede')));
      expect(corpo['mensagem'], isNot(contains('more than one value')));

      // O detalhe continua restrito ao log do servidor.
      expect(log.join('\n'), contains('more than one value'));
    });

    test('/api/status nao devolve detalhe bruto da falha de sonda', () async {
      final List<String> log = <String>[];
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[
          _SessaoPortalFake(const ResultadoLogin.autenticado()),
        ],
        log: log,
        sonda: () async {
          throw const _ErroDeSondaSensivel();
        },
      );

      final response = await api.handler(
        Request('GET', Uri.parse('http://localhost/api/status')),
      );
      final String bruto = await response.readAsString();
      final Map<String, dynamic> corpo =
          jsonDecode(bruto) as Map<String, dynamic>;
      final Map<String, dynamic> portal =
          corpo['portalSulAmerica'] as Map<String, dynamic>;

      // O sinal util continua: o cliente sabe que o portal esta fora.
      expect(corpo['status'], 'ok');
      expect(portal['alcançavel'], isFalse);

      // O subject/issuer do certificado nao pode vazar para chamador anonimo.
      expect(bruto, isNot(contains('subject=')));
      expect(bruto, isNot(contains('issuer=')));
      expect(portal.containsKey('detalhe'), isFalse);
      expect(portal.containsKey('erro'), isFalse);

      // E o operador ainda consegue diagnosticar pelo log.
      expect(log.join('\n'), contains('subject=CN=interno.sulamerica'));
    });
  });

  group('ValidadorApi - ciclo de vida da sessao', () {
    test('nao encerra a sessao usada por um lote em andamento', () async {
      // Cenario: login atinge o limite enquanto um lote consulta. A eviccao
      // ingenua (`_sessoes.keys.first`) fecharia o Dio do lote em voo.
      final _SessaoPortalFake emUso = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final _SessaoPortalFake antiga = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final _SessaoPortalFake nova = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );

      final api = _apiDeTeste(
        // A ordem importa: a sessao que entrara em uso precisa ser a mais
        // antiga do mapa, senao a eviccao ingenua (`_sessoes.keys.first`)
        // ja pegaria outra e o teste nao provaria nada.
        sessoes: <_SessaoPortalFake>[emUso, antiga, nova],
        log: <String>[],
        limiteSessoes: 2,
      );

      final String tokenEmUso =
          await _tokenDoLogin(api); // `emUso` (mais antiga)
      await _tokenDoLogin(api); // `antiga` (segunda, ociosa)

      final Completer<void> liberado = Completer<void>();
      emUso.consultaEmAndamento = liberado;
      final Future<Response> lote = _loteDe(tokenEmUso, api);
      await _aguardaConsulta(emUso);

      // Login com o limite atingido: precisa evictar alguem, mas nao a em uso.
      final login = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      expect(login.statusCode, 200, reason: 'login deveria criar sessao nova');
      expect(emUso.encerradas, 0, reason: 'em uso nao pode ser encerrada');
      expect(antiga.encerradas, 1, reason: 'a ociosa deve ser encerrada');

      liberado.complete();
      final respostaLote = await lote;
      expect(respostaLote.statusCode, 200);
    });

    test('recusa o login com 503 quando todas as sessoes estao em uso',
        () async {
      // Com uma unica sessao, ocupada por um lote, nao ha o que evictar. O
      // login precisa falhar com erro claro, nunca matar a sessao ativa.
      final _SessaoPortalFake emUso = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final _SessaoPortalFake nova = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[emUso, nova],
        log: <String>[],
        limiteSessoes: 1,
      );

      final String token = await _tokenDoLogin(api);
      final Completer<void> liberado = Completer<void>();
      emUso.consultaEmAndamento = liberado;
      final Future<Response> lote = _loteDe(token, api);
      await _aguardaConsulta(emUso);

      final login = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      final corpo = jsonDecode(await login.readAsString()) as Map;
      expect(login.statusCode, 503);
      expect(corpo['mensagem'], contains('Limite de sessoes ativas'));
      expect(emUso.encerradas, 0, reason: 'ativa nao pode ser encerrada');
      // A sessao do login recusado nao pode ficar vazando.
      expect(nova.encerradas, 1);

      liberado.complete();
      expect((await lote).statusCode, 200);
    });

    test('apos o lote terminar a sessao volta a ser elegivel para eviccao',
        () async {
      final _SessaoPortalFake emUso = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final _SessaoPortalFake nova = _SessaoPortalFake(
        const ResultadoLogin.autenticado(),
      );
      final api = _apiDeTeste(
        sessoes: <_SessaoPortalFake>[emUso, nova, nova],
        log: <String>[],
        limiteSessoes: 1,
      );

      final String token = await _tokenDoLogin(api);
      final Future<Response> lote = _loteDe(token, api);
      expect((await lote).statusCode, 200);

      // Sem lote em voo, a protecao nao pode vazar para sempre: a sessao
      // volta a ser candidata normal a eviccao.
      final login = await api.handler(
        _requestLogin(const {'identificadorPrestador': 'teste'}),
      );
      expect(login.statusCode, 200);
      expect(emUso.encerradas, 1);
    });
  });
}

/// Erro de rede sintetico com conteudo sensivel, para provar que o detalhe
/// nao sai do servidor.
class _ErroDeSondaSensivel implements Exception {
  const _ErroDeSondaSensivel();

  @override
  String toString() => 'HandshakeException: subject=CN=interno.sulamerica, '
      'issuer=CN=CA Interna SA, address=10.4.2.9:443';
}
