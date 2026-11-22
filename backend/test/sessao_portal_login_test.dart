import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

/// Adapter que responde por "METODO caminho", sem tocar a rede.
class _AdapterFake implements HttpClientAdapter {
  _AdapterFake(this.respostas);

  final Map<String, ResponseBody> respostas;
  final List<Uri> requisicoes = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requisicoes.add(options.uri);
    return respostas['${options.method} ${options.uri.path}'] ??
        ResponseBody.fromString('sem resposta', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterFalhaF5 implements HttpClientAdapter {
  int requisicoes = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requisicoes++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 503,
        data: '<html><title>Rejected</title>Support ID ABC12345</html>',
        headers: Headers.fromMap(<String, List<String>>{
          'content-type': <String>['text/html; charset=utf-8'],
        }),
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterLoginBloqueado implements HttpClientAdapter {
  _AdapterLoginBloqueado(this.liberarGet);

  final Completer<void> liberarGet;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.uri.path == '/main.jsp') {
      await liberarGet.future;
      return ResponseBody.fromString('<html>formulario</html>', 200);
    }
    if (options.method == 'POST' && options.uri.path == '/main.jsp') {
      return ResponseBody.fromString(
        '',
        302,
        headers: <String, List<String>>{
          'location': <String>['/prestador/'],
        },
      );
    }
    if (options.method == 'GET' && options.uri.path == '/prestador/') {
      return ResponseBody.fromString('<html>logout</html>', 200);
    }
    return ResponseBody.fromString('sem resposta', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SessaoPortal - leitura do Location', () {
    test('Location repetido autentica em vez de virar falha de rede', () async {
      // `headers.value('location')` lanca `Exception` quando o header chega
      // duplicado. A excecao subia para o `catch` do login e a resposta ao
      // cliente saia como "falha de rede". O login deve seguir o primeiro
      // valor do header e autenticar.
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()
          ..httpClientAdapter = _AdapterFake(<String, ResponseBody>{
            'GET /main.jsp': ResponseBody.fromString(
              '<html>formulario</html>',
              200,
            ),
            'POST /main.jsp': ResponseBody.fromString(
              '',
              302,
              headers: <String, List<String>>{
                'location': <String>['/prestador/', '/redundante/'],
              },
            ),
            'GET /prestador/': ResponseBody.fromString(
              '<html>logout</html>',
              200,
            ),
          }),
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, isNull);
      expect(resultado.autenticada, isTrue);
      expect(sessao.diagnosticoSessao['loginGetHttp200'], 1);
      expect(sessao.diagnosticoSessao['loginPostHttp302'], 1);
      expect(sessao.diagnosticoSessao['loginRedirectHttp200'], 1);
      expect(sessao.diagnosticoSessao['loginAutenticado'], 1);
      await sessao.encerrar();
    });

    test('Location ausente no 302 vira resposta inesperada', () async {
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()
          ..httpClientAdapter = _AdapterFake(<String, ResponseBody>{
            'GET /main.jsp': ResponseBody.fromString(
              '<html>formulario</html>',
              200,
            ),
            'POST /main.jsp': ResponseBody.fromString('', 302),
          }),
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, MotivoFalhaLogin.respostaInesperada);
      expect(resultado.motivo, isNot(MotivoFalhaLogin.falhaRede));
      expect(sessao.diagnosticoSessao['loginPostHttp302'], 1);
      expect(sessao.diagnosticoSessao['loginRedirectSemLocation'], 1);
      await sessao.encerrar();
    });

    test('redirect para outro host e rejeitado antes da requisicao', () async {
      final _AdapterFake adapter = _AdapterFake(<String, ResponseBody>{
        'GET /main.jsp': ResponseBody.fromString(
          '<html>formulario</html>',
          200,
        ),
        'POST /main.jsp': ResponseBody.fromString(
          '',
          302,
          headers: <String, List<String>>{
            'location': <String>['https://example.invalid/fora'],
          },
        ),
      });
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()..httpClientAdapter = adapter,
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, MotivoFalhaLogin.respostaInesperada);
      expect(adapter.requisicoes, hasLength(2));
      expect(
        adapter.requisicoes.any((Uri uri) => uri.host == 'example.invalid'),
        isFalse,
      );
      expect(sessao.diagnosticoSessao['redirectDestinoInvalido'], 1);
      await sessao.encerrar();
    });

    test('registra status inesperado do GET sem guardar resposta', () async {
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()
          ..httpClientAdapter = _AdapterFake(<String, ResponseBody>{
            'GET /main.jsp': ResponseBody.fromString(
              '<html><title>Request rejected</title>Support ID: ABCD123456</html>',
              403,
              headers: <String, List<String>>{
                'content-type': <String>['text/html; charset=utf-8'],
              },
            ),
          }),
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, MotivoFalhaLogin.respostaInesperada);
      expect(sessao.diagnosticoSessao['loginGetHttp403'], 1);
      expect(sessao.diagnosticoSessao['loginGetRespostaInesperada'], 1);
      expect(sessao.diagnosticoSessao['assinaturaResposta'], 1);
      await sessao.encerrar();
    });

    test(
      'resposta F5 anexada a erro de transporte não vira retry de rede',
      () async {
        final _AdapterFalhaF5 adapter = _AdapterFalhaF5();
        final SessaoPortal sessao = SessaoPortal(
          dio: Dio()..httpClientAdapter = adapter,
        );

        final ResultadoLogin resultado = await sessao.login(
          code: 'codigo',
          user: 'usuario',
          senha: 'senha',
        );

        expect(adapter.requisicoes, 1);
        expect(resultado.autenticada, isFalse);
        expect(resultado.motivo, MotivoFalhaLogin.respostaInesperada);
        expect(sessao.diagnosticoSessao['assinaturaF5Rejected'], 1);
        await sessao.encerrar();
      },
    );
  });

  test('limita logins globais e publica métricas de fila', () async {
    final int limite = SessaoPortal.diagnosticoLogins['limite']!;
    if (Platform.environment['PORTAL_LOGIN_MAX_CONCORRENCIA'] == null) {
      expect(limite, 2);
    }
    final Completer<void> liberarGet = Completer<void>();
    final List<SessaoPortal> sessoes = List<SessaoPortal>.generate(
      limite + 1,
      (_) => SessaoPortal(
        dio: Dio()..httpClientAdapter = _AdapterLoginBloqueado(liberarGet),
      ),
      growable: false,
    );
    final List<Future<ResultadoLogin>> logins = sessoes
        .map(
          (SessaoPortal sessao) =>
              sessao.login(code: 'codigo', user: 'usuario', senha: 'senha'),
        )
        .toList();

    try {
      await Future<void>.delayed(Duration.zero);
      final Map<String, int> diagnostico = SessaoPortal.diagnosticoLogins;
      expect(diagnostico['ativasAgora'], limite);
      expect(diagnostico['aguardandoAgora'], 1);
      expect(diagnostico['picoAtivas'], greaterThanOrEqualTo(limite));
      expect(diagnostico['picoAguardando'], greaterThanOrEqualTo(1));

      liberarGet.complete();
      final List<ResultadoLogin> resultados = await Future.wait(logins);
      expect(resultados.every((ResultadoLogin r) => r.autenticada), isTrue);
    } finally {
      if (!liberarGet.isCompleted) liberarGet.complete();
      await Future.wait(logins);
      await Future.wait<void>(
        sessoes.map((SessaoPortal sessao) => sessao.encerrar()),
      );
    }
  });
}
