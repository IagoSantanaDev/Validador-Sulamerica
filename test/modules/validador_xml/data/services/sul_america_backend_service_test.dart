import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  final int statusCode;
  final Map<String, dynamic> corpo;
  final Map<String, List<String>> cabecalhos;
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

SulAmericaBackendService _servicoCom(_AdapterFake adapter) {
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
  group('criarSessao', () {
    test(
      'envia o identificador sem token no corpo e devolve o token',
      () async {
        final _AdapterFake adapter = _AdapterFake(
          statusCode: 201,
          corpo: {
            'token': 'abc123',
            'identificadorPrestador': '27372066000673',
          },
        );

        final resultado = await _servicoCom(
          adapter,
        ).criarSessao(identificadorPrestador: '27372066000673');

        resultado.fold(
          onSuccess: (String token) => expect(token, 'abc123'),
          onFailure: (AppException erro) => fail('Esperava sucesso: $erro'),
        );
        final RequestOptions requisicao = adapter.requisicoes.single;
        expect(requisicao.path, '/api/sessoes');
        expect(requisicao.method, 'POST');
        expect(requisicao.data, {'identificadorPrestador': '27372066000673'});
        expect(requisicao.uri.toString(), isNot(contains('abc123')));
        expect(jsonEncode(requisicao.data), isNot(contains('token')));
      },
    );

    test('401 vira NaoAutorizadoException', () async {
      final adapter = _AdapterFake(
        statusCode: 401,
        corpo: {'status': 'erro', 'mensagem': 'credencial recusada'},
      );

      final resultado = await _servicoCom(
        adapter,
      ).criarSessao(identificadorPrestador: '27372066000673');

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (AppException erro) =>
            expect(erro, isA<NaoAutorizadoException>()),
      );
    });
  });

  group('criarLote', () {
    test('envia Bearer e Idempotency-Key e lê 202 com Location', () async {
      final _AdapterFake adapter = _AdapterFake(
        statusCode: 202,
        corpo: {'id': 'lote-1', 'estado': 'na_fila', 'total': 2},
        cabecalhos: {
          'location': ['/api/lotes/lote-1/eventos'],
          'retry-after': ['10'],
        },
      );

      final resultado = await _servicoCom(adapter).criarLote(
        token: 'token-secreto',
        idempotencyKey: 'chave-1',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (lote) {
          expect(lote.id, 'lote-1');
          expect(lote.estado, 'na_fila');
          expect(lote.total, 2);
          expect(lote.location, '/api/lotes/lote-1/eventos');
        },
        onFailure: (AppException erro) => fail('Esperava sucesso: $erro'),
      );
      final RequestOptions requisicao = adapter.requisicoes.single;
      expect(requisicao.path, '/api/lotes');
      expect(requisicao.headers['Authorization'], 'Bearer token-secreto');
      expect(requisicao.headers['Idempotency-Key'], 'chave-1');
      expect(requisicao.data, {
        'consultas': [
          {'tipo': 'elegibilidade', 'chave': '123'},
          {'tipo': 'senha', 'chave': '456'},
        ],
      });
      expect(jsonEncode(requisicao.data), isNot(contains('token-secreto')));
      expect(requisicao.uri.toString(), isNot(contains('token-secreto')));
    });

    test('404 vira RecursoNaoEncontradoException', () async {
      final adapter = _AdapterFake(statusCode: 404);

      final resultado = await _servicoCom(adapter).criarLote(
        token: 'token-secreto',
        idempotencyKey: 'chave-1',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (AppException erro) =>
            expect(erro, isA<RecursoNaoEncontradoException>()),
      );
    });

    test('429 vira FilaCheiaException com Retry-After', () async {
      final adapter = _AdapterFake(
        statusCode: 429,
        corpo: {'status': 'erro', 'mensagem': 'fila cheia'},
        cabecalhos: {
          'retry-after': ['10'],
        },
      );

      final resultado = await _servicoCom(adapter).criarLote(
        token: 'token-secreto',
        idempotencyKey: 'chave-1',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (AppException erro) {
          expect(erro, isA<FilaCheiaException>());
          expect(
            (erro as FilaCheiaException).retryAfter,
            const Duration(seconds: 10),
          );
        },
      );
    });

    test('5xx vira ErroServidorException com o status', () async {
      final adapter = _AdapterFake(statusCode: 503);

      final resultado = await _servicoCom(adapter).criarLote(
        token: 'token-secreto',
        idempotencyKey: 'chave-1',
        consultas: _consultas,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (AppException erro) {
          expect(erro, isA<ErroServidorException>());
          expect((erro as ErroServidorException).statusCode, 503);
        },
      );
    });

    test('status() segue disponível para a verificação de conexão', () async {
      final adapter = _AdapterFake(
        statusCode: 200,
        corpo: {'status': 'ok', 'sessoesAtivas': 1},
      );

      final resultado = await _servicoCom(adapter).status();

      resultado.fold(
        onSuccess: (dados) => expect(dados['status'], 'ok'),
        onFailure: (AppException erro) => fail('Esperava sucesso: $erro'),
      );
      expect(adapter.requisicoes.single.path, '/api/status');
    });
  });

  group('abrirEventos', () {
    test('monta a URL de eventos sem expor o token', () {
      final Uri url = SulAmericaBackendService.montarUrlEventos(
        'https://validador-api.onrender.com/',
        'lote-1',
        desde: 12,
      );

      expect(
        url.toString(),
        'https://validador-api.onrender.com/api/lotes/lote-1/eventos?desde=12',
      );
      expect(url.toString(), isNot(contains('Bearer')));
    });

    test('fora do web falha com erro explícito', () {
      final _AdapterFake adapter = _AdapterFake();

      expect(
        () => _servicoCom(
          adapter,
        ).abrirEventos(token: 'token-secreto', idLote: 'lote-1'),
        throwsUnsupportedError,
      );
    });
  });
}
