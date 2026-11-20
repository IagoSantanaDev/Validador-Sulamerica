import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

const String _idLogin = '8A61898253CE1C780153D20B7FF82329';
const String _idConsulta = '8A61F4123F396827013F39A6986109F9';

class _LogMudo implements LogOutput {
  const _LogMudo();

  @override
  void output(OutputEvent event) {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> init() async {}
}

class _AdapterTeste implements HttpClientAdapter {
  _AdapterTeste(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requisicoes = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requisicoes.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _resposta(
  String corpo,
  int status, {
  Map<String, List<String>>? headers,
}) =>
    ResponseBody.fromString(corpo, status, headers: headers);

void main() {
  test('HTTP 429 é devolvido sem retry de consulta', () async {
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        return ResponseBody.fromString(
          '<html><title>Rejected</title>Support ID ABC12345</html>',
          429,
          headers: <String, List<String>>{
            'content-type': <String>['text/html; charset=utf-8'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<String> resultado = await sessao
        .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');

    expect(consultas, 1);
    expect(resultado.sucesso, isFalse);
    expect(resultado.status, 429);
    expect(resultado.categoria, CategoriaFalhaConsultaPortal.http);
    expect(sessao.diagnosticoSessao['assinaturaResposta'], 1);
    expect(sessao.diagnosticoSessao['assinaturaF5Rejected'], 1);
    expect(sessao.diagnosticoSessao['assinaturaF5MarkerSupportId'], 1);
    expect(
      jsonEncode(sessao.diagnosticoSessao),
      isNot(contains('ABC12345')),
    );
    await sessao.encerrar();
  });

  test('diagnostica AJAX HTML sem guardar o corpo', () async {
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.uri.path == '/ajax-controller.jsp') {
        return ResponseBody.fromString(
          '<html>block page</html>',
          200,
          headers: <String, List<String>>{
            'content-type': <String>['text/html'],
          },
        );
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<Map<String, dynamic>> resultado =
        await sessao.consultarSenha(senha: '5000000000');

    expect(
      resultado.categoria,
      CategoriaFalhaConsultaPortal.respostaInesperada,
    );
    expect(sessao.diagnosticoSessao['ajaxHttp200'], 1);
    expect(sessao.diagnosticoSessao['ajaxContentTypeHtml'], 1);
    expect(sessao.diagnosticoSessao['ajaxJsonInvalido'], 1);
    expect(sessao.diagnosticoSessao['assinaturaResposta'], 1);
    expect(sessao.diagnosticoSessao['assinaturaF5Rejected'], isNull);
    expect(
      jsonEncode(sessao.diagnosticoSessao),
      isNot(contains('block page')),
    );
    await sessao.encerrar();
  });

  test('assina AJAX HTTP nao-200 com HTML sem guardar o corpo', () async {
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.uri.path == '/ajax-controller.jsp') {
        return ResponseBody.fromString(
          '<html><title>Rejected</title>Support ID ABC12345</html>',
          502,
          headers: <String, List<String>>{
            'content-type': <String>['text/html'],
          },
        );
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<Map<String, dynamic>> resultado =
        await sessao.consultarSenha(senha: '5000000000');

    expect(resultado.status, 502);
    expect(resultado.categoria, CategoriaFalhaConsultaPortal.http);
    expect(sessao.diagnosticoSessao['assinaturaResposta'], 1);
    expect(sessao.diagnosticoSessao['assinaturaF5Rejected'], 1);
    expect(sessao.diagnosticoSessao['assinaturaF5MarkerSupportId'], 1);
    expect(
      jsonEncode(sessao.diagnosticoSessao),
      isNot(contains('ABC12345')),
    );
    await sessao.encerrar();
  });

  test('nao repete transporte quando a resposta anexada tem marcador F5',
      () async {
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 503,
            data: '<html><title>Rejected</title>Support ID ABC12345</html>',
            headers: Headers.fromMap(<String, List<String>>{
              'content-type': <String>['text/html; charset=utf-8'],
            }),
          ),
        );
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<String> resultado = await sessao
        .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');

    expect(consultas, 1);
    expect(resultado.sucesso, isFalse);
    expect(resultado.status, 503);
    expect(resultado.categoria, CategoriaFalhaConsultaPortal.http);
    expect(sessao.diagnosticoSessao['assinaturaF5Rejected'], 1);
    expect(sessao.diagnosticoSessao['retriesTransitoriosIniciados'], 0);
    await sessao.encerrar();
  });

  test('repete transporte com HTTP 503 sem marcador F5', () async {
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        if (consultas == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
            response: Response<dynamic>(
              requestOptions: request,
              statusCode: 503,
              data: 'temporarily unavailable',
              headers: Headers.fromMap(<String, List<String>>{
                'content-type': <String>['text/plain'],
              }),
            ),
          );
        }
        return _resposta('<html>elegivel</html>', 200);
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<String> resultado = await sessao
        .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');

    expect(consultas, 2);
    expect(resultado.sucesso, isTrue);
    expect(sessao.diagnosticoSessao['retriesTransitoriosIniciados'], 1);
    expect(sessao.diagnosticoSessao['retriesTransitoriosResolvidos'], 1);
    await sessao.encerrar();
  });

  test('consulta diagnóstica retorna 401 sem renovar a sessão', () async {
    int logins = 0;
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        logins++;
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        return _resposta('expired', 401);
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<String> resultado =
        await sessao.consultarBeneficiario(
      carteirinhaCompleta: '12345678901234567890',
      recuperarFalhaSessao: false,
    );

    expect(consultas, 1);
    expect(logins, 1);
    expect(resultado.sucesso, isFalse);
    expect(resultado.status, 401);
    expect(resultado.categoria, CategoriaFalhaConsultaPortal.sessao);
    await sessao.encerrar();
  });

  test(
    'timeout de transporte tem um retry e retorna resultado tipado',
    () async {
      int consultas = 0;
      final _AdapterTeste adapter = _AdapterTeste((
        RequestOptions request,
      ) async {
        if (request.method == 'POST' &&
            request.uri.queryParameters['lumPageId'] == _idLogin) {
          return _resposta(
            '',
            302,
            headers: <String, List<String>>{
              'location': <String>['/prestador/'],
            },
          );
        }
        if (request.uri.path == '/prestador/') {
          return _resposta('<html>logout</html>', 200);
        }
        if (request.method == 'POST' &&
            request.uri.queryParameters['lumPageId'] == _idConsulta) {
          consultas++;
          if (consultas == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionTimeout,
            );
          }
          return _resposta('<html>elegivel</html>', 200);
        }
        return _resposta('<html>formulario</html>', 200);
      });
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()..httpClientAdapter = adapter,
        logger: Logger(output: const _LogMudo(), level: Level.off),
      );
      await _login(sessao);

      final ResultadoConsultaPortal<String> resultado = await sessao
          .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');

      expect(consultas, 2);
      expect(resultado.sucesso, isTrue);
      expect(resultado.status, 200);
      expect(resultado.dados, contains('elegivel'));
      await sessao.encerrar();
    },
  );

