import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/constants/app_strings.dart';
import 'package:validador_xml_sulamerica/globals/network/app_exception.dart';
import 'package:validador_xml_sulamerica/globals/network/dio_client.dart';
import 'package:validador_xml_sulamerica/globals/network/result.dart';
import 'package:validador_xml_sulamerica/globals/network/sse_client.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_lote.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/lote_remoto.dart';
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

class _FakeAsyncBackend extends SulAmericaBackendService {
  _FakeAsyncBackend() : super(DioClient(baseUrl: 'http://localhost'));

  final List<Result<String>> respostasSessao = [];
  final List<Result<LoteRemoto>> respostasLote = [];
  final List<Result<Map<String, dynamic>>> respostasStatus = [];
  final List<Stream<EventoSse>> streams = [];
  final List<String> chavesIdempotencia = [];
  final List<String> tokensSubmissao = [];
  final List<String> tokensSse = [];
  final List<int?> idsSse = [];
  final List<List<ConsultaLoteItem>> lotes = [];
  final Map<String, List<ConsultaLoteItem>> _consultasPorLote = {};
  int chamadasSessao = 0;
  int chamadasStatus = 0;
  int _proximoLote = 0;

  @override
  Future<Result<Map<String, dynamic>>> status() async {
    chamadasStatus++;
    if (respostasStatus.isNotEmpty) return respostasStatus.removeAt(0);
    return Result.success({
      'bloqueio': {'ativo': false},
    });
  }

  @override
  Future<Result<String>> criarSessao({
    required String identificadorPrestador,
  }) async {
    chamadasSessao++;
    if (respostasSessao.isNotEmpty) return respostasSessao.removeAt(0);
    return Result.success('token-$chamadasSessao');
  }

  @override
  Future<Result<LoteRemoto>> criarLote({
    required String token,
    required String idempotencyKey,
    required List<ConsultaLoteItem> consultas,
  }) async {
    tokensSubmissao.add(token);
    chavesIdempotencia.add(idempotencyKey);
    lotes.add(List.of(consultas));
    if (respostasLote.isNotEmpty) {
      final Result<LoteRemoto> resposta = respostasLote.removeAt(0);
      if (resposta is Failure<LoteRemoto>) return resposta;
      final LoteRemoto lote = (resposta as Success<LoteRemoto>).valor;
      _consultasPorLote[lote.id] = List.of(consultas);
      return resposta;
    }

    final LoteRemoto lote = LoteRemoto(
      id: 'lote-${++_proximoLote}',
      estado: 'na_fila',
      total: consultas.length,
    );
    _consultasPorLote[lote.id] = List.of(consultas);
    return Result.success(lote);
  }

