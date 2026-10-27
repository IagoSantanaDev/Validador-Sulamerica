import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_credenciais_portal.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/validador_guias_repository.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/sul_america_backend_service.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/controllers/validador_controller.dart';

class _RegraCredenciaisFixa extends RegraCredenciaisPortal {
  const _RegraCredenciaisFixa(this._identificadorPrestador);

  final String? _identificadorPrestador;

  @override
  String? resolver(String? identificadorPrestador) => _identificadorPrestador;
}

class _FakeBatchAdapter implements HttpClientAdapter {
  _FakeBatchAdapter({
    this.statusAutorizacao = 'Autorizado',
    this.elegivel = true,
    this.loginOk = true,
    this.rejeicoesBatch = 0,
    this.resultadosParciais = false,
    this.reverterResultados = false,
    this.elegibilidadeAlternada = false,
  });

  final String? statusAutorizacao;
  final bool? elegivel;
  final bool loginOk;
  int rejeicoesBatch;
  final bool resultadosParciais;
  final bool reverterResultados;
  final bool elegibilidadeAlternada;
  final List<String> logChamadas = [];
  final List<dynamic> consultasRecebidas = [];
  final List<int> tamanhosLotes = [];
  final List<Object?> corposLogin = [];

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
        corposLogin.add(options.data);
        return loginOk
            ? _resposta(200, {'token': 'tok123'})
            : _resposta(401, {'status': 'erro'});
      case '/api/consultas':
        final Object? data = options.data;
        final Map<String, dynamic> corpo = data is String
            ? jsonDecode(data) as Map<String, dynamic>
            : (data as Map).cast<String, dynamic>();
        final List<dynamic> consultas = corpo['consultas'] as List;
        tamanhosLotes.add(consultas.length);
        consultasRecebidas.addAll(consultas);
        if (rejeicoesBatch > 0) {
          rejeicoesBatch--;
          return _resposta(401, {'status': 'erro'});
        }
        final List<Map<String, dynamic>> resultados = [
          for (final dynamic c in consultas)
            if (!resultadosParciais ||
                (c as Map)['chave'] != (consultas.last as Map)['chave'])
              if ((c as Map)['tipo'] == 'elegibilidade')
                {
                  'chave': c['chave'],
                  'tipo': c['tipo'],
                  'sucesso': true,
                  'elegivel': elegibilidadeAlternada
                      ? (c['chave'] as String).endsWith('1')
                      : elegivel,
                  'rotuloElegibilidade': elegibilidadeAlternada
                      ? ((c['chave'] as String).endsWith('1') ? 'SIM' : 'NAO')
                      : elegivel == true
                          ? 'SIM'
                          : null,
                }
              else
                {
                  'chave': c['chave'],
                  'tipo': c['tipo'],
                  'sucesso': true,
                  'statusSenha': statusAutorizacao,
                },
        ];
        return _resposta(200, {
          'status': 'ok',
          'resultados':
              reverterResultados ? resultados.reversed.toList() : resultados,
        });
      default:
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
  Future<void> preparar() async {}

  @override
  List<GuiaValidada> validarLote(String conteudoXml) => retorno;

  @override
  List<GuiaValidada> validarGuias(List<GuiaTiss> guias) => retorno;
}

const GuiaTiss _guiaSemSenha = GuiaTiss(
  numeroGuiaPrestador: '111',
  numeroCarteira: '42509512809910100031',
  senha: null,
);

const GuiaTiss _guiaSenhaValida = GuiaTiss(
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
  String? identificadorPrestador = '27372066000673',
}) {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  final SulAmericaBackendService service = SulAmericaBackendService(
    DioClient(baseUrl: 'http://localhost:8080', dio: dio),
  );
  return ValidadorController(
    repository: _FakeValidadorGuiasRepository(retornoValidacao),
    service: service,
    regraCredenciais: _RegraCredenciaisFixa(identificadorPrestador),
  );
}