  test('HTTP 503 transitorio e repetido ate a consulta responder', () async {
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        if (consultas == 1) return _resposta('temporario', 503);
        return _resposta('<html>elegivel</html>', 200);
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final ResultadoConsultaPortal<String> resultado = await sessao
        .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');

    expect(consultas, 2);
    expect(resultado.sucesso, isTrue);
    expect(resultado.dados, contains('elegivel'));
    await sessao.encerrar();
  });

  test('consultas concorrentes compartilham renovação de sessão', () async {
    int logins = 0;
    int consultas = 0;
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        logins++;
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        return _resposta(
          consultas <= 2 ? 'expired' : '<html>elegivel</html>',
          consultas <= 2 ? 401 : 200,
        );
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final List<ResultadoConsultaPortal<String>> resultados =
        await Future.wait(<Future<ResultadoConsultaPortal<String>>>[
      sessao.consultarBeneficiario(carteirinhaCompleta: '12345678901234567890'),
      sessao.consultarBeneficiario(carteirinhaCompleta: '98765432109876543210'),
    ]);

    expect(logins, 2);
    expect(consultas, 4);
    expect(resultados.every((resultado) => resultado.sucesso), isTrue);
    expect(sessao.diagnosticoSessao['rejeicoes401'], 2);
    expect(sessao.diagnosticoSessao['renovacoesIniciadas'], 1);
    expect(sessao.diagnosticoSessao['renovacoesSucesso'], 1);
    expect(sessao.diagnosticoSessao['rejeicoes401AposRenovacao'], 0);
    await sessao.encerrar();
  });

