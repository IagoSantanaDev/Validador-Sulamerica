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

/// `SessaoPortal` sem rede: `login` devolve um resultado controlado e guarda
/// as credenciais recebidas para permitir assercao sobre a resolucao feita
/// pelo servidor.
class _SessaoPortalFake extends SessaoPortal {
  _SessaoPortalFake(this.resultado)
      : super(
          logger: Logger(output: const _LogMudo()),
          // Deterministico: sem pinning, independente de
          // PORTAL_CERT_FINGERPRINT_SHA256 no ambiente de quem roda.
          fingerprintEsperado: '',
        );

  final ResultadoLogin resultado;
  final List<({String code, String user, String senha})> credenciaisRecebidas =
      <({String code, String user, String senha})>[];

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    credenciaisRecebidas.add((code: code, user: user, senha: senha));
    return resultado;
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
      final api = ValidadorApi();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/status'),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 200);
    });
  });
}
