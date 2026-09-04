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

/// Adapter de rede falso com respostas por rota — registra as chamadas feitas.
class _FakeGatewayAdapter implements HttpClientAdapter {
  _FakeGatewayAdapter(this.respostas);

  final Map<String, (int, Map<String, dynamic>)> respostas;
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
    final (int, Map<String, dynamic>)? resposta = respostas[options.path];
    final (int status, Map<String, dynamic> corpo) =
        resposta ?? (404, {'status': 'erro'});
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
  required _FakeGatewayAdapter adapter,
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
  group('ValidadorController - consultas ao portal por guia', () {
    test('guia sem senha aciona consulta de beneficiário (elegibilidade)',
        () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/beneficiario': (
          200,
          {
            'status': 'ok',
            'elegivel': true,
            'rotuloElegibilidade': 'SIM',
            'html': '<html/>',
          },
        ),
      });

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
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, contains('/api/login'));
      expect(adapter.logChamadas, contains('/api/beneficiario'));
      expect(adapter.logChamadas, isNot(contains('/api/autorizacao')));

      final ConsultaGuia? consulta =
          controller.guiasComErro.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.tipo, TipoConsultaGuia.elegibilidade);
      expect(consulta.sucesso, isTrue);
      expect(consulta.descricao, 'Elegível: SIM');
    });

    test('guia com senha 5 + 10 caracteres aciona autorização VPP', () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/autorizacao': (
          200,
          {
            'paginacao': {'total_registros': 1},
            'registros': [
              {
                'numero_solicitacao': '239675343',
                'status_solicitacao': {'descricao': 'Autorizado'},
              },
            ],
          },
        ),
      });

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, contains('/api/login'));
      expect(adapter.logChamadas, contains('/api/autorizacao'));
      expect(adapter.logChamadas, isNot(contains('/api/beneficiario')));

      final ConsultaGuia? consulta = controller.guias
          .firstWhere((g) => g.numeroGuiaPrestador == '222')
          .consulta;
      expect(consulta, isNotNull);
      expect(consulta!.tipo, TipoConsultaGuia.autorizacaoVpp);
      expect(consulta.sucesso, isTrue);
      expect(consulta.descricao, 'Autorização VPP: ok');
    });

    test('guia com senha inválida não é consultada', () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/autorizacao': (200, {'ok': true}),
      });

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

      expect(adapter.logChamadas, contains('/api/login'));
      expect(adapter.logChamadas, isNot(contains('/api/autorizacao')));
      expect(adapter.logChamadas, isNot(contains('/api/beneficiario')));
      expect(controller.guiasComErro.single.consulta, isNull);
    });

    test('dedupe: guias com a mesma carteira geram uma única consulta',
        () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/beneficiario': (
          200,
          {'status': 'ok', 'elegivel': true, 'rotuloElegibilidade': 'SIM', 'html': '<html/>'},
        ),
      });

      const GuiaTiss guiaSemSenhaB = GuiaTiss(
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
              guia: guiaSemSenhaB,
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(
        adapter.logChamadas.where((p) => p == '/api/beneficiario'),
        hasLength(1),
      );
      expect(controller.guias, hasLength(2));
      for (final GuiaValidada guia in controller.guias) {
        expect(guia.consulta?.descricao, 'Elegível: SIM');
      }
    });

    test('dedupe: guias com a mesma senha geram uma única autorização',
        () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/autorizacao': (
          200,
          {
            'paginacao': {'total_registros': 1},
            'registros': [
              {
                'numero_solicitacao': '239675343',
                'status_solicitacao': {'descricao': 'Autorizado'},
              },
            ],
          },
        ),
      });

      const GuiaTiss guiaVppB = GuiaTiss(
        numeroGuiaPrestador: '223',
        numeroCarteira: '55788888482319470020',
        senha: '5056430843',
      );

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
            GuiaValidada(guia: guiaVppB, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(
        adapter.logChamadas.where((p) => p == '/api/autorizacao'),
        hasLength(1),
      );
      for (final GuiaValidada guia in controller.guias) {
        expect(guia.consulta?.descricao, 'Autorização VPP: ok');
      }
    });

    test('autorização VPP não autorizada (Negado) é marcada como falha',
        () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
        '/api/autorizacao': (
          200,
          {
            'paginacao': {'total_registros': 1},
            'registros': [
              {
                'numero_solicitacao': '239675343',
                'status_solicitacao': {'descricao': 'Negado'},
              },
            ],
          },
        ),
      });

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaVppValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, 'Autorização VPP: Negado');
    });

    test('sem credenciais do prestador nenhuma chamada é feita', () async {
      final _FakeGatewayAdapter adapter = _FakeGatewayAdapter({
        '/api/login': (200, {'token': 'tok123'}),
      });

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