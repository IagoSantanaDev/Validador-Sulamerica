import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/http/auth.dart';

Request _request({String? authorization}) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/lotes'),
    headers: authorization == null
        ? null
        : <String, String>{'authorization': authorization},
  );
}

void main() {
  group('tokenBearer', () {
    test('extrai o token de um header Bearer valido', () {
      expect(
        tokenBearer(_request(authorization: 'Bearer abc123')),
        'abc123',
      );
    });

    test('aceita esquema em qualquer caixa', () {
      expect(
        tokenBearer(_request(authorization: 'bearer abc123')),
        'abc123',
      );
      expect(
        tokenBearer(_request(authorization: 'BEARER abc123')),
        'abc123',
      );
    });

    test('aceita espacos extras entre esquema e token', () {
      expect(
        tokenBearer(_request(authorization: '  Bearer   abc123  ')),
        'abc123',
      );
    });

    test('devolve null quando o header esta ausente', () {
      expect(tokenBearer(_request()), isNull);
    });

    test('devolve null para esquema diferente de Bearer', () {
      expect(
        tokenBearer(_request(authorization: 'Basic abc123')),
        isNull,
      );
      expect(
        tokenBearer(_request(authorization: 'Token abc123')),
        isNull,
      );
    });

    test('devolve null para Bearer sem token', () {
      expect(tokenBearer(_request(authorization: 'Bearer')), isNull);
      expect(tokenBearer(_request(authorization: 'Bearer   ')), isNull);
    });

    test('devolve null para header vazio', () {
      expect(tokenBearer(_request(authorization: '')), isNull);
    });

    test('devolve null para formato com mais de duas partes', () {
      expect(
        tokenBearer(_request(authorization: 'Bearer abc 123')),
        isNull,
      );
    });
  });
}
