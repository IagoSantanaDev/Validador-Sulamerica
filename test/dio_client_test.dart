import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/app_exception.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.statusCode, required this.corpo});

  final int statusCode;
  final Map<String, dynamic> corpo;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int> bytes = utf8.encode(jsonEncode(corpo));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

DioClient _criarClienteComRespostaFalsa({
  required int statusCode,
  required Map<String, dynamic> corpo,
}) {
  final Dio dio = Dio()
    ..httpClientAdapter =
        _FakeHttpClientAdapter(statusCode: statusCode, corpo: corpo);
  return DioClient(baseUrl: 'https://exemplo.com', dio: dio);
}

void main() {
  group('DioClient', () {
    test('retorna Success quando a resposta é 200', () async {
      final DioClient client = _criarClienteComRespostaFalsa(
        statusCode: 200,
        corpo: {'nome': 'ok'},
      );

      final resultado = await client.get<String>(
        '/status',
        parser: (dados) => dados['nome'] as String,
      );

      resultado.fold(
        onSuccess: (valor) => expect(valor, 'ok'),
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });

    test('mapeia status 404 para RecursoNaoEncontradoException', () async {
      final DioClient client = _criarClienteComRespostaFalsa(
        statusCode: 404,
        corpo: {'mensagem': 'nao encontrado'},
      );

      final resultado = await client.get<dynamic>(
        '/inexistente',
        parser: (dados) => dados,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<RecursoNaoEncontradoException>()),
      );
    });

    test('mapeia status 401 para NaoAutorizadoException', () async {
      final DioClient client = _criarClienteComRespostaFalsa(
        statusCode: 401,
        corpo: {'mensagem': 'nao autorizado'},
      );

      final resultado = await client.get<dynamic>(
        '/protegido',
        parser: (dados) => dados,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<NaoAutorizadoException>()),
      );
    });

    test('mapeia status 500 para ErroServidorException com o statusCode',
        () async {
      final DioClient client = _criarClienteComRespostaFalsa(
        statusCode: 500,
        corpo: {'mensagem': 'falha interna'},
      );

      final resultado = await client.get<dynamic>(
        '/instavel',
        parser: (dados) => dados,
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) {
          expect(erro, isA<ErroServidorException>());
          expect((erro as ErroServidorException).statusCode, 500);
        },
      );
    });
  });
}
