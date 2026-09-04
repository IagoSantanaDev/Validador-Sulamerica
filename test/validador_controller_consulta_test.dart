import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/controllers/validador_controller.dart';

/// Adapter de rede falso que responde /api/consultas a partir do CORPO do
/// request (lote) e registra as chamadas feitas — sem rede real.
class _FakeBatchAdapter implements HttpClientAdapter {
  _FakeBatchAdapter({
    this.statusAutorizacao = 'Autorizado',
    this.elegivel = true,
    this.loginOk = true,
  });

  final String? statusAutorizacao;
  final bool? elegivel;
  final bool loginOk;
  final List<String> logChamadas = [];
  final List<dynamic> consultasRecebidas = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    logChamadas.add(options.path);
    switch (options.path) {
      case '/api/login':
        return loginOk
            ? _resposta(200, {'token': 'tok123'})
            : _resposta(401, {'status': 'erro'});
      case '/api/consultas':
        final Object? data = options.data;
        final Map<String, dynamic> corpo = data is String
            ? jsonDecode(data) as Map<String, dynamic>
            : (data as Map).cast<String, dynamic>();
        final List<dynamic> consultas = corpo['consultas'] as List;
        consultasRecebidas.addAll(consultas);
        final List<Map<String, dynamic>> resultados = [
          for (final dynamic c in consultas)
            if ((c as Map)['tipo'] == 'elegibilidade')
              {
                'chave': c['chave'],
                'tipo': c['tipo'],
                'sucesso': true,
                'elegivel': elegivel,
                'rotuloElegibilidade': elegivel == true ? 'SIM' : null,
              }
            else
              {
                'chave': c['chave'],
                'tipo': c['tipo'],
                'sucesso': true,
                'statusVpp': statusAutorizacao,
              },
        ];
        return _resposta(200, {'status': 'ok', 'resultados': resultados});
      default:
        // Rota inexistente: dispara o fallback individual nos testes.
        return _resposta(404, {'status': 'erro', 'mensagem': 'nao encontrado'});
    }
  }

  ResponseBody _resposta(int status, Map<String, dynamic> corpo) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(corpo)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeValidadorGuiasRepository implements ValidadorGuiasRepository {
  _FakeValidadorGuiasRepository(this.retorno);

  final List<GuiaValidada> retorno;

  @override
  List<GuiaValidada> validarLote(String conteudoXml) => retorno;
}

/// Adapter para o fluxo individual (backend antigo): atende /api/login,
/// /api/beneficiario e /api/autorizacao; 404 para o restante.
class _FakeIndividualAdapter implements HttpClientAdapter {
  _FakeIndividualAdapter();

  final List<String> logChamadas = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    logChamadas.add(options.path);
    switch (options.path) {
      case '/api/login':
        return _resposta(200, {'token': 'tok123'});
      case '/api/beneficiario':
        return _resposta(200, {
          'status': 'ok',
          'elegivel': true,
          'rotuloElegibilidade': 'SIM',
        });
      case '/api/autorizacao':
        return _resposta(200, {
          'status': 'ok',
          'encontrada': true,
          'descricao': 'Autorizado',
        });
      default:
        return _resposta(404, {'status': 'erro'});
    }
  }

  ResponseBody _resposta(int status, Map<String, dynamic> corpo) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(corpo)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const GuiaTiss _guiaSemSenha = GuiaTiss(
  numeroGuiaPrestador: '111',
  numeroCarteira: '42509512809910100031',
  senha: null,
);

const GuiaTiss _guiaSenhaVppValida = GuiaTiss(
  numeroGuiaPrestador: '222',
  numeroCarteira: '55788888482319470020',
  senha: '5056430843',
);

const GuiaTiss _guiaSenhaInvalida = GuiaTiss(
  numeroGuiaPrestador: '333',
  numeroCarteira: '55788888482319470020',
  senha: '123',
);

ValidadorController _controllerComGateway({
  required HttpClientAdapter adapter,
  required List<GuiaValidada> retornoValidacao,
  String? code = 'prestador-code',
  String? user = 'master',
  String? senha = 'x',
}) {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  final SulAmericaBackendService service = SulAmericaBackendService(
    DioClient(baseUrl: 'http://localhost:8080', dio: dio),
  );
  return ValidadorController(
    repository: _FakeValidadorGuiasRepository(retornoValidacao),
    service: service,
    codigoPrestador: code,
    usuarioPrestador: user,
    senhaPrestador: senha,
  );
}

Future<ValidadorController> _validar(ValidadorController controller) async {
  controller.definirArquivo(
    nomeArquivo: 'lote.xml',
    bytes: Uint8List.fromList('<lote/>'.codeUnits),
  );
  await controller.validar();
  return controller;
}

