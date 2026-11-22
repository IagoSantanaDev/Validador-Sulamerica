import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/constants/app_strings.dart';
import 'package:validador_xml_sulamerica/globals/network/app_exception.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_lote.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';

class _AdapterFake implements HttpClientAdapter {
  _AdapterFake({
    this.statusCode = 202,
    this.corpo = const <String, dynamic>{},
    this.cabecalhos = const <String, List<String>>{},
    this.erro,
  });

  final int statusCode;
  final Map<String, dynamic> corpo;
  final Map<String, List<String>> cabecalhos;
  final Object? erro;
  final List<RequestOptions> requisicoes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requisicoes.add(options);
    if (erro != null) throw erro!;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(corpo)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...cabecalhos,
      },
    );
  }
}

SulAmericaBackendService _servico(_AdapterFake adapter) {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  return SulAmericaBackendService(
    DioClient(baseUrl: 'http://localhost:8080', dio: dio),
  );
}

const List<ConsultaLoteItem> _consultas = [
  ConsultaLoteItem(tipo: TipoConsultaGuia.elegibilidade, chave: '123'),
  ConsultaLoteItem(tipo: TipoConsultaGuia.senha, chave: '456'),
];

void main() {
  group('SulAmericaBackendService', () {
    test('criarSessao envia apenas o identificador e devolve o token', () async {
      final _AdapterFake adapter = _AdapterFake(
        statusCode: 201,
        corpo: {
          'token': 'token-fake',
          'identificadorPrestador': 'TESTE',
        },
      );

      final resultado = await _servico(
        adapter,
      ).criarSessao(identificadorPrestador: 'TESTE');

      resultado.fold(
        onSuccess: (token) => expect(token, 'token-fake'),
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
      final RequestOptions request = adapter.requisicoes.single;
      expect(request.path, '/api/sessoes');
      expect(request.data, {'identificadorPrestador': 'TESTE'});
      expect(request.uri.toString(), isNot(contains('token-fake')));
    });

    test('criarSessao mapeia 401 para NaoAutorizadoException', () async {
      final _AdapterFake adapter = _AdapterFake(
        statusCode: 401,
        corpo: {'status': 'erro', 'mensagem': 'credencial recusada'},
      );

      final resultado = await _servico(
        adapter,
      ).criarSessao(identificadorPrestador: 'TESTE');

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<NaoAutorizadoException>()),
      );
    });

    test('falha inesperada não expõe detalhe técnico', () async {
      final resultado = await _servico(
        _AdapterFake(erro: StateError('TypeError: Failed to fetch')),
      ).criarSessao(identificadorPrestador: 'TESTE');

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) {
          expect(erro.mensagem, AppStrings.erroConsultaBackendGenerico);
          expect(erro.mensagem, isNot(contains('TypeError')));
          expect(erro.mensagem, isNot(contains('Failed to fetch')));
        },
      );
    });

    test('criarLote envia Bearer e idempotência e lê Location', () async {
      final _AdapterFake adapter = _AdapterFake(
        statusCode: 202,
        corpo: {'id': 'lote-fake', 'estado': 'na_fila', 'total': 2},
        cabecalhos: {
          'location': ['/api/lotes/lote-fake/eventos'],
        },
      );

      final resultado = await _servico(adapter).criarLote(
        token: 'token-fake',
        idempotencyKey: 'key-fake',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (lote) {
          expect(lote.id, 'lote-fake');
          expect(lote.location, '/api/lotes/lote-fake/eventos');
          expect(lote.total, 2);
        },
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
      final RequestOptions request = adapter.requisicoes.single;
      expect(request.path, '/api/lotes');
      expect(request.headers['Authorization'], 'Bearer token-fake');
      expect(request.headers['Idempotency-Key'], 'key-fake');
      expect(request.data, {
        'consultas': [
          {'tipo': 'elegibilidade', 'chave': '123'},
          {'tipo': 'senha', 'chave': '456'},
        ],
      });
      expect(jsonEncode(request.data), isNot(contains('token-fake')));
      expect(request.uri.toString(), isNot(contains('token-fake')));
    });

    test('404 mapeia para RecursoNaoEncontradoException', () async {
      final resultado = await _servico(
        _AdapterFake(statusCode: 404),
      ).criarLote(
        token: 'token-fake',
        idempotencyKey: 'key-fake',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<RecursoNaoEncontradoException>()),
      );
    });

    test('429 preserva o header Retry-After', () async {
      final resultado = await _servico(
        _AdapterFake(
          statusCode: 429,
          cabecalhos: {
            'retry-after': ['10'],
          },
        ),
      ).criarLote(
        token: 'token-fake',
        idempotencyKey: 'key-fake',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) {
          expect(erro, isA<FilaCheiaException>());
          expect((erro as FilaCheiaException).retryAfter, const Duration(seconds: 10));
        },
      );
    });

    test('503 preserva Retry-After como indisponibilidade temporária', () async {
      final resultado = await _servico(
        _AdapterFake(
          statusCode: 503,
          cabecalhos: {
            'retry-after': ['45'],
          },
        ),
      ).criarLote(
        token: 'token-fake',
        idempotencyKey: 'key-fake',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) {
          expect(erro, isA<ServicoIndisponivelException>());
          expect(
            (erro as ServicoIndisponivelException).retryAfter,
            const Duration(seconds: 45),
          );
        },
      );
    });

    test('outros 5xx preservam statusCode genérico', () async {
      final resultado = await _servico(
        _AdapterFake(statusCode: 502),
      ).criarLote(
        token: 'token-fake',
        idempotencyKey: 'key-fake',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) {
          expect(erro, isA<ErroServidorException>());
          expect((erro as ErroServidorException).statusCode, 502);
        },
      );
    });

    test('status continua disponível', () async {
      final _AdapterFake adapter = _AdapterFake(
        statusCode: 200,
        corpo: {'status': 'ok'},
      );

      final resultado = await _servico(adapter).status();

      resultado.fold(
        onSuccess: (dados) => expect(dados['status'], 'ok'),
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
      expect(adapter.requisicoes.single.path, '/api/status');
    });

    test('monta URL SSE com retomada sem expor o token', () {
      final Uri url = SulAmericaBackendService.montarUrlEventos(
        'https://api.example.invalid/',
        'lote-fake',
        desde: 17,
      );

      expect(
        url.toString(),
        'https://api.example.invalid/api/lotes/lote-fake/eventos?desde=17',
      );
      expect(url.toString(), isNot(contains('token-fake')));
    });

    test('fora do web, SSE falha explicitamente', () {
      expect(
        () => _servico(_AdapterFake()).abrirEventos(
          token: 'token-fake',
          idLote: 'lote-fake',
        ),
        throwsUnsupportedError,
      );
    });
  });
}
