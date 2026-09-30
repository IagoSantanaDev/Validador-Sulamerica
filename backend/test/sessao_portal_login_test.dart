import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

/// Adapter que responde por "METODO caminho", sem tocar a rede.
class _AdapterFake implements HttpClientAdapter {
  _AdapterFake(this.respostas);

  final Map<String, ResponseBody> respostas;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respostas['${options.method} ${options.uri.path}'] ??
        ResponseBody.fromString('sem resposta', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SessaoPortal - leitura do Location', () {
    test('Location repetido autentica em vez de virar falha de rede',
        () async {
      // `headers.value('location')` lanca `Exception` quando o header chega
      // duplicado. A excecao subia para o `catch` do login e a resposta ao
      // cliente saia como "falha de rede". O login deve seguir o primeiro
      // valor do header e autenticar.
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()
          ..httpClientAdapter = _AdapterFake(<String, ResponseBody>{
            'GET /main.jsp': ResponseBody.fromString('<html>formulario</html>', 200),
            'POST /main.jsp': ResponseBody.fromString(
              '',
              302,
              headers: <String, List<String>>{
                'location': <String>['/prestador/', '/redundante/'],
              },
            ),
            'GET /prestador/':
                ResponseBody.fromString('<html>logout</html>', 200),
          }),
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, isNull);
      expect(resultado.autenticada, isTrue);
      await sessao.encerrar();
    });

    test('Location ausente no 302 vira resposta inesperada', () async {
      final SessaoPortal sessao = SessaoPortal(
        dio: Dio()
          ..httpClientAdapter = _AdapterFake(<String, ResponseBody>{
            'GET /main.jsp':
                ResponseBody.fromString('<html>formulario</html>', 200),
            'POST /main.jsp': ResponseBody.fromString('', 302),
          }),
      );

      final ResultadoLogin resultado = await sessao.login(
        code: 'codigo',
        user: 'usuario',
        senha: 'senha',
      );

      expect(resultado.motivo, MotivoFalhaLogin.respostaInesperada);
      expect(resultado.motivo, isNot(MotivoFalhaLogin.falhaRede));
      await sessao.encerrar();
    });
  });
}