Future<ValidadorController> _validar(ValidadorController controller) async {
  controller.definirArquivo(
    nomeArquivo: 'lote.xml',
    bytes: Uint8List.fromList(
      '<mensagemTISS><guiaSP-SADT/></mensagemTISS>'.codeUnits,
    ),
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
              erros: [ErroValidacao(campo: 'senha', mensagem: 'sem senha')],
            ),
            GuiaValidada(
              guia: _guiaSenhaValida,
              erros: [],
            ),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);

      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      expect(adapter.corposLogin, [
        {'identificadorPrestador': '27372066000673'},
      ]);
      expect(adapter.consultasRecebidas, hasLength(3));

      expect(controller.guiasComErro.first.consultas, hasLength(1));
      expect(
        controller.guiasComErro.first.consulta?.descricao,
        'Elegível: SIM',
      );
      final List<String> consultasGuiaSenha =
          controller.guias[1].consultas.map((c) => c.descricao).toList();
      expect(consultasGuiaSenha, contains('Elegível: SIM'));
      expect(consultasGuiaSenha, contains('Senha: ok'));
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
            GuiaValidada(guia: _guiaSenhaValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      final ConsultaGuia consulta = controller.guias.single.consultas
          .firstWhere((c) => c.tipo == TipoConsultaGuia.senha);
      expect(consulta.sucesso, isTrue);
      expect(consulta.descricao, 'Senha: ok');
    });

    test('autorização VPP não autorizada (Negado) é marcada como falha',
        () async {
      final _FakeBatchAdapter adapter =
          _FakeBatchAdapter(statusAutorizacao: 'Negado');

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSenhaValida, erros: []),
          ],
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('Senha: Negado'));
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

      expect(adapter.logChamadas, ['/api/login', '/api/consultas']);
      expect(adapter.consultasRecebidas, hasLength(1));
      final List<String> descricoes = controller.guiasComErro.single.consultas
          .map((c) => c.descricao)
          .toList();
      expect(descricoes.any((d) => d.startsWith('Senha inválida')), isTrue);
      expect(descricoes, contains('Elegível: SIM'));
    });

    test('senha com dígito Unicode é rejeitada antes de consultar a API',
        () async {
      const GuiaTiss guiaSenhaUnicode = GuiaTiss(
        numeroGuiaPrestador: '334',
        numeroCarteira: '55788888482319470020',
        senha: '5\u06600000000',
      );
      final _FakeBatchAdapter adapter = _FakeBatchAdapter();

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: guiaSenhaUnicode, erros: []),
          ],
        ),
      );

      expect(
        controller.guias.single.consultas
            .firstWhere((consulta) => consulta.tipo == TipoConsultaGuia.senha)
            .sucesso,
        isFalse,
      );
      expect(
        adapter.consultasRecebidas
            .where((consulta) => (consulta as Map)['tipo'] == 'senha'),
        isEmpty,
      );
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
            GuiaValidada(guia: _guiaSenhaValida, erros: []),
          ],
        ),
      );

      final ConsultaGuia? consulta = controller.guias.single.consulta;
      expect(consulta, isNotNull);
      expect(consulta!.sucesso, isFalse);
      expect(consulta.descricao, contains('Senha não encontrada no portal'));
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
          identificadorPrestador: null,
        ),
      );

      expect(controller.status, StatusValidador.concluido);
      expect(adapter.logChamadas, isEmpty);
      expect(controller.totalGuias, 1);
    });

    test('particiona 301 chaves e preserva correlação para todas as guias',
        () async {
      final List<GuiaValidada> guias = [
        for (int indice = 0; indice < 301; indice++)
          GuiaValidada(
            guia: GuiaTiss(
              numeroGuiaPrestador: indice.toString().padLeft(3, '0'),
              numeroCarteira: indice.toString().padLeft(20, '0'),
              senha: null,
            ),
            erros: const [],
          ),
      ];
      final _FakeBatchAdapter adapter = _FakeBatchAdapter(
        reverterResultados: true,
        elegibilidadeAlternada: true,
      );

      final ValidadorController controller = await _validar(
        _controllerComGateway(adapter: adapter, retornoValidacao: guias),
      );

      expect(adapter.tamanhosLotes, [300, 1]);
      expect(adapter.consultasRecebidas, hasLength(301));
      expect(controller.guias, hasLength(301));
      expect(
        controller.guias.map((guia) => guia.consulta?.sucesso),
        [for (int indice = 0; indice < 301; indice++) indice % 10 == 1],
      );
      expect(
        controller.guias.map((guia) => guia.numeroGuiaPrestador).toList(),
        [
          for (int indice = 0; indice < 301; indice++)
            indice.toString().padLeft(3, '0'),
        ],
      );
    });

    test('resposta parcial marca resultados ausentes como falha por guia',
        () async {
      const GuiaTiss guiaAusente = GuiaTiss(
        numeroGuiaPrestador: '115',
        numeroCarteira: '42509512809910100032',
        senha: null,
      );
      final _FakeBatchAdapter adapter =
          _FakeBatchAdapter(resultadosParciais: true);

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSemSenha, erros: []),
            GuiaValidada(guia: guiaAusente, erros: []),
          ],
        ),
      );

      expect(controller.guias.first.temFalhaConsulta, isFalse);
      expect(controller.guias.last.temFalhaConsulta, isTrue);
      expect(
        controller.guias.last.consulta?.descricao,
        contains('não retornou resultado'),
      );
    });

    test('token rejeitado refaz login e repete o batch no máximo uma vez',
        () async {
      final _FakeBatchAdapter adapter = _FakeBatchAdapter(rejeicoesBatch: 3);

      final ValidadorController controller = await _validar(
        _controllerComGateway(
          adapter: adapter,
          retornoValidacao: const [
            GuiaValidada(guia: _guiaSemSenha, erros: []),
          ],
        ),
      );

      expect(
        adapter.logChamadas,
        ['/api/login', '/api/consultas', '/api/login', '/api/consultas'],
      );
      expect(controller.guias.single.consulta?.sucesso, isFalse);
      expect(controller.guias.single.consulta?.descricao, contains('401/403'));
    });
  });
}
