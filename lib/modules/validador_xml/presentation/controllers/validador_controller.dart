import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/network/app_exception.dart';
import '../../../../globals/network/result.dart';
import '../../../../globals/network/sse_client.dart';
import '../../data/datasources/tuss_base_local_exceptions.dart';
import '../../data/datasources/xml_lote_guias_datasource.dart';
import '../../data/datasources/xml_lote_guias_exceptions.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/consulta_lote.dart';
import '../../data/models/bloqueio_portal.dart';
import '../../data/models/guia_validada.dart';
import '../../data/models/informacoes_lote.dart';
import '../../data/models/lote_guias_extraido.dart';
import '../../data/models/lote_remoto.dart';
import '../../data/repositories/regras/regra_credenciais_portal.dart';
import '../../data/repositories/regras/regra_senha_prefixo.dart';
import '../../data/repositories/validador_guias_repository.dart';
import '../../data/repositories/validador_guias_repository_impl.dart';
import '../../data/services/classificador_tuss_local.dart';
import '../../data/services/sul_america_backend_service.dart';

enum StatusValidador { semArquivo, arquivoPronto, validando, concluido, erro }

enum EstadoConexao { verificando, apiIndisponivel, pronto }

enum EtapaConsultaBackend {
  naoIniciada,
  consultando,
  aguardandoRetentativa,
  pendente,
  concluida,
}

Duration? _retryAfter(AppException erro) => switch (erro) {
  FilaCheiaException(:final retryAfter) => retryAfter,
  ServicoIndisponivelException(:final retryAfter) => retryAfter,
  _ => null,
};

class ValidadorController extends ChangeNotifier {
  static const int _maxConsultasPorLote = 300;
  static const List<Duration> _intervalosRetentativa = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  static const List<Duration> _intervalosFilaCheia = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static const Duration _limiteRetryAfterLote = Duration(seconds: 60);

  ValidadorController({
    ValidadorGuiasRepository? repository,
    SulAmericaBackendService? service,
    RegraCredenciaisPortal? regraCredenciais,
    Future<void> Function(Duration)? aguardarRetentativa,
  }) : _repository =
           repository ??
           ValidadorGuiasRepositoryImpl(
             classificadorTuss: ClassificadorTussLocal(),
           ),
       _service = service ?? _servicePadrao(),
       _regraCredenciais = regraCredenciais ?? const RegraCredenciaisPortal(),
       _aguardarRetentativa =
           aguardarRetentativa ??
           ((Duration duracao) => Future<void>.delayed(duracao));

  final ValidadorGuiasRepository _repository;
  final XmlLoteGuiasDatasource _datasource = const XmlLoteGuiasDatasource();
  final SulAmericaBackendService? _service;
  final RegraCredenciaisPortal _regraCredenciais;
  final Future<void> Function(Duration) _aguardarRetentativa;
  final Random _aleatorio = Random.secure();

  String? _tokenSessao;
  String? _identificadorPrestadorDoToken;
  EtapaConsultaBackend _etapaConsultaBackend = EtapaConsultaBackend.naoIniciada;
  final Map<String, ConsultaLoteItem> _consultasPendentes = {};
  final Map<String, ConsultaGuia> _resultadosConsultas = {};
  List<GuiaValidada> _guiasBaseConsultas = const [];
  bool _retentativaManualEmAndamento = false;
  bool _descartandoLoteBloqueado = false;
  String? _identificadorPrestadorDaConsulta;
  String? _mensagemAvisoConsultaBackend;
  int _progressoConsultasConcluidas = 0;
  int _totalConsultas = 0;
  bool _disposed = false;
  BloqueioPortal? _bloqueioPortal;
  Timer? _timerBloqueio;

  EtapaConsultaBackend get etapaConsultaBackend => _etapaConsultaBackend;
  BloqueioPortal? get bloqueioPortal => _bloqueioPortal;
  int get totalConsultasPendentes => _consultasPendentes.length;
  bool get temConsultasPendentes => _consultasPendentes.isNotEmpty;
  String? get mensagemAvisoConsultaBackend => _mensagemAvisoConsultaBackend;
  int get progressoConsultasConcluidas => _progressoConsultasConcluidas;
  int get totalConsultas => _totalConsultas;
  double get fracaoProgressoConsultas => _totalConsultas == 0
      ? 0
      : _progressoConsultasConcluidas / _totalConsultas;

  EstadoConexao _estadoConexao = EstadoConexao.verificando;

  EstadoConexao get estadoConexao => _estadoConexao;

