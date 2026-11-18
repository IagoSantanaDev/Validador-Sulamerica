import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/http/cors.dart';
import 'package:validador_backend/http/json.dart';

const String _producao = 'https://validador-sulamerica.pages.dev';
const String _local = 'http://localhost:3000';

Handler get _handlerInterno => (Request request) {
      return respostaJson({'status': 'ok'});
    };

Future<Response> _chamar(
  Middleware middleware,
  String metodo, {
  String? origin,
}) async {
  final Handler handler = const Pipeline()
      .addMiddleware(middleware)
      .addHandler(_handlerInterno);
  return await handler(
    Request(
      metodo,
      Uri.parse('http://localhost/api/lotes'),
      headers: origin == null ? null : <String, String>{'origin': origin},
    ),
  );
}

void main() {
  group('cors - lista de origens', () {
    test('ecoa apenas a origem da lista que casou', () async {
      final Middleware middleware = cors(origens: [_producao, _local]);
      final Response resposta = await _chamar(
        middleware,
        'POST',
        origin: _producao,
      );
      expect(resposta.headers['access-control-allow-origin'], _producao);
      expect(resposta.headers['vary'], 'origin');
    });

    test('a segunda origem da lista tambem casa', () async {
      final Middleware middleware = cors(origens: [_producao, _local]);
      final Response resposta = await _chamar(
        middleware,
        'POST',
        origin: _local,
      );
      expect(resposta.headers['access-control-allow-origin'], _local);
    });

    test('nao devolve header para origem fora da lista', () async {
      final Middleware middleware = cors(origens: [_producao, _local]);
      final Response resposta = await _chamar(
        middleware,
        'POST',
        origin: 'https://ataque.example',
      );
      expect(
        resposta.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
      expect(resposta.headers.containsKey('vary'), isFalse);
    });

    test('nao devolve header quando a requisicao nao tem Origin', () async {
      final Middleware middleware = cors(origens: [_producao]);
      final Response resposta = await _chamar(middleware, 'POST');
      expect(
        resposta.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });

    test('normaliza espacos, barra final e itens vazios', () async {
      final Middleware middleware = cors(
        origens: [
          '  $_producao/  ',
          '',
          '$_local//',
          ',',
        ],
      );
      expect(
        (await _chamar(middleware, 'POST', origin: _producao))
            .headers['access-control-allow-origin'],
        _producao,
      );
      expect(
        (await _chamar(middleware, 'POST', origin: _local))
            .headers['access-control-allow-origin'],
        _local,
      );
      expect(
        (await _chamar(middleware, 'POST', origin: ''))
            .headers
            .containsKey('access-control-allow-origin'),
        isFalse,
      );
    });

    test('lista vazia mantem o wildcard', () async {
      final Response resposta = await _chamar(
        cors(),
        'POST',
        origin: _producao,
      );
      expect(resposta.headers['access-control-allow-origin'], '*');
      expect(resposta.headers.containsKey('vary'), isFalse);
    });

    test('asterisco na lista devolve wildcard sem Vary', () async {
      final Middleware middleware = cors(origens: [_producao, '*']);
      final Response resposta = await _chamar(
        middleware,
        'POST',
        origin: 'https://qualquer.example',
      );
      expect(resposta.headers['access-control-allow-origin'], '*');
      expect(resposta.headers.containsKey('vary'), isFalse);
    });
  });

  group('cors - preflight', () {
    test('OPTIONS responde 200 com metodos e headers permitidos', () async {
      final Middleware middleware = cors(origens: [_producao]);
      final Response resposta = await _chamar(
        middleware,
        'OPTIONS',
        origin: _producao,
      );
      expect(resposta.statusCode, 200);
      expect(resposta.headers['access-control-allow-origin'], _producao);
      expect(
        resposta.headers['access-control-allow-methods'],
        metodosPermitidosCors,
      );
      expect(
        resposta.headers['access-control-allow-headers'],
        contains('Authorization'),
      );
      expect(
        resposta.headers['access-control-allow-headers'],
        contains('Idempotency-Key'),
      );
      expect(
        resposta.headers['access-control-allow-headers'],
        contains('Last-Event-ID'),
      );
      expect(
        resposta.headers['access-control-allow-headers'],
        contains('Content-Type'),
      );
      expect(resposta.headers['access-control-expose-headers'], 'Location');
      expect(resposta.headers['access-control-max-age'], '86400');
    });

    test('preflight de origem fora da lista nao ecoa a origem', () async {
      final Middleware middleware = cors(origens: [_producao]);
      final Response resposta = await _chamar(
        middleware,
        'OPTIONS',
        origin: 'https://ataque.example',
      );
      expect(
        resposta.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });
  });

  group('cors - resposta real', () {
    test('preserva headers internos e adiciona os de CORS', () async {
      final Middleware middleware = cors(origens: [_producao]);
      final Response resposta = await _chamar(
        middleware,
        'POST',
        origin: _producao,
      );
      expect(resposta.statusCode, 200);
      expect(resposta.headers['content-type'], tipoConteudoJson);
      expect(resposta.headers['access-control-allow-origin'], _producao);
      expect(resposta.headers['access-control-expose-headers'], 'Location');
    });
  });
}