  @override
  ConexaoSse abrirEventos({
    required String token,
    required String idLote,
    int? desde,
  }) {
    tokensSse.add(token);
    idsSse.add(desde);
    if (streams.isNotEmpty) {
      return ConexaoSse(streams.removeAt(0), () {});
    }

    final List<Map<String, Object?>> resultados = [
      for (final ConsultaLoteItem consulta
          in _consultasPorLote[idLote] ?? const <ConsultaLoteItem>[])
        {
          'chave': consulta.chave,
          'tipo': consulta.tipo.name,
          'sucesso': true,
          if (consulta.tipo == TipoConsultaGuia.elegibilidade) ...{
            'elegivel': true,
            'rotuloElegibilidade': 'SIM',
          } else
            'statusSenha': 'Autorizado',
        },
    ];
    return ConexaoSse(
      Stream<EventoSse>.fromIterable([
        EventoSse(
          id: '1',
          evento: 'progresso',
          dados: jsonEncode({
            'concluidas': resultados.length,
            'total': resultados.length,
          }),
        ),
        EventoSse(
          id: '2',
          evento: 'resultado',
          dados: jsonEncode({'status': 'concluido', 'resultados': resultados}),
        ),
      ]),
      () {},
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

const String _carteira = '42509512809910100031';
const GuiaTiss _guiaSemSenha = GuiaTiss(
  numeroGuiaPrestador: '111',
  numeroCarteira: _carteira,
  senha: null,
);
ValidadorController _novoController({
  required _FakeAsyncBackend service,
  required List<GuiaValidada> retorno,
  String? identificadorPrestador = '27372066000673',
  List<Duration>? esperas,
}) {
  return ValidadorController(
    repository: _FakeValidadorGuiasRepository(retorno),
    service: service,
    regraCredenciais: _RegraCredenciaisFixa(identificadorPrestador),
    aguardarRetentativa: (Duration duracao) async {
      esperas?.add(duracao);
    },
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

Map<String, Object?> _resultado({
  required String chave,
  String tipo = 'elegibilidade',
  bool sucesso = true,
  bool? elegivel = true,
  String? erro,
}) => {
  'chave': chave,
  'tipo': tipo,
  'sucesso': sucesso,
  if (tipo == 'elegibilidade') 'elegivel': elegivel,
  if (tipo == 'senha') 'statusSenha': 'Autorizado',
  if (erro != null) 'erro': erro,
};

Stream<EventoSse> _resultadoStream(
  List<Map<String, Object?>> resultados, {
  String id = '1',
  String status = 'concluido',
  List<Map<String, String>> pendentes = const [],
}) => Stream<EventoSse>.value(
  EventoSse(
    id: id,
    evento: 'resultado',
    dados: jsonEncode({
      'status': status,
      'resultados': resultados,
      if (pendentes.isNotEmpty) 'pendentes': pendentes,
    }),
  ),
);

Stream<EventoSse> _erroDepoisDoEvento(EventoSse evento, Object erro) async* {
  yield evento;
  throw erro;
}

void main() {
  group('ValidadorController - fluxo assíncrono de consultas', () {
    test('bloqueio do status impede começar validação', () async {
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasStatus.add(
          Result.success({
            'bloqueio': {
              'ativo': true,
              'motivo': 'limite_portal',
              'codigo': '429',
              'mensagem': 'Limite de consultas do portal atingido (429)',
              'retryAfterSegundos': 120,
            },
          }),
        );
      final ValidadorController controller = _novoController(
        service: service,
        retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
      );
      addTearDown(controller.dispose);

      await _validar(controller);

      expect(controller.status, StatusValidador.semArquivo);
      expect(controller.nomeArquivo, isNull);
      expect(controller.bloqueioPortal?.motivo, 'limite_portal');
      expect(service.chamadasSessao, 0);
      expect(service.tokensSubmissao, isEmpty);
    });

    test(
      'erro SSE de bloqueio descarta lote e retorna à tela inicial',
      () async {
        const Map<String, Object?> bloqueio = {
          'ativo': true,
          'motivo': 'rejeicao_f5',
          'codigo': 'F5',
          'mensagem': 'Portal bloqueou a consulta (F5)',
          'retryAfterSegundos': 120,
        };
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..streams.add(
            Stream<EventoSse>.value(
              EventoSse(
                id: '1',
                evento: 'erro',
                dados: jsonEncode({
                  'mensagem': bloqueio['mensagem'],
                  'bloqueio': bloqueio,
                }),
              ),
            ),
          );
        final ValidadorController controller = _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
        );
        addTearDown(controller.dispose);

        await _validar(controller);

        expect(controller.status, StatusValidador.semArquivo);
        expect(controller.nomeArquivo, isNull);
        expect(controller.guias, isEmpty);
        expect(controller.bloqueioPortal?.codigo, 'F5');
        expect(service.lotes, hasLength(1));
      },
    );

    test(
      'retry manual de pendência entra no bloqueio ao receber erro SSE',
      () async {
        const Map<String, Object?> bloqueio = {
          'ativo': true,
          'motivo': 'limite_portal',
          'codigo': '429',
          'mensagem': 'Limite de consultas do portal atingido (429)',
          'retryAfterSegundos': 120,
        };
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..streams.addAll([
            _resultadoStream(
              [
                _resultado(
                  chave: _carteira,
                  sucesso: false,
                  erro: 'Falha na consulta ao portal SulAmerica.',
                ),
              ],
              status: 'parcial',
              pendentes: [
                {
                  'tipo': 'elegibilidade',
                  'chave': _carteira,
                  'motivo': 'tentativas_esgotadas',
                },
              ],
            ),
            Stream<EventoSse>.value(
              EventoSse(
                id: '1',
                evento: 'erro',
                dados: jsonEncode({
                  'mensagem': bloqueio['mensagem'],
                  'bloqueio': bloqueio,
                }),
              ),
            ),
          ]);
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          ),
        );
        addTearDown(controller.dispose);

        expect(controller.temConsultasPendentes, isTrue);

        await controller.retentarConsultasPendentes();

        expect(controller.status, StatusValidador.semArquivo);
        expect(controller.nomeArquivo, isNull);
        expect(controller.guias, isEmpty);
        expect(controller.temConsultasPendentes, isFalse);
        expect(controller.bloqueioPortal?.codigo, '429');
        expect(service.lotes, hasLength(2));
      },
    );

    test('503 consulta status antes de tentar novamente', () async {
      const Map<String, dynamic> bloqueio = {
        'ativo': true,
        'motivo': 'limite_portal',
        'codigo': '429',
        'mensagem': 'Limite de consultas do portal atingido (429)',
        'retryAfterSegundos': 120,
      };
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasSessao.add(
          Result.failure(
            const ServicoIndisponivelException(retryAfter: Duration(seconds: 60)),
          ),
        )
        ..respostasStatus.addAll([
          Result.success({'bloqueio': {'ativo': false}}),
          Result.success({'bloqueio': bloqueio}),
        ]);
      final ValidadorController controller = _novoController(
        service: service,
        retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
      );
      addTearDown(controller.dispose);

      await _validar(controller);

      expect(service.chamadasSessao, 1);
      expect(service.chamadasStatus, 2);
      expect(controller.status, StatusValidador.semArquivo);
      expect(controller.bloqueioPortal?.codigo, '429');
    });

    test('erro SSE verifica status antes de reconectar ou retentar', () async {
      const Map<String, Object?> bloqueio = {
        'ativo': true,
        'motivo': 'rejeicao_f5',
        'codigo': 'F5',
        'mensagem': 'Portal bloqueou a consulta (F5)',
        'retryAfterSegundos': 120,
      };
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..streams.add(
          Stream<EventoSse>.value(
            EventoSse(
              id: '1',
              evento: 'erro',
              dados: jsonEncode({'mensagem': 'Consulta interrompida'}),
            ),
          ),
        )
        ..respostasStatus.addAll([
          Result.success({'bloqueio': {'ativo': false}}),
          Result.success({'bloqueio': bloqueio}),
        ]);
      final ValidadorController controller = _novoController(
        service: service,
        retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
      );
      addTearDown(controller.dispose);

      await _validar(controller);

      expect(service.chamadasStatus, 2);
      expect(service.idsSse, [null]);
      expect(controller.status, StatusValidador.semArquivo);
      expect(controller.guias, isEmpty);
      expect(controller.bloqueioPortal?.codigo, 'F5');
    });

    test('503 com bloqueio não repete criação de sessão', () async {
      const Map<String, dynamic> bloqueio = {
        'ativo': true,
        'motivo': 'portal_indisponivel',
        'codigo': '5xx',
        'mensagem': 'Portal temporariamente indisponível',
        'retryAfterSegundos': 60,
      };
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasSessao.add(
          Result.failure(
            const ServicoIndisponivelException(
              retryAfter: Duration(seconds: 60),
              bloqueio: bloqueio,
            ),
          ),
        );
      final ValidadorController controller = _novoController(
        service: service,
        retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
      );
      addTearDown(controller.dispose);

      await _validar(controller);

      expect(service.chamadasSessao, 1);
      expect(service.tokensSubmissao, isEmpty);
      expect(controller.status, StatusValidador.semArquivo);
      expect(controller.bloqueioPortal?.codigo, '5xx');
    });

    test(
      'submete lotes e aplica progresso e resultado recebidos por SSE',
      () async {
        final _FakeAsyncBackend service = _FakeAsyncBackend();
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          ),
        );

        expect(service.chamadasSessao, 1);
        expect(service.lotes, hasLength(1));
        expect(service.lotes.single.single.chave, _carteira);
        expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
        expect(controller.progressoConsultasConcluidas, 1);
        expect(controller.totalConsultas, 1);
        expect(controller.fracaoProgressoConsultas, 1);
        expect(controller.etapaConsultaBackend, EtapaConsultaBackend.concluida);
      },
    );

    test('mantém chunks sequenciais limitados a 300 consultas', () async {
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
      final _FakeAsyncBackend service = _FakeAsyncBackend();
      final ValidadorController controller = await _validar(
        _novoController(service: service, retorno: guias),
      );

      expect(service.lotes.map((lote) => lote.length), [300, 1]);
      expect(controller.guias, hasLength(301));
      expect(controller.progressoConsultasConcluidas, 301);
      expect(controller.fracaoProgressoConsultas, 1);
      expect(service.idsSse, [null, null]);
    });

    test('doze lotes fake completam o progresso do arquivo sem rede', () async {
      final List<GuiaValidada> guias = [
        for (int indice = 0; indice < 3301; indice++)
          GuiaValidada(
            guia: GuiaTiss(
              numeroGuiaPrestador: indice.toString().padLeft(4, '0'),
              numeroCarteira: indice.toString().padLeft(20, '0'),
              senha: null,
            ),
            erros: const [],
          ),
      ];
      final _FakeAsyncBackend service = _FakeAsyncBackend();
      final ValidadorController controller = await _validar(
        _novoController(service: service, retorno: guias),
      );

      expect(service.lotes, hasLength(12));
      expect(controller.progressoConsultasConcluidas, 3301);
      expect(controller.totalConsultas, 3301);
      expect(controller.guias, hasLength(3301));
    });

    test('429 de sessão só repete uma vez quando Retry-After existe', () async {
      final List<Duration> esperas = [];
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasSessao.addAll([
          Result.failure(
            const FilaCheiaException(retryAfter: Duration(seconds: 5)),
          ),
          Result.success('token-renovado'),
        ]);
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.chamadasSessao, 2);
      expect(esperas, [const Duration(seconds: 5)]);
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
    });

    test(
      '429 de sessão sem Retry-After não repete e deixa consulta pendente',
      () async {
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..respostasSessao.add(Result.failure(const FilaCheiaException()));
        final List<Duration> esperas = [];
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
            esperas: esperas,
          ),
        );

        expect(service.chamadasSessao, 1);
        expect(service.lotes, isEmpty);
        expect(esperas, isEmpty);
        expect(controller.temConsultasPendentes, isTrue);
        expect(controller.mensagemAvisoConsultaBackend, contains('fila'));
      },
    );

    test(
      '429 do lote usa a mesma chave e Retry-After limitado a 60 segundos',
      () async {
        final List<Duration> esperas = [];
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..respostasLote.addAll([
            Result.failure(
              const FilaCheiaException(retryAfter: Duration(seconds: 90)),
            ),
            Result.failure(const FilaCheiaException()),
            Result.failure(
              const FilaCheiaException(retryAfter: Duration(seconds: 10)),
            ),
          ]);
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
            esperas: esperas,
          ),
        );

        expect(service.lotes, hasLength(4));
        expect(service.chavesIdempotencia.toSet(), hasLength(1));
        expect(esperas, [
          const Duration(seconds: 60),
          const Duration(seconds: 2),
          const Duration(seconds: 10),
        ]);
        expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
      },
    );

    test(
      '401 na submissão reautentica uma vez e preserva idempotency key',
      () async {
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..respostasLote.add(Result.failure(const NaoAutorizadoException()));
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          ),
        );

        expect(service.chamadasSessao, 2);
        expect(service.tokensSubmissao, ['token-1', 'token-2']);
        expect(service.chavesIdempotencia.toSet(), hasLength(1));
        expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
      },
    );

    test('SSE reautentica em 401 e reconecta usando o último id', () async {
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..streams.add(
          _erroDepoisDoEvento(
            const EventoSse(
              id: '17',
              evento: 'progresso',
              dados: '{"concluidas":1,"total":1}',
            ),
            const NaoAutorizadoException(),
          ),
        );
      final List<Duration> esperas = [];
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.chamadasSessao, 2);
      expect(service.tokensSse, ['token-1', 'token-2']);
      expect(service.idsSse, [null, 17]);
      expect(esperas, isEmpty);
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
    });

    test(
      'SSE reconecta em 2/4/8 segundos e depois mantém itens pendentes',
      () async {
        final _FakeAsyncBackend service = _FakeAsyncBackend()
          ..streams.addAll([
            _erroDepoisDoEvento(
              const EventoSse(
                id: '23',
                evento: 'progresso',
                dados: '{"concluidas":1,"total":1}',
              ),
              const SemConexaoException(),
            ),
            Stream<EventoSse>.error(const SemConexaoException()),
            Stream<EventoSse>.error(const RequisicaoExpiradaException()),
            Stream<EventoSse>.error(const SemConexaoException()),
          ]);
        final List<Duration> esperas = [];
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
            esperas: esperas,
          ),
        );

        expect(esperas, [
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 8),
        ]);
        expect(service.idsSse, [null, 23, 23, 23]);
        expect(controller.temConsultasPendentes, isTrue);
        expect(controller.totalConsultasPendentes, 1);
        expect(controller.etapaConsultaBackend, EtapaConsultaBackend.pendente);
      },
    );

    test('SSE não exibe TypeError: Failed to fetch ao usuário', () async {
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..streams.add(
          Stream<EventoSse>.error(
            const ErroDesconhecidoException('TypeError: Failed to fetch'),
          ),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
        ),
      );

      expect(
        controller.mensagemAvisoConsultaBackend,
        AppStrings.erroConsultaBackendGenerico,
      );
      expect(
        controller.mensagemAvisoConsultaBackend,
        isNot(contains('Failed to fetch')),
      );
    });

    test('SSE não exibe resposta técnica de token inválido', () async {
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasSessao.addAll([
          Result.success('token-1'),
          Result.failure(const NaoAutorizadoException()),
        ])
        ..streams.add(Stream<EventoSse>.error(const NaoAutorizadoException()));
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
        ),
      );

      expect(
        controller.mensagemAvisoConsultaBackend,
        AppStrings.erroLoginFalhou,
      );
      expect(controller.mensagemAvisoConsultaBackend, isNot(contains('401')));
      expect(
        controller.mensagemAvisoConsultaBackend,
        isNot(contains('Token de sessao invalido')),
      );
    });

    test('rejeição HTTP diferente de 429 e 503 não repete submissão', () async {
      final List<Duration> esperas = [];
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasLote.add(
          Result.failure(const ErroServidorException(statusCode: 500)),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.lotes, hasLength(1));
      expect(esperas, isEmpty);
      expect(controller.temConsultasPendentes, isTrue);
    });

    test('503 em sessão respeita Retry-After limitado a 60 segundos', () async {
      final List<Duration> esperas = [];
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasSessao.addAll([
          Result.failure(
            const ServicoIndisponivelException(
              retryAfter: Duration(seconds: 90),
            ),
          ),
          Result.success('token-recuperado'),
        ]);
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.chamadasSessao, 2);
      expect(esperas, [const Duration(seconds: 60)]);
      expect(service.lotes, hasLength(1));
      expect(controller.temConsultasPendentes, isFalse);
    });

    test('503 em lote repete com mesma chave e respeita Retry-After', () async {
      final List<Duration> esperas = [];
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasLote.add(
          Result.failure(
            const ServicoIndisponivelException(
              retryAfter: Duration(seconds: 45),
            ),
          ),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.lotes, hasLength(2));
      expect(service.chavesIdempotencia.first, service.chavesIdempotencia.last);
      expect(esperas, [const Duration(seconds: 45)]);
      expect(controller.temConsultasPendentes, isFalse);
    });

    test('resultado parcial aplica concluídas e deixa pendências para retry manual', () async {
      const String senha = '5000000000';
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..streams.add(
          _resultadoStream(
            [_resultado(chave: _carteira)],
            status: 'parcial',
            pendentes: [
              {'tipo': 'senha', 'chave': senha, 'motivo': 'prazo_5_minutos'},
            ],
          ),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [
            GuiaValidada(
              guia: GuiaTiss(
                numeroGuiaPrestador: '111',
                numeroCarteira: _carteira,
                senha: senha,
              ),
              erros: [],
            ),
          ],
        ),
      );

      expect(controller.temConsultasPendentes, isTrue);
      expect(controller.totalConsultasPendentes, 1);
      expect(controller.guias.single.consultas, hasLength(1));
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
      expect(
        controller.mensagemAvisoConsultaBackend,
        AppStrings.consultasPrazoExpirado,
      );
      expect(service.lotes, hasLength(1));
    });

    test('falha de transporte permite retry automático, rejeição de portal fica manual', () async {
      final List<Duration> esperas = [];
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..respostasLote.add(Result.failure(const SemConexaoException()))
        ..streams.add(
          _resultadoStream([
            _resultado(
              chave: _carteira,
              sucesso: false,
              erro: 'Falha na consulta ao portal SulAmerica.',
            ),
          ]),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
          esperas: esperas,
        ),
      );

      expect(service.lotes, hasLength(2));
      expect(esperas, [const Duration(seconds: 2)]);
      expect(controller.temConsultasPendentes, isTrue);
      expect(controller.guias.single.consultas, isEmpty);

      await controller.retentarConsultasPendentes();

      expect(service.lotes, hasLength(3));
      expect(controller.temConsultasPendentes, isFalse);
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
    });

    test(
      'mantém limites locais de carteira e senha antes de chamar backend',
      () async {
        const GuiaTiss guiaInvalida = GuiaTiss(
          numeroGuiaPrestador: '333',
          numeroCarteira: '123',
          senha: '123',
        );
        final _FakeAsyncBackend service = _FakeAsyncBackend();
        final ValidadorController controller = await _validar(
          _novoController(
            service: service,
            retorno: const [
              GuiaValidada(
                guia: guiaInvalida,
                erros: [
                  ErroValidacao(campo: 'senha', mensagem: 'senha inválida'),
                ],
              ),
            ],
          ),
        );

        expect(service.chamadasSessao, 0);
        expect(service.lotes, isEmpty);
        expect(controller.guias.single.consultas, hasLength(2));
        expect(
          controller.guias.single.consultas.map((consulta) => consulta.tipo),
          containsAll([TipoConsultaGuia.elegibilidade, TipoConsultaGuia.senha]),
        );
      },
    );

    test('falha transitória declarada como pendente permanece disponível para retry', () async {
      const String senha = '5000000000';
      final _FakeAsyncBackend service = _FakeAsyncBackend()
        ..streams.add(
          _resultadoStream(
            [
              _resultado(chave: _carteira),
              _resultado(
                chave: senha,
                tipo: 'senha',
                sucesso: false,
                erro: 'Falha na consulta ao portal SulAmerica (HTTP 503).',
              ),
            ],
            status: 'parcial',
            pendentes: [
              {
                'tipo': 'senha',
                'chave': senha,
                'motivo': 'tentativas_esgotadas',
              },
            ],
          ),
        );
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          retorno: const [
            GuiaValidada(
              guia: GuiaTiss(
                numeroGuiaPrestador: '111',
                numeroCarteira: _carteira,
                senha: senha,
              ),
              erros: [],
            ),
          ],
        ),
      );

      expect(controller.temConsultasPendentes, isTrue);
      expect(controller.totalConsultasPendentes, 1);
      expect(controller.guias.single.consultas, hasLength(1));
      expect(controller.guias.single.consulta?.descricao, 'Elegível: SIM');
      expect(controller.mensagemAvisoConsultaBackend, isNull);
      expect(service.lotes, hasLength(1));
    });

    test('não faz login quando não há identificador do prestador', () async {
      final _FakeAsyncBackend service = _FakeAsyncBackend();
      final ValidadorController controller = await _validar(
        _novoController(
          service: service,
          identificadorPrestador: null,
          retorno: const [GuiaValidada(guia: _guiaSemSenha, erros: [])],
        ),
      );

      expect(service.chamadasSessao, 0);
      expect(service.lotes, isEmpty);
      expect(controller.totalGuias, 1);
    });
  });
}
