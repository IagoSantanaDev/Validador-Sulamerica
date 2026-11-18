import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';
import 'package:validador_backend/validador_api.dart';

const Map<String, String> _ambienteFake = {
  'PORTAL_PRESTADOR_ID_TESTE_A_CODE': 'fake-code-a',
  'PORTAL_PRESTADOR_ID_TESTE_A_USER': 'fake-user-a',
  'PORTAL_PRESTADOR_ID_TESTE_A_SENHA': 'fake-password-a',
  'PORTAL_PRESTADOR_ID_TESTE_B_CODE': 'fake-code-b',
  'PORTAL_PRESTADOR_ID_TESTE_B_USER': 'fake-user-b',
  'PORTAL_PRESTADOR_ID_TESTE_B_SENHA': 'fake-password-b',
};

class _LogSilencioso implements LogOutput {
  const _LogSilencioso();

  @override
  Future<void> destroy() async {}

  @override
  Future<void> init() async {}

  @override
  void output(OutputEvent event) {}
}

class SessaoPortalFake extends SessaoPortal {
  SessaoPortalFake(this.latencia)
      : super(logger: Logger(output: const _LogSilencioso()));

  final Duration latencia;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async =>
      const ResultadoLogin.autenticado();

  @override
  Future<ResultadoLogin> garantirAutenticada() async =>
      const ResultadoLogin.autenticado();

  @override
  Future<ResultadoConsultaPortal<String>> consultarBeneficiario({
    required String carteirinhaCompleta,
    CancelToken? cancelToken,
  }) async {
    await _aguardar(cancelToken);
    return const ResultadoConsultaPortal<String>.sucesso(
      dados: '<html>elegivel=true</html>',
      status: 200,
    );
  }

  @override
  Future<ResultadoConsultaPortal<Map<String, dynamic>>> consultarSenha({
    required String senha,
    CancelToken? cancelToken,
  }) async {
    await _aguardar(cancelToken);
    return const ResultadoConsultaPortal<Map<String, dynamic>>.sucesso(
      dados: <String, dynamic>{
        'registros': <Object>[
          <String, Object>{
            'status_solicitacao': <String, String>{'descricao': 'Autorizado'},
          },
        ],
      },
      status: 200,
    );
  }

  Future<void> _aguardar(CancelToken? cancelToken) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const OperacaoPortalCanceladaException();
    }
    if (latencia <= Duration.zero) return;
    await Future.any<void>([
      Future<void>.delayed(latencia),
      if (cancelToken != null)
        cancelToken.whenCancel.then<void>(
          (_) => throw const OperacaoPortalCanceladaException(),
        ),
    ]);
  }

  @override
  Future<void> encerrar() async {}
}

/// Executa uma rodada de carga exclusivamente contra o servidor local e
/// devolve métricas agregadas em formato serializável como JSON.
Future<Map<String, Object>> executarCarga({
  required bool dividirIdentificadores,
  int clientes = 12,
  int itensPorCliente = 300,
  Duration latencia = const Duration(milliseconds: 5),
}) async {
  final ValidadorApi api = ValidadorApi(
    logger: Logger(output: const _LogSilencioso()),
    ambiente: _ambienteFake,
    fabricaSessao: (_) => SessaoPortalFake(latencia),
  );
  final HttpServer servidor = await shelf_io.serve(
    api.handler,
    InternetAddress.loopbackIPv4,
    0,
  );
  final HttpClient clienteHttp = HttpClient();
  final Uri base = Uri(
    scheme: 'http',
    host: servidor.address.address,
    port: servidor.port,
  );

  try {
    final List<int> duracoes = await Future.wait([
      for (int indice = 0; indice < clientes; indice++)
        _executarCliente(
          clienteHttp,
          base,
          indice: indice,
          identificador:
              dividirIdentificadores && indice.isOdd ? 'TESTE_B' : 'TESTE_A',
          itens: itensPorCliente,
        ),
    ]);
    duracoes.sort();

    return <String, Object>{
      'cenario': dividirIdentificadores
          ? 'identificadores_divididos'
          : 'identificador_unico',
      'clientes': clientes,
      'itensPorCliente': itensPorCliente,
      'concluidos': duracoes.length,
      'rejeicoes429': 0,
      'duracaoMs': <String, num>{
        'p50': _percentil(duracoes, 0.50),
        'p95': _percentil(duracoes, 0.95),
      },
      'rssMb': ProcessInfo.currentRss / (1024 * 1024),
    };
  } finally {
    clienteHttp.close(force: true);
    await servidor.close(force: true);
  }
}