void main() {
  group('ValidadorController - consultas ao portal em lote', () {
    test('guia sem senha aciona elegibilidade via uma única chamada de lote',
        () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSemSenha,
              erros: [
                ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
              ],
            ),
            GuiaValidada(
              guia: _guiaSenhaVppValida,
              erros: [],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      // Login + uma única chamada de lote; sem chamadas individuais. A guia
      // sem senha recebe 1 item (elegibilidade); a com senha, 2 (carteira +
      // VPP).
      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      expect(adapter.consultasRecebidas, hasLength(3));

      expect(controller.guiasComErro.first.consultas, hasLength(1));
      expect(
        controller.guiasComErro.first.consulta?.descricao,
        'Elegível: SIM',
      );
      final List<String> consultasGuiaSenha =
          controller.guias[1].consultas.map((c) => c.descricao).toList();
      expect(consultasGuiaSenha, contains('Elegível: SIM'));
      expect(consultasGuiaSenha, contains('Autorização VPP: ok'));
    });

    test('batch agrupa chaves repetidas em uma única consulta', () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      const GuiaTiss segundaComMesmaCarteira = GuiaTiss(
        numeroGuiaPrestador: '112',
        numeroCarteira: '42509512809910100031',
        senha: null,
      );

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSemSenha,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
            GuiaValidada(
              guia: segundaComMesmaCarteira,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      expect(adapter.consultasRecebidas, hasLength(1));
      for (final GuiaValidada guia in controller.guias) {
        expect(guia.consulta?.descricao, 'Elegível: SIM');
      }
    });

    test('autorização parcial ("Autorizado parcialmente") conta como ok',
        () async {
      final _FakeBatchAdapter adapter =
          _FakeBatchAdapter(statusAutorizacao: 'Autorizado parcialmente');

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      final ConsultaGuia consulta = controller.guias.single.consultas
          .firstWhere((c) => c.tipo == TipoConsultaGuia.autorizacaoVpp);
      expect(consulta.sucesso, isTrue);
      expect(consulta.descricao, 'Autorização VPP: ok');
    });

    test('autorização VPP não autorizada (Negado) é marcada como falha',
        () async {
      final _FakeBatchAdapter adapter =
          _FakeBatchAdapter(statusAutorizacao: 'Negado');

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('Autorização VPP: Negado'));
    });

    test('guia com senha inválida não gera consultas (nem login)', () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSenhaInvalida,
              erros: [
                ErroValidacao(campo: 'senha', mensagem: 'senha inválida'),
              ],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      // Senha inválida vira erro local; a carteira válida ainda consulta a
      // elegibilidade no lote (único item enviado, sem VPP).
      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      expect(adapter.consultasRecebidas, hasLength(1));
      final List<String> descricoes =
          controller.guiasComErro.single.consultas.map((c) => c.descricao).toList();
      expect(descricoes.any((d) => d.startsWith('Senha inválida')), isTrue);
      expect(descricoes, contains('Elegível: SIM'));
    });

    test('fallback: sem /api/consultas usa o fluxo individual', () async {
      final _FakeIndividualAdapter adapter = _FakeIndividualAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSemSenha,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, contains('/api/login'));
      expect(adapter.logChamadas, contains('/api/consultas'));
      expect(adapter.logChamadas, contains('/api/beneficiario'));
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
    });

    test('elegibilidade NÃO é um erro próprio no frontend', () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter(elegivel: false);

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSemSenha,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
          ],
        ),
      );

      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('Beneficiário não elegível'));
    });

    test('VPP sem status é exibido como senha inválida', () async {
      final _FakeBatchAdapter adapter =
          _FakeBatchAdapter(statusAutorizacao: null);

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
          ],
        ),
      );

      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('Senha inválida'));
    });

    test('carteira sem 20 dígitos vira erro próprio sem chamar a API',
        () async {
      const GuiaTiss guiaCarteiraCurta = GuiaTiss(
        numeroGuiaPrestador: '114',
        numeroCarteira: '123',
        senha: null,
      );
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: guiaCarteiraCurta,
              erros: [],
            ),
          ],
        ),
      );

      expect(adapter.logChamadas, isEmpty);
      expect(controller.guias.single.consulta?.sucesso, isFalse);
      expect(
        controller.guias.single.consulta?.descricao,
        contains('Número da carteira inválido'),
      );
    });

    test('falha no login é exibida como erro em todas as guias', () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter(loginOk: false);

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(
              guia: _guiaSemSenha,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('autenticar'));
    });

    test('sem credenciais do prestador nenhuma chamada é feita', () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSemSenha, erros: []),
          ],
          code: null,
          user: null,
          senha: null,
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, isEmpty);
      expect(controller.totalGuias, 1);
    });
  });
}
