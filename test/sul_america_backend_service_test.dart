import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/app_exception.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_lote.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.statusCode, required this.corpo});

  final int statusCode;
  final Map<String, dynamic> corpo;
  final List<Object?> corposEnviados = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    corposEnviados.add(options.data);
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
  _FakeHttpClientAdapter? adapter,
}) {
  final Dio dio = Dio()
    ..httpClientAdapter =
        adapter ?? _FakeHttpClientAdapter(statusCode: statusCode, corpo: corpo);
  return SulAmericaBackendService(
    DioClient(baseUrl: 'http://localhost:8080', dio: dio),
  );
}

void main() {
  group('SulAmericaBackendService', () {
    test('login devolve o token do backend em Success', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter(
        statusCode: 200,
        corpo: {'token': 'a1b2c3d4', 'autenticada': true},
      );
      final servico = _servico(
        statusCode: 200,
        corpo: {'token': 'a1b2c3d4', 'autenticada': true},
        adapter: adapter,
      );

      final resultado = await servico.login(
        identificadorPrestador: '27372066000673',
      );

      resultado.fold(
        onSuccess: (token) => expect(token, 'a1b2c3d4'),
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
      expect(adapter.corposEnviados, [
        {'identificadorPrestador': '27372066000673'},
      ]);
    });

    test('consultarLote parseia resultados de elegibilidade e senha', () async {
      final servico = _servico(
        statusCode: 200,
        corpo: {
          'status': 'ok',
          'resultados': [
            {
              'chave': '58201824004384300010',
              'tipo': 'elegibilidade',
              'sucesso': true,
              'elegivel': true,
              'rotuloElegibilidade': 'SIM',
            },
            {
              'chave': '5056654786',
              'tipo': 'senha',
              'sucesso': true,
              'statusSenha': 'Autorizado parcialmente',
            },
          ],
        },
      );

      final resultado = await servico.consultarLote(
        token: 'a1b2c3d4',
        consultas: const [
          ConsultaLoteItem(
            tipo: TipoConsultaGuia.elegibilidade,
            chave: '58201824004384300010',
          ),
          ConsultaLoteItem(
            tipo: TipoConsultaGuia.senha,
            chave: '5056654786',
          ),
        ],
      );

      resultado.fold(
        onSuccess: (itens) {
          expect(itens, hasLength(2));
          expect(itens[0].tipo, TipoConsultaGuia.elegibilidade);
          expect(itens[0].elegivel, isTrue);
          expect(itens[1].tipo, TipoConsultaGuia.senha);
          expect(itens[1].statusSenha, 'Autorizado parcialmente');
        },
        onFailure: (erro) => fail('Esperava sucesso, veio: $erro'),
      );
    });

    test('login com 401 (senha errada) mapeia NaoAutorizadoException',
        () async {
      final servico = _servico(
        statusCode: 401,
        corpo: {'status': 'erro', 'mensagem': 'Falha ao autenticar'},
      );

      final resultado = await servico.login(
        identificadorPrestador: '27372066000673',
      );

      resultado.fold(
        onSuccess: (_) => fail('Esperava falha'),
        onFailure: (erro) => expect(erro, isA<NaoAutorizadoException>()),
      );
    });
  });
}
