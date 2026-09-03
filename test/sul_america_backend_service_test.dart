import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/app_exception.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';

/// Adapter falso que devolve uma resposta pré-definida — sem chamada de
/// rede real (inclusive permite testar o mapeamento de erros do proxy,
/// que responde com status HTTP 4xx/5xx e corpo JSON).
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
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(corpo)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

SulAmericaBackendService _servico({
  required int statusCode,
  required Map<String, dynamic> corpo,
}) {
  final Dio dio = Dio()
    ..httpClientAdapter =
        _FakeHttpClientAdapter(statusCode: statusCode, corpo: corpo);
  return SulAmericaBackendService(
    DioClient(baseUrl: 'http://localhost:8080', dio: dio),
  );
}

void main() {
  group('SulAmericaBackendService', () {
    test('login devolve o token do backend em Success', () async {
      final servico = _servico(
        statusCode: 200,
        corpo: {'token': 'a1b2c3d4', 'autenticada': true},
      );

      final resultado = await servico.login(
        code: '100000015513',
        user: 'master',
        senha: 'x',
      );

      resultado.fold(
        onSuccess: (token) => expect(token, 'a1b2c3d4'),
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });

    test('consulta de beneficiário parseia elegivel/rotulo/html', () async {
      final servico = _servico(
        statusCode: 200,
        corpo: {
          'status': 'ok',
          'elegivel': true,
          'rotuloElegibilidade': 'SIM',
          'html': '<html>elegibilidade-resultado</html>',
        },
      );

      final resultado = await servico.consultarBeneficiario(
        token: 'a1b2c3d4',
        carteira: '58201824004384300010',
      );

      resultado.fold(
        onSuccess: (res) {
          expect(res.elegivel, isTrue);
          expect(res.rotuloElegibilidade, 'SIM');
          expect(res.temResultadoElegibilidade, isTrue);
          expect(res.html, contains('elegibilidade-resultado'));
        },
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });

    test('consulta sem resultado de elegibilidade devolve null', () async {
      final servico = _servico(
        statusCode: 200,
        corpo: {
          'status': 'ok',
          'elegivel': null,
          'rotuloElegibilidade': null,
          'html': '<html>Identificação</html>',
        },
      );

      final resultado = await servico.consultarBeneficiario(
        token: 'a1b2c3d4',
        carteira: '99999999999999999999',
      );

      resultado.fold(
        onSuccess: (res) {
          expect(res.elegivel, isNull);
          expect(res.temResultadoElegibilidade, isFalse);
        },
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });

    test('login com 401 (senha errada) mapeia NaoAutorizadoException', () async {
      final servico = _servico(
        statusCode: 401,
        corpo: {'status': 'erro', 'mensagem': 'Falha ao autenticar'},
      );

      final resultado = await servico.login(
        code: '100000015513',
        user: 'master',
        senha: 'errada',
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<NaoAutorizadoException>()),
      );
    });

    test('autorização VPP devolve o JSON do portal', () async {
      final servico = _servico(
        statusCode: 200,
        corpo: {
          'paginacao': {'total_registros': 1},
          'registros': [
            {
              'numero_solicitacao': '239675343',
              'status_solicitacao': {'descricao': 'Autorizado'},
            },
          ],
        },
      );

      final resultado = await servico.autorizacaoVpp(
        token: 'a1b2c3d4',
        numeroVpp: '5056654786',
      );

      resultado.fold(
        onSuccess: (dados) {
          expect(dados['paginacao']['total_registros'], 1);
          final registros = dados['registros'] as List;
          expect(
            (registros.first as Map)['numero_solicitacao'],
            '239675343',
          );
        },
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });
  });
}