  Future<void> verificarDisponibilidadeApi() async {
    final SulAmericaBackendService? service = _service;
    _estadoConexao = EstadoConexao.verificando;
    notifyListeners();
    if (service == null) {
      _estadoConexao = EstadoConexao.apiIndisponivel;
      notifyListeners();
      return;
    }

    final Result<Map<String, dynamic>> status = await service.status();
    if (status is Success<Map<String, dynamic>>) {
      _atualizarBloqueio(status.valor['bloqueio']);
    }
    _estadoConexao = status is Success<Map<String, dynamic>>
        ? EstadoConexao.pronto
        : EstadoConexao.apiIndisponivel;
    notifyListeners();
  }

  Future<bool> verificarBloqueioAgora() => _consultarBloqueio();

  Future<bool> _consultarBloqueio() async {
    final SulAmericaBackendService? service = _service;
    if (service == null) return _bloqueioPortal != null;

    final Result<Map<String, dynamic>> resposta = await service.status();
    if (resposta is Success<Map<String, dynamic>>) {
      _atualizarBloqueio(resposta.valor['bloqueio']);
      return _bloqueioPortal != null;
    }

    final AppException? falha = resposta.fold<AppException?>(
      onSuccess: (_) => null,
      onFailure: (erro) => erro,
    );
    if (falha is ServicoIndisponivelException) {
      if (_ativarBloqueioJson(falha.bloqueio)) return true;
    }
    final BloqueioPortal? bloqueio = _bloqueioPortal;
    if (bloqueio != null) {
      _bloqueioPortal = bloqueio.comSegundosRestantes(5);
      _agendarTimerBloqueio();
      notifyListeners();
    }
    return _bloqueioPortal != null;
  }

  void _atualizarBloqueio(Object? valor) {
    if (valor is Map && valor['ativo'] == true) {
      _ativarBloqueioJson(valor.cast<String, dynamic>());
      return;
    }
    if (_bloqueioPortal == null) return;
    _timerBloqueio?.cancel();
    _timerBloqueio = null;
    _bloqueioPortal = null;
    notifyListeners();
  }

  bool _ativarBloqueioJson(Map<String, dynamic>? json) {
    if (json == null || json['ativo'] != true) return false;
    _ativarBloqueio(BloqueioPortal.fromJson(json));
    return true;
  }

  Future<bool> _consultarBloqueioAposFalha(AppException? erro) async {
    if (erro is! ServicoIndisponivelException) return false;
    if (_ativarBloqueioJson(erro.bloqueio)) return true;
    return _consultarBloqueio();
  }

  void _ativarBloqueio(BloqueioPortal bloqueio) {
    _bloqueioPortal = bloqueio;
    _agendarTimerBloqueio();
    _retornarAoInicioBloqueado();
  }

  void _agendarTimerBloqueio() {
    _timerBloqueio?.cancel();
    final BloqueioPortal? bloqueio = _bloqueioPortal;
    if (bloqueio == null) return;
    if (bloqueio.segundosRestantes == 0) {
      _timerBloqueio = Timer(const Duration(seconds: 1), () {
        _timerBloqueio = null;
        if (!_disposed) unawaited(_consultarBloqueio());
      });
    } else {
      _timerBloqueio = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        final BloqueioPortal? atual = _bloqueioPortal;
        if (atual == null) {
          timer.cancel();
          return;
        }
        final int restantes = atual.segundosRestantes - 1;
        _bloqueioPortal = atual.comSegundosRestantes(restantes);
        notifyListeners();
        if (restantes <= 0) {
          timer.cancel();
          _timerBloqueio = null;
          unawaited(_consultarBloqueio());
        }
      });
    }
  }

  void _retornarAoInicioBloqueado() {
    if (_descartandoLoteBloqueado) return;
    _descartandoLoteBloqueado = true;
    _status = StatusValidador.semArquivo;
    _nomeArquivo = null;
    _bytesArquivo = null;
    _resultado = const [];
    _mensagemErro = null;
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = null;
    _tempoProcessamento = Duration.zero;
    _limparEstadoConsultas();
    _descartandoLoteBloqueado = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timerBloqueio?.cancel();
    super.dispose();
  }

  StatusValidador _status = StatusValidador.semArquivo;
  String? _nomeArquivo;
  Uint8List? _bytesArquivo;
  List<GuiaValidada> _resultado = const [];
  String? _mensagemErro;
  InformacoesLote _informacoes = InformacoesLote.vazio;
  String? _hashMd5;
  Duration _tempoProcessamento = Duration.zero;

  StatusValidador get status => _status;
  String? get nomeArquivo => _nomeArquivo;
  String? get mensagemErro => _mensagemErro;
  int? get tamanhoArquivoBytes => _bytesArquivo?.length;
  List<GuiaValidada> get guiasComErro =>
      _resultado.where((g) => g.temErro || g.temFalhaConsulta).toList();
  List<GuiaValidada> get guias => _resultado;
  int get totalGuias => _resultado.length;
  int get totalGuiasComErro => _resultado.where((guia) => guia.temErro).length;
  InformacoesLote get informacoes => _informacoes;
  String? get hashMd5 => _hashMd5;
  Duration get tempoProcessamento => _tempoProcessamento;

  static SulAmericaBackendService? _servicePadrao() {
    try {
      return GetIt.instance.get<SulAmericaBackendService>();
    } catch (_) {
      return null;
    }
  }

  void definirArquivo({required String nomeArquivo, required Uint8List bytes}) {
    if (_bloqueioPortal != null) return;
    _nomeArquivo = nomeArquivo;
    _bytesArquivo = bytes;
    _status = StatusValidador.arquivoPronto;
    _mensagemErro = null;
    _resultado = const [];
    _limparEstadoConsultas();
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = md5.convert(bytes).toString();
    notifyListeners();
  }

  Future<void> validar() async {
    if (await _consultarBloqueio()) return;
    final Uint8List? bytes = _bytesArquivo;
    if (bytes == null) return;

    _status = StatusValidador.validando;
    _mensagemErro = null;
    _limparEstadoConsultas();
    notifyListeners();

    final Stopwatch cronometro = Stopwatch()..start();
    try {
      final String conteudoXml = _decodificarXml(bytes);
      await _repository.preparar();
      final LoteGuiasExtraido lote = _datasource.extrairLote(conteudoXml);
      final InformacoesLote informacoes = lote.informacoes;
      final List<GuiaValidada> resultadoBruto = await Future(
        () => _repository.validarGuias(lote.guias),
      );
      final String? identificadorPrestador = _regraCredenciais.resolver(
        informacoes.prestadorCnpjCpf,
      );
      final List<GuiaValidada> resultado = await _consultarGuias(
        resultadoBruto,
        identificadorPrestador,
      );
      if (_bloqueioPortal != null) {
        _retornarAoInicioBloqueado();
        return;
      }

      _resultado = _ordenarPorNumeroGuia(resultado);
      _informacoes = informacoes;
      _status = StatusValidador.concluido;
    } on XmlMalFormadoException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = erro.toString();
    } on NenhumaGuiaEncontradaException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = erro.toString();
    } on TussBaseLocalInvalidaException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = 'Não foi possível carregar a base TUSS: ${erro.mensagem}';
    } catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = 'Erro inesperado ao validar o arquivo: $erro';
    } finally {
      cronometro.stop();
      _tempoProcessamento = cronometro.elapsed;
    }
    notifyListeners();
  }

  void novoArquivo() {
    _status = StatusValidador.semArquivo;
    _nomeArquivo = null;
    _bytesArquivo = null;
    _resultado = const [];
    _limparEstadoConsultas();
    _mensagemErro = null;
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = null;
    _tempoProcessamento = Duration.zero;
    notifyListeners();
  }

  Future<List<GuiaValidada>> _consultarGuias(
    List<GuiaValidada> guias,
    String? identificadorPrestador,
  ) async {
    final SulAmericaBackendService? service = _service;
    _limparEstadoConsultas();
    _identificadorPrestadorDaConsulta = identificadorPrestador;
    if (service == null || guias.isEmpty) {
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return guias;
    }

    final List<GuiaValidada> base = List.of(guias);
    for (int i = 0; i < base.length; i++) {
      final GuiaValidada guia = base[i];
      final String? senha = guia.senha;
      final String? carteira = guia.numeroCarteira;
      final bool senhaInvalida =
          senha != null && senha.isNotEmpty && !_senhaValida(senha);
      final bool carteiraInvalida =
          carteira != null && carteira.isNotEmpty && !_carteiraValida(carteira);
      final List<ConsultaGuia> errosLocais = [];
      if (senhaInvalida) {
        errosLocais.add(
          ConsultaGuia(
            tipo: TipoConsultaGuia.senha,
            sucesso: false,
            descricao: '${AppStrings.erroSenhaInvalida} ($senha)',
          ),
        );
      }
      if (carteiraInvalida) {
        errosLocais.add(
          ConsultaGuia(
            tipo: TipoConsultaGuia.elegibilidade,
            sucesso: false,
            descricao: '${AppStrings.erroCarteiraInvalida} ($carteira)',
          ),
        );
      }
      if (errosLocais.isNotEmpty) {
        base[i] = GuiaValidada(
          guia: guia.guia,
          erros: senhaInvalida
              ? guia.erros.where((e) => e.campo != 'senha').toList()
              : guia.erros,
          consultas: errosLocais,
        );
      }
    }

    final List<ConsultaLoteItem> itens = [];
    final Set<String> chavesVistas = {};
    for (final GuiaValidada guia in base) {
      for (final ConsultaLoteItem item in _itensDeConsulta(guia)) {
        if (chavesVistas.add(_chaveConsulta(item))) itens.add(item);
      }
    }
    _guiasBaseConsultas = base;
    _resultado = List.of(base);
    _totalConsultas = itens.length;
    if (itens.isEmpty) {
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return base;
    }
    if (identificadorPrestador == null) {
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return base;
    }

    _etapaConsultaBackend = EtapaConsultaBackend.consultando;
    for (
      int inicio = 0;
      inicio < itens.length;
      inicio += _maxConsultasPorLote
    ) {
      final int fim = min(inicio + _maxConsultasPorLote, itens.length).toInt();
      await _processarConsultas(
        service,
        itens.sublist(inicio, fim),
        _progressoConsultasConcluidas,
      );
      if (_bloqueioPortal != null) return const <GuiaValidada>[];
    }
    _atualizarResultado();
    _etapaConsultaBackend = _consultasPendentes.isEmpty
        ? EtapaConsultaBackend.concluida
        : EtapaConsultaBackend.pendente;
    notifyListeners();
    return _resultado;
  }

  Future<void> _processarConsultas(
    SulAmericaBackendService service,
    List<ConsultaLoteItem> consultas,
    int progressoBase,
  ) async {
    final tokenInicial = await _obterTokenSessao(
      service,
      _identificadorPrestadorDaConsulta,
    );
    final String? tokenInicialValido = tokenInicial.token;
    if (tokenInicialValido == null) {
      if (_bloqueioPortal != null) return;
      final AppException? falha = tokenInicial.falha;
      if (falha is NaoAutorizadoException) {
        _avisarFalhaAutenticacao();
      } else {
        _registrarConsultasPendentes(consultas);
        _mensagemAvisoConsultaBackend = falha == null
            ? tokenInicial.mensagemErro
            : _mensagemAmigavelConsulta(falha);
      }
      _atualizarResultado();
      return;
    }
    String token = tokenInicialValido;

    final String idempotencyKey = _novaChaveIdempotencia();
    int tentativasFilaCheia = 0;
    int tentativasTransporte = 0;
    bool reautenticouSubmissao = false;
    LoteRemoto? loteRemoto;

    while (loteRemoto == null) {
      final Result<LoteRemoto> resposta = await service.criarLote(
        token: token,
        idempotencyKey: idempotencyKey,
        consultas: consultas,
      );
      final AppException? falha = resposta.fold<AppException?>(
        onSuccess: (_) => null,
        onFailure: (erro) => erro,
      );
      if (falha == null) {
        loteRemoto = resposta.fold<LoteRemoto>(
          onSuccess: (lote) => lote,
          onFailure: (_) => throw StateError('Resultado inconsistente.'),
        );
        break;
      }

      if (await _consultarBloqueioAposFalha(falha)) return;

      if (falha is NaoAutorizadoException && !reautenticouSubmissao) {
        reautenticouSubmissao = true;
        _invalidarTokenSessao();
        final refresh = await _obterTokenSessao(
          service,
          _identificadorPrestadorDaConsulta,
        );
        final String? novoToken = refresh.token;
        if (novoToken != null) {
          token = novoToken;
          continue;
        }
        _mensagemAvisoConsultaBackend = refresh.falha == null
            ? refresh.mensagemErro
            : _mensagemAmigavelConsulta(refresh.falha!);
        if (refresh.falha is NaoAutorizadoException) {
          _avisarFalhaAutenticacao();
        }
        break;
      }

      if ((falha is FilaCheiaException ||
              falha is ServicoIndisponivelException) &&
          tentativasFilaCheia < _intervalosFilaCheia.length) {
        _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
        notifyListeners();
        final Duration? retryAfter = _retryAfter(falha);
        final Duration espera = retryAfter == null
            ? _intervalosFilaCheia[tentativasFilaCheia]
            : _limitarRetryAfter(retryAfter);
        tentativasFilaCheia++;
        await _aguardarRetentativa(espera);
        _etapaConsultaBackend = EtapaConsultaBackend.consultando;
        continue;
      }

      if (_falhaTransporte(falha) &&
          tentativasTransporte < _intervalosRetentativa.length) {
        _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
        notifyListeners();
        await _aguardarRetentativa(
          _intervalosRetentativa[tentativasTransporte],
        );
        tentativasTransporte++;
        _etapaConsultaBackend = EtapaConsultaBackend.consultando;
        continue;
      }

      if (falha is NaoAutorizadoException) {
        _avisarFalhaAutenticacao();
      }
      _mensagemAvisoConsultaBackend = _mensagemAmigavelConsulta(falha);
      break;
    }

    final LoteRemoto? loteAceito = loteRemoto;
    if (loteAceito == null || loteAceito.id.isEmpty) {
      _mensagemAvisoConsultaBackend ??=
          'O backend não retornou o identificador do lote.';
      _registrarConsultasPendentes(consultas);
      _atualizarResultado();
      return;
    }

    await _acompanharLote(service, loteAceito, consultas, token, progressoBase);
  }

  Future<void> _acompanharLote(
    SulAmericaBackendService service,
    LoteRemoto lote,
    List<ConsultaLoteItem> consultas,
    String tokenInicial,
    int progressoBase,
  ) async {
    String token = tokenInicial;
    int? ultimoId;
    int reconexoes = 0;
    bool reautenticouSse = false;
    int progressoLote = 0;

    while (true) {
      final ConexaoSse conexao = service.abrirEventos(
        token: token,
        idLote: lote.id,
        desde: ultimoId,
      );
      final leitura = await _lerEventosLote(
        conexao,
        onEvento: (EventoSse evento) {
          final int? id = int.tryParse(evento.id ?? '');
          if (id != null && (ultimoId == null || id > ultimoId!)) {
            ultimoId = id;
          }
          if (evento.evento == 'progresso') {
            final Map<String, dynamic>? dados = _decodificarEvento(
              evento.dados,
            );
            if (dados != null) {
              final ProgressoLote progresso = ProgressoLote.fromJson(dados);
              progressoLote = max(
                progressoLote,
                min(progresso.concluidas, consultas.length),
              ).toInt();
              _progressoConsultasConcluidas = max(
                _progressoConsultasConcluidas,
                progressoBase + progressoLote,
              ).toInt();
              notifyListeners();
            }
          }
        },
      );

      if (leitura.bloqueio != null) {
        _ativarBloqueio(leitura.bloqueio!);
        return;
      }

      if (leitura.resultado != null) {
        _aplicarResultadoLote(consultas, leitura.resultado!);
        _progressoConsultasConcluidas = max(
          _progressoConsultasConcluidas,
          progressoBase +
              (leitura.resultado!.status == 'parcial'
                  ? leitura.resultado!.resultados.length
                  : consultas.length),
        ).toInt();
        _atualizarResultado();
        return;
      }

      final AppException? erro = leitura.erro;
      if (erro is NaoAutorizadoException && !reautenticouSse) {
        reautenticouSse = true;
        _invalidarTokenSessao();
        final refresh = await _obterTokenSessao(
          service,
          _identificadorPrestadorDaConsulta,
        );
        if (refresh.token != null) {
          token = refresh.token!;
          continue;
        }
        _mensagemAvisoConsultaBackend = refresh.falha == null
            ? refresh.mensagemErro
            : _mensagemAmigavelConsulta(refresh.falha!);
        if (refresh.falha is NaoAutorizadoException) {
          _avisarFalhaAutenticacao();
        }
        break;
      }

      final bool streamInterrompido =
          leitura.streamFechou || (erro != null && _falhaTransporte(erro));
      if ((erro != null || leitura.streamFechou) &&
          await _consultarBloqueio()) {
        return;
      }
      if (streamInterrompido && reconexoes < _intervalosRetentativa.length) {
        _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
        notifyListeners();
        await _aguardarRetentativa(_intervalosRetentativa[reconexoes]);
        reconexoes++;
        _etapaConsultaBackend = EtapaConsultaBackend.consultando;
        continue;
      }

      if (erro != null) {
        _mensagemAvisoConsultaBackend = _mensagemAmigavelConsulta(erro);
      }
      break;
    }

    _registrarConsultasPendentes(consultas);
    _atualizarResultado();
  }

  Future<
    ({
      ResultadoLoteEvento? resultado,
      AppException? erro,
      BloqueioPortal? bloqueio,
      bool streamFechou,
    })
  >
  _lerEventosLote(
    ConexaoSse conexao, {
    required void Function(EventoSse) onEvento,
  }) async {
    final completer =
        Completer<
          ({
            ResultadoLoteEvento? resultado,
            AppException? erro,
            BloqueioPortal? bloqueio,
            bool streamFechou,
          })
        >();
    late final StreamSubscription<EventoSse> subscription;
    subscription = conexao.eventos.listen(
      (EventoSse evento) {
        try {
          onEvento(evento);
          if (evento.evento == 'resultado') {
            final Map<String, dynamic>? dados = _decodificarEvento(
              evento.dados,
            );
            if (dados == null) {
              completer.complete((
                resultado: null,
                erro: const ErroDesconhecidoException(
                  'Evento de resultado SSE inválido.',
                ),
                bloqueio: null,
                streamFechou: false,
              ));
              return;
            }
            completer.complete((
              resultado: ResultadoLoteEvento.fromJson(dados),
              erro: null,
              bloqueio: null,
              streamFechou: false,
            ));
          }
          if (evento.evento == 'erro') {
            final Map<String, dynamic>? dados = _decodificarEvento(
              evento.dados,
            );
            final Object? valorBloqueio = dados?['bloqueio'];
            final BloqueioPortal? bloqueio = valorBloqueio is Map &&
                    valorBloqueio['ativo'] == true
                ? BloqueioPortal.fromJson(
                    valorBloqueio.cast<String, dynamic>(),
                  )
                : null;
            completer.complete((
              resultado: null,
              erro: bloqueio == null
                  ? ErroDesconhecidoException(
                      dados?['mensagem'] as String? ??
                          AppStrings.erroConsultaBackendGenerico,
                    )
                  : null,
              bloqueio: bloqueio,
              streamFechou: false,
            ));
          }
        } on FormatException {
          if (!completer.isCompleted) {
            completer.complete((
              resultado: null,
              erro: const ErroDesconhecidoException(
                AppStrings.erroConsultaBackendGenerico,
              ),
              bloqueio: null,
              streamFechou: false,
            ));
          }
        } on TypeError {
          if (!completer.isCompleted) {
            completer.complete((
              resultado: null,
              erro: const ErroDesconhecidoException(
                AppStrings.erroConsultaBackendGenerico,
              ),
              bloqueio: null,
              streamFechou: false,
            ));
          }
        }
      },
      onError: (Object erro, StackTrace _) {
        if (!completer.isCompleted) {
          completer.complete((
            resultado: null,
            erro: erro is AppException
                ? erro
                : const ErroDesconhecidoException(
                    AppStrings.erroConsultaBackendGenerico,
                  ),
            bloqueio: null,
            streamFechou: false,
          ));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete((
            resultado: null,
            erro: null,
            bloqueio: null,
            streamFechou: true,
          ));
        }
      },
    );
    final leitura = await completer.future;
    await subscription.cancel();
    conexao.cancelar();
    return leitura;
  }

  Map<String, dynamic>? _decodificarEvento(String dados) {
    final Object? valor = jsonDecode(dados);
    return valor is Map<String, dynamic> ? valor : null;
  }

  void _aplicarResultadoLote(
    List<ConsultaLoteItem> consultas,
    ResultadoLoteEvento evento,
  ) {
    final Set<String> solicitadas = consultas.map(_chaveConsulta).toSet();
    final Set<String> declaradasPendentes = evento.pendentes
        .map(
          (PendenciaConsultaLote pendencia) =>
              '${pendencia.tipo.name}|${pendencia.chave}',
        )
        .where(solicitadas.contains)
        .toSet();
    final Set<String> resolvidas = {};
    for (final ResultadoConsultaLote resultado in evento.resultados) {
      final String chave = '${resultado.tipo.name}|${resultado.chave}';
      if (!solicitadas.contains(chave)) continue;
      if (declaradasPendentes.contains(chave) ||
          _falhaTransitoriaNoResultado(resultado)) {
        continue;
      }
      _resultadosConsultas[chave] = _consultaDesdeBatch(resultado);
      _consultasPendentes.remove(chave);
      resolvidas.add(chave);
    }
    for (final ConsultaLoteItem item in consultas) {
      final String chave = _chaveConsulta(item);
      if (!resolvidas.contains(chave) &&
          (evento.status != 'parcial' ||
              declaradasPendentes.contains(chave) ||
              evento.resultados.any(
                (ResultadoConsultaLote resultado) =>
                    '${resultado.tipo.name}|${resultado.chave}' == chave &&
                    _falhaTransitoriaNoResultado(resultado),
              ))) {
        _consultasPendentes[_chaveConsulta(item)] = item;
      }
    }
    if (evento.pendentes.any(
      (PendenciaConsultaLote pendencia) =>
          pendencia.motivo == 'prazo_5_minutos',
    )) {
      _mensagemAvisoConsultaBackend = AppStrings.consultasPrazoExpirado;
    }
  }

  String _novaChaveIdempotencia() => base64Url
      .encode(List<int>.generate(24, (_) => _aleatorio.nextInt(256)))
      .replaceAll('=', '');

  Duration _limitarRetryAfter(Duration duracao) {
    if (duracao.isNegative) return Duration.zero;
    return duracao > _limiteRetryAfterLote ? _limiteRetryAfterLote : duracao;
  }

  bool _falhaTransporte(AppException erro) =>
      erro is SemConexaoException || erro is RequisicaoExpiradaException;

  void _registrarConsultasPendentes(Iterable<ConsultaLoteItem> itens) {
    for (final ConsultaLoteItem item in itens) {
      _consultasPendentes[_chaveConsulta(item)] = item;
    }
  }

  void _invalidarTokenSessao() {
    _tokenSessao = null;
    _identificadorPrestadorDoToken = null;
  }

  void _avisarFalhaAutenticacao() {
    _mensagemAvisoConsultaBackend = AppStrings.erroLoginFalhou;
  }

  String _mensagemAmigavelConsulta(AppException erro) {
    if (erro is FilaCheiaException) {
      return AppStrings.filaConsultaBackendCheia;
    }
    if (erro is ServicoIndisponivelException) {
      return AppStrings.servicoConsultaIndisponivel;
    }
    if (erro is SemConexaoException) {
      return AppStrings.erroConexaoConsultaBackend;
    }
    if (erro is RequisicaoExpiradaException) {
      return AppStrings.erroConsultaBackendExpirada;
    }
    if (erro is NaoAutorizadoException) {
      return AppStrings.erroSessaoConsultaBackend;
    }
    return AppStrings.erroConsultaBackendGenerico;
  }

  String _chaveConsulta(ConsultaLoteItem item) =>
      '${item.tipo.name}|${item.chave}';

  List<GuiaValidada> _aplicarResultadosConsultas(List<GuiaValidada> base) {
    final List<GuiaValidada> resultado = [];
    for (final GuiaValidada guia in base) {
      GuiaValidada atualizada = guia;
      for (final ConsultaLoteItem item in _itensDeConsulta(guia)) {
        final ConsultaGuia? consulta =
            _resultadosConsultas[_chaveConsulta(item)];
        if (consulta != null) {
          atualizada = _anexarConsulta(atualizada, consulta);
        }
      }
      resultado.add(atualizada);
    }
    return resultado;
  }

  void _atualizarResultado() {
    _resultado = _ordenarPorNumeroGuia(
      _aplicarResultadosConsultas(_guiasBaseConsultas),
    );
    notifyListeners();
  }

  void _limparEstadoConsultas() {
    _tokenSessao = null;
    _identificadorPrestadorDoToken = null;
    _consultasPendentes.clear();
    _resultadosConsultas.clear();
    _guiasBaseConsultas = const [];
    _identificadorPrestadorDaConsulta = null;
    _mensagemAvisoConsultaBackend = null;
    _etapaConsultaBackend = EtapaConsultaBackend.naoIniciada;
    _retentativaManualEmAndamento = false;
    _progressoConsultasConcluidas = 0;
    _totalConsultas = 0;
  }

  Future<void> retentarConsultasPendentes() async {
    final SulAmericaBackendService? service = _service;
    if (service == null ||
        _consultasPendentes.isEmpty ||
        _retentativaManualEmAndamento) {
      return;
    }
    if (await _consultarBloqueio()) return;
    _retentativaManualEmAndamento = true;
    _etapaConsultaBackend = EtapaConsultaBackend.consultando;
    final List<ConsultaLoteItem> consultas = _consultasPendentes.values
        .toList();
    _totalConsultas = consultas.length;
    _progressoConsultasConcluidas = 0;
    notifyListeners();
    try {
      for (
        int inicio = 0;
        inicio < consultas.length;
        inicio += _maxConsultasPorLote
      ) {
        final int fim = min(
          inicio + _maxConsultasPorLote,
          consultas.length,
        ).toInt();
        await _processarConsultas(
          service,
          consultas.sublist(inicio, fim),
          _progressoConsultasConcluidas,
        );
      }
      _etapaConsultaBackend = _consultasPendentes.isEmpty
          ? EtapaConsultaBackend.concluida
          : EtapaConsultaBackend.pendente;
    } finally {
      _retentativaManualEmAndamento = false;
      notifyListeners();
    }
  }

  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  static bool _senhaValida(String senha) =>
      RegraSenhaPrefixo.senhaValida(senha);

  List<ConsultaLoteItem> _itensDeConsulta(GuiaValidada guia) {
    final List<ConsultaLoteItem> itens = [];
    final String? carteira = guia.numeroCarteira;
    if (carteira != null && carteira.isNotEmpty && _carteiraValida(carteira)) {
      itens.add(
        ConsultaLoteItem(tipo: TipoConsultaGuia.elegibilidade, chave: carteira),
      );
    }
    final String? senha = guia.senha;
    if (senha != null && _senhaValida(senha)) {
      itens.add(ConsultaLoteItem(tipo: TipoConsultaGuia.senha, chave: senha));
    }
    return itens;
  }

  ConsultaGuia _consultaDesdeBatch(ResultadoConsultaLote r) {
    if (!r.sucesso) {
      return ConsultaGuia(
        tipo: r.tipo,
        sucesso: false,
        descricao: r.tipo == TipoConsultaGuia.elegibilidade
            ? 'Consulta de elegibilidade falhou: ${r.erro ?? 'sem detalhe'}'
            : 'Consulta de senha falhou: ${r.erro ?? 'sem detalhe'}',
      );
    }
    if (r.tipo == TipoConsultaGuia.elegibilidade) {
      return _consultaElegibilidade(r.elegivel, carteira: r.chave);
    }
    return _consultaSenha(r.statusSenha, senha: r.chave);
  }

  bool _falhaTransitoriaNoResultado(ResultadoConsultaLote resultado) =>
      !resultado.sucesso &&
      resultado.erro?.trim() == 'Falha na consulta ao portal SulAmerica.';

  ConsultaGuia _consultaElegibilidade(
    bool? elegivel, {
    required String carteira,
  }) {
    return switch (elegivel) {
      true => const ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: true,
        descricao: 'Elegível: SIM',
      ),
      false => ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: false,
        descricao: '${AppStrings.erroNaoElegivel} ($carteira)',
      ),
      null => ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: false,
        descricao: '${AppStrings.erroCarteiraNaoEncontrada} ($carteira)',
      ),
    };
  }

  ConsultaGuia _consultaSenha(String? descricao, {required String senha}) {
    final bool autorizada = _descricaoAutorizada(descricao);
    return ConsultaGuia(
      tipo: TipoConsultaGuia.senha,
      sucesso: autorizada,
      descricao: autorizada
          ? 'Senha: ok'
          : descricao == null
          ? '${AppStrings.erroSenhaNaoEncontrada} ($senha)'
          : 'Senha: $descricao ($senha)',
    );
  }

  static bool _descricaoAutorizada(String? descricao) =>
      descricao != null && descricao.toLowerCase().contains('autorizado');

  Future<({String? token, String? mensagemErro, AppException? falha})>
  _obterTokenSessao(
    SulAmericaBackendService service,
    String? identificadorPrestador,
  ) async {
    if (identificadorPrestador == null) {
      return (
        token: null,
        mensagemErro: AppStrings.erroCredenciaisAusentes,
        falha: null,
      );
    }
    if (_tokenSessao != null &&
        _identificadorPrestadorDoToken == identificadorPrestador) {
      return (token: _tokenSessao, mensagemErro: null, falha: null);
    }

    Result<String> resultado = await service.criarSessao(
      identificadorPrestador: identificadorPrestador,
    );
    AppException? falha = resultado.fold<AppException?>(
      onSuccess: (_) => null,
      onFailure: (erro) => erro,
    );
    if (await _consultarBloqueioAposFalha(falha)) {
      return (token: null, mensagemErro: falha!.mensagem, falha: falha);
    }
    final Duration? retryAfter = falha == null ? null : _retryAfter(falha);
    if ((falha is FilaCheiaException ||
            falha is ServicoIndisponivelException) &&
        retryAfter != null) {
      _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
      notifyListeners();
      await _aguardarRetentativa(_limitarRetryAfter(retryAfter));
      _etapaConsultaBackend = EtapaConsultaBackend.consultando;
      resultado = await service.criarSessao(
        identificadorPrestador: identificadorPrestador,
      );
      falha = resultado.fold<AppException?>(
        onSuccess: (_) => null,
        onFailure: (erro) => erro,
      );
      if (await _consultarBloqueioAposFalha(falha)) {
        return (token: null, mensagemErro: falha!.mensagem, falha: falha);
      }
    }

    if (falha != null) {
      return (token: null, mensagemErro: falha.mensagem, falha: falha);
    }
    final String token = resultado.fold<String>(
      onSuccess: (valor) => valor,
      onFailure: (_) => throw StateError('Resultado inconsistente.'),
    );
    _tokenSessao = token;
    _identificadorPrestadorDoToken = identificadorPrestador;
    return (token: token, mensagemErro: null, falha: null);
  }

  GuiaValidada _anexarConsulta(GuiaValidada guia, ConsultaGuia consulta) =>
      GuiaValidada(
        guia: guia.guia,
        erros: guia.erros,
        consultas: [...guia.consultas, consulta],
      );

  String _decodificarXml(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  List<GuiaValidada> _ordenarPorNumeroGuia(List<GuiaValidada> lista) {
    final List<MapEntry<int, GuiaValidada>> indexado = List.generate(
      lista.length,
      (indice) => MapEntry(indice, lista[indice]),
    );
    indexado.sort((a, b) {
      final int comparacaoGuia = a.value.numeroGuiaPrestador.compareTo(
        b.value.numeroGuiaPrestador,
      );
      return comparacaoGuia != 0 ? comparacaoGuia : a.key.compareTo(b.key);
    });
    return indexado.map((entrada) => entrada.value).toList();
  }
}
