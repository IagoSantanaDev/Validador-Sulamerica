import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/http/json.dart';

Request _request(String corpo) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/lotes'),
    body: corpo,
  );
}

void main() {
  group('lerCorpoJson', () {
    test('devolve o mapa de um corpo JSON valido', () async {
      final Map<String, dynamic>? corpo = await lerCorpoJson(
        _request(jsonEncode({'consultas': <dynamic>[]})),
      );
      expect(corpo, isNotNull);
      expect(corpo!['consultas'], isEmpty);
    });

    test('devolve null para corpo vazio', () async {
      expect(await lerCorpoJson(_request('   ')), isNull);
    });

    test('devolve null para JSON invalido', () async {
      expect(await lerCorpoJson(_request('nao e json')), isNull);
    });

    test('devolve null quando a raiz JSON nao e objeto', () async {
      expect(await lerCorpoJson(_request('[1, 2, 3]')), isNull);
      expect(await lerCorpoJson(_request('"texto"')), isNull);
    });

    test('rejeita corpo acima do limite pelo content-length', () async {
      final String corpoGrande = 'x' * ((1 << 20) + 1);
      expect(
        lerCorpoJson(_request(corpoGrande)),
        throwsA(isA<CorpoJsonExcedeLimite>()),
      );
    });

    test('rejeita corpo acima do limite durante o streaming', () async {
      final String corpoGrande = 'x' * ((1 << 20) + 1);
      final Request request = Request(
        'POST',
        Uri.parse('http://localhost/api/lotes'),
        body: Stream<List<int>>.value(utf8.encode(corpoGrande)),
      );
      expect(request.contentLength, isNull);
      expect(
        lerCorpoJson(request),
        throwsA(isA<CorpoJsonExcedeLimite>()),
      );
    });

    test('aceita corpo exatamente no limite', () async {
      final String enchimento = 'x' * 100;
      final String corpo = jsonEncode({'lixo': enchimento});
      final Map<String, dynamic>? lido = await lerCorpoJson(
        Request(
          'POST',
          Uri.parse('http://localhost/api/lotes'),
          body: Stream<List<int>>.value(utf8.encode(corpo)),
        ),
        limiteBytes: corpo.length,
      );
      expect(lido!['lixo'], enchimento);
    });

    test('respeita limite customizado', () async {
      expect(
        lerCorpoJson(_request('{"a": 1}'), limiteBytes: 4),
        throwsA(
          isA<CorpoJsonExcedeLimite>().having(
            (CorpoJsonExcedeLimite erro) => erro.limiteBytes,
            'limiteBytes',
            4,
          ),
        ),
      );
    });
  });

  group('respostaJson', () {
    test('serializa o corpo com status 200 e content-type JSON', () async {
      final Response resposta = respostaJson({'status': 'ok'});
      expect(resposta.statusCode, 200);
      expect(resposta.headers['content-type'], tipoConteudoJson);
      expect(jsonDecode(await resposta.readAsString()), {'status': 'ok'});
    });

    test('aceita status e headers extras', () async {
      final Response resposta = respostaJson(
        {'id': 'abc'},
        status: 202,
        headers: {'location': '/api/lotes/abc/eventos'},
      );
      expect(resposta.statusCode, 202);
      expect(resposta.headers['location'], '/api/lotes/abc/eventos');
      expect(resposta.headers['content-type'], tipoConteudoJson);
    });
  });

  group('respostaErro', () {
    test('monta o formato padrao de erro', () async {
      final Response resposta = respostaErro('Payload invalido.', 400);
      expect(resposta.statusCode, 400);
      expect(resposta.headers['content-type'], tipoConteudoJson);
      expect(jsonDecode(await resposta.readAsString()), {
        'status': 'erro',
        'mensagem': 'Payload invalido.',
      });
    });
  });

  group('cabecalhosRetryAfter', () {
    test('devolve o valor em segundos', () {
      expect(cabecalhosRetryAfter(10), {'retry-after': '10'});
    });

    test('rejeita segundos negativos', () {
      expect(() => cabecalhosRetryAfter(-1), throwsArgumentError);
    });
  });
}