  test(
    'renovação compartilha login inicial e ainda repete falha de transporte',
    () async {
      int logins = 0;
      int consultas = 0;
      final Completer<void> primeiroGetIniciado = Completer<void>();
      final Completer<void> liberarPrimeiroGet = Completer<void>();
      final _AdapterTeste adapter = _AdapterTeste((
        RequestOptions request,
      ) async {
        if (request.method == 'GET' &&
            request.uri.queryParameters['lumPageId'] == _idLogin &&
            !primeiroGetIniciado.isCompleted) {
          primeiroGetIniciado.complete();
          await liberarPrimeiroGet.future;
          return _resposta('<html>formulario</html>', 200);
        }
        if (request.method == 'POST' &&
            request.uri.queryParameters['lumPageId'] == _idLogin) {
          logins++;
          if (logins == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
          return _resposta(
            '',
            302,
            headers: <String, List<String>>{
              'location': <String>['/prestador/'],
            },
          );
        }
        if (request.uri.path == '/prestador/') {
          return _resposta('<html>logout</html>', 200);
        }
        if (request.method == 'POST' &&
            request.uri.queryParameters['lumPageId'] == _idConsulta) {
          consultas++;
          return _resposta('<html>elegivel</html>', 200);
        }
        return _resposta('<html>formulario</html>', 200);
      });
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()..httpClientAdapter = adapter,
        logger: Logger(output: const _LogMudo(), level: Level.off),
      );

      final Future<ResultadoLogin> loginInicial = sessao.login(
        code: 'code',
        user: 'user',
        senha: 'senha',
      );
      await primeiroGetIniciado.future;
      final Future<ResultadoConsultaPortal<String>> consulta = sessao
          .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');
      liberarPrimeiroGet.complete();

      final ResultadoLogin resultadoInicial = await loginInicial;
      final ResultadoConsultaPortal<String> resultadoConsulta = await consulta;

      expect(resultadoInicial.autenticada, isFalse);
      expect(resultadoConsulta.sucesso, isTrue);
      expect(logins, 2);
      expect(consultas, 1);
      await sessao.encerrar();
    },
  );

  test(
      'renovação falha uma vez para chamadas concorrentes e consulta futura tenta de novo',
      () async {
    int logins = 0;
    int consultas = 0;
    final Completer<void> duasConsultas = Completer<void>();
    final _AdapterTeste adapter = _AdapterTeste((RequestOptions request) async {
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idLogin) {
        logins++;
        if (logins == 2) return _resposta('<html>sem login</html>', 200);
        return _resposta(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['/prestador/'],
          },
        );
      }
      if (request.uri.path == '/prestador/') {
        return _resposta('<html>logout</html>', 200);
      }
      if (request.method == 'POST' &&
          request.uri.queryParameters['lumPageId'] == _idConsulta) {
        consultas++;
        if (consultas <= 2) {
          if (consultas == 2) duasConsultas.complete();
          await duasConsultas.future;
          return _resposta('sessao expirada', 403);
        }
        return _resposta('<html>elegivel</html>', 200);
      }
      return _resposta('<html>formulario</html>', 200);
    });
    final SessaoPortal sessao = SessaoPortal(
      dio: Dio()..httpClientAdapter = adapter,
      logger: Logger(output: const _LogMudo(), level: Level.off),
    );
    await _login(sessao);

    final List<ResultadoConsultaPortal<String>> concorrentes =
        await Future.wait(<Future<ResultadoConsultaPortal<String>>>[
      sessao.consultarBeneficiario(carteirinhaCompleta: '12345678901234567890'),
      sessao.consultarBeneficiario(carteirinhaCompleta: '98765432109876543210'),
    ]);
    expect(concorrentes.every((resultado) => !resultado.sucesso), isTrue);
    expect(logins, 2);
    expect(sessao.diagnosticoSessao['rejeicoes403'], 2);
    expect(sessao.diagnosticoSessao['renovacoesIniciadas'], 1);
    expect(sessao.diagnosticoSessao['renovacoesSucesso'], 0);
    expect(sessao.diagnosticoSessao['renovacoesFalhaCredenciaisInvalidas'], 1);

    final ResultadoConsultaPortal<String> posterior = await sessao
        .consultarBeneficiario(carteirinhaCompleta: '12345678901234567890');
    expect(posterior.sucesso, isTrue);
    expect(logins, 3);
    expect(consultas, 3);
    expect(sessao.diagnosticoSessao['renovacoesIniciadas'], 2);
    expect(sessao.diagnosticoSessao['renovacoesSucesso'], 1);
    await sessao.encerrar();
  });
}

Future<void> _login(SessaoPortal sessao) async {
  final ResultadoLogin resultado = await sessao.login(
    code: 'code',
    user: 'user',
    senha: 'senha',
  );
  expect(resultado.autenticada, isTrue);
}
