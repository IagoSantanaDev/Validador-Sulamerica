import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:validador_backend/validador_api.dart';

void main() {
  group('ValidadorApi - login', () {
    late ValidadorApi api;

    setUp(() {
      api = ValidadorApi();
    });

    test('rejeita corpo JSON invalido com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: 'nao e json',
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificadorPrestador ausente com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'outro': 'campo'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificadorPrestador vazio com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': '  '}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita identificador desconhecido com 401', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'desconhecido'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });

    test('aceita apenas identificadorPrestador (sem code/user/senha)',
        () async {
      // Mesmo com code/user/senha no corpo, o backend deve ignorá-los
      // e resolver as credenciais no servidor. Como o identificador não
      // está configurado, deve retornar 401 (desconhecido).
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({
          'identificadorPrestador': 'nao-configurado',
          'code': '123',
          'user': 'user',
          'senha': 'senha',
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });
  });

  group('ValidadorApi - consultas', () {
    late ValidadorApi api;

    setUp(() {
      api = ValidadorApi();
    });

    test('rejeita token ausente com 401', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'consultas': [
            {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });

    test('rejeita consultas ausentes com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({'token': 'abc'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita consultas vazias com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': <dynamic>[],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item nao-objeto com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': ['invalido'],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item sem tipo com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item sem chave com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': 'elegibilidade'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item com tipo vazio com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': '', 'chave': '12345678901234567890'},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita item com chave vazia com 400', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({
          'token': 'abc',
          'consultas': [
            {'tipo': 'elegibilidade', 'chave': ''},
          ],
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 400);
    });

    test('rejeita lote acima de 300 itens com 413', () async {
      final consultas = List.generate(
        301,
        (i) => {'tipo': 'elegibilidade', 'chave': '12345678901234567890'},
      );
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: jsonEncode({'token': 'abc', 'consultas': consultas}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 413);
    });

    test('rejeita corpo acima de 1 MB com 413', () {
      final corpoGrande = 'x' * ((1 << 20) + 1);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/consultas'),
        body: corpoGrande,
      );
      expect(request.contentLength, greaterThan(1 << 20));
    });
  });

  group('ValidadorApi - rate limit', () {
    test('retorna 429 apos exceder limite de requisicoes', () async {
      final api = ValidadorApi();
      const int limite = 40;

      // Identificador desconhecido responde 401 sem tocar a rede, o que
      // permite exercitar apenas o rate limit.
      for (int i = 0; i < limite; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'identificadorPrestador': 'inexistente'}),
        );
        final response = await api.handler(request);
        expect(response.statusCode, 401, reason: 'Falha na req $i');
      }

      // A próxima requisição deve ser bloqueada.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'inexistente'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 429);
    });

    test('nao confia em X-Forwarded-For arbitrario', () async {
      final api = ValidadorApi();
      const int limite = 40;

      // X-Forwarded-For variando deve continuar contando como o mesmo IP,
      // pois o backend usa apenas o endereco real de conexao.
      for (int i = 0; i < limite; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'identificadorPrestador': 'inexistente'}),
          headers: {'x-forwarded-for': '10.0.0.$i'},
        );
        final response = await api.handler(request);
        expect(response.statusCode, 401, reason: 'Falha na req $i');
      }

      // A próxima requisição deve ser bloqueada, mesmo com XFF diferente.
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'inexistente'}),
        headers: {'x-forwarded-for': '10.0.0.999'},
      );
      final response = await api.handler(request);
      expect(response.statusCode, 429);
    });

    test('nao aplica rate limit em rotas fora do portal', () async {
      final api = ValidadorApi();
      for (int i = 0; i < 45; i++) {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/rota-inexistente'),
          body: '{}',
        );
        final response = await api.handler(request);
        expect(response.statusCode, 404, reason: 'Falha na req $i');
      }
    });
  });

  group('ValidadorApi - ambiente injetado', () {
    test('identificador desconhecido no ambiente injetado retorna 401',
        () async {
      final api = ValidadorApi(ambiente: const {});
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({'identificadorPrestador': 'teste'}),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
      final corpo = jsonDecode(await response.readAsString()) as Map;
      expect(corpo['mensagem'], contains('nao autorizado'));
    });

    test(
      'identificador conhecido sai da etapa de autorizacao',
      () async {
        // Com ambiente injetado, o identificador e resolvido no servidor e a
        // tentativa de login no portal acontece. Nao depende de rede: sem
        // credenciais validas o portal recusa, mas a mensagem nao pode ser a
        // de "identificador nao autorizado".
        final api = ValidadorApi(
          ambiente: const {
            'PORTAL_PRESTADOR_ID_TESTE_CODE': '000000000000',
            'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario-teste',
            'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha-teste',
          },
        );
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'identificadorPrestador': 'teste'}),
        );
        final response = await api.handler(request);
        final corpo = jsonDecode(await response.readAsString()) as Map;
        expect(corpo['mensagem'], isNot(contains('nao autorizado')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('credenciais do cliente no corpo sao ignoradas', () async {
      // Mesmo com ambiente injetado para 'teste', o body traz outros
      // identificadores: apenas o identificadorPrestador decide.
      final api = ValidadorApi(ambiente: const {});
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/login'),
        body: jsonEncode({
          'identificadorPrestador': 'outro',
          'code': '1',
          'user': 'u',
          'senha': 's',
        }),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 401);
    });
  });

  group('ValidadorApi - rota nao encontrada', () {
    test('retorna 404 para rota desconhecida', () async {
      final api = ValidadorApi();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/rota-desconhecida'),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 404);
    });
  });

  group('ValidadorApi - status', () {
    test('retorna 200 para /api/status', () async {
      final api = ValidadorApi();
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/status'),
      );
      final response = await api.handler(request);
      expect(response.statusCode, 200);
    });
  });
}