Future<int> _executarCliente(
  HttpClient cliente,
  Uri base, {
  required int indice,
  required String identificador,
  required int itens,
}) async {
  final Stopwatch cronometro = Stopwatch()..start();
  final String token = await _criarSessao(cliente, base, identificador);
  final Map<String, dynamic> lote = await _criarLote(
    cliente,
    base,
    token: token,
    indice: indice,
    itens: itens,
  );
  await _aguardarResultado(
    cliente,
    base,
    token: token,
    idLote: lote['id'] as String,
    esperado: itens,
  );
  cronometro.stop();
  return cronometro.elapsedMilliseconds;
}

Future<String> _criarSessao(
  HttpClient cliente,
  Uri base,
  String identificador,
) async {
  final HttpClientRequest request = await cliente.postUrl(
    base.resolve('/api/sessoes'),
  );
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'identificadorPrestador': identificador}));
  final HttpClientResponse response = await request.close();
  final Map<String, dynamic> body = await _jsonResponse(response);
  if (response.statusCode != HttpStatus.created) {
    throw StateError('Criacao da sessao retornou HTTP ${response.statusCode}.');
  }
  return body['token'] as String;
}

Future<Map<String, dynamic>> _criarLote(
  HttpClient cliente,
  Uri base, {
  required String token,
  required int indice,
  required int itens,
}) async {
  final HttpClientRequest request = await cliente.postUrl(
    base.resolve('/api/lotes'),
  );
  request.headers
    ..contentType = ContentType.json
    ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
    ..set('Idempotency-Key', 'load-client-$indice');
  request.write(
    jsonEncode({
      'consultas': [
        for (int i = 0; i < itens; i++)
          {
            'tipo': i.isEven ? 'elegibilidade' : 'senha',
            'chave': i.isEven
                ? '123${i.toString().padLeft(17, '0')}'
                : '5${i.toString().padLeft(9, '0')}',
          },
      ],
    }),
  );
  final HttpClientResponse response = await request.close();
  final Map<String, dynamic> body = await _jsonResponse(response);
  if (response.statusCode != HttpStatus.accepted) {
    throw StateError('Criacao do lote retornou HTTP ${response.statusCode}.');
  }
  return body;
}

Future<void> _aguardarResultado(
  HttpClient cliente,
  Uri base, {
  required String token,
  required String idLote,
  required int esperado,
}) async {
  final HttpClientRequest request = await cliente.getUrl(
    base.resolve('/api/lotes/$idLote/eventos'),
  );
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
    ..set(HttpHeaders.acceptHeader, 'text/event-stream');
  final HttpClientResponse response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw StateError('SSE retornou HTTP ${response.statusCode}.');
  }

  String evento = '';
  final List<String> dados = [];
  await for (final String linha
      in response.transform(utf8.decoder).transform(const LineSplitter())) {
    if (linha.isEmpty) {
      if (evento == 'resultado' && dados.isNotEmpty) {
        final Map<String, dynamic> payload =
            jsonDecode(dados.join('\n')) as Map<String, dynamic>;
        final List<dynamic> resultados = payload['resultados'] as List<dynamic>;
        if (resultados.length != esperado) {
          throw StateError(
            'Lote $idLote retornou ${resultados.length} de $esperado itens.',
          );
        }
        return;
      }
      if (evento == 'erro' && dados.isNotEmpty) {
        throw StateError('Lote $idLote falhou: ${dados.join('\n')}');
      }
      evento = '';
      dados.clear();
    } else if (linha.startsWith('event:')) {
      evento = linha.substring(6).trim();
    } else if (linha.startsWith('data:')) {
      dados.add(linha.substring(5).trimLeft());
    }
  }
  throw StateError('O stream do lote $idLote terminou sem resultado.');
}

Future<Map<String, dynamic>> _jsonResponse(HttpClientResponse response) async {
  final String body = await response.transform(utf8.decoder).join();
  return jsonDecode(body) as Map<String, dynamic>;
}

num _percentil(List<int> valores, double fracao) {
  if (valores.isEmpty) return 0;
  final int indice = ((valores.length - 1) * fracao).ceil();
  return valores[indice];
}

Future<void> main() async {
  for (final bool dividir in [false, true]) {
    final Map<String, Object> relatorio = await executarCarga(
      dividirIdentificadores: dividir,
    );
    stdout.writeln(jsonEncode(relatorio));
  }
}
