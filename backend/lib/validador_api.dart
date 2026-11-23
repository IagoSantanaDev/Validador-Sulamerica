import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:validador_backend/http/auth.dart';
import 'package:validador_backend/http/cors.dart';
import 'package:validador_backend/http/json.dart';
import 'package:validador_backend/http/rate_limit.dart';
import 'package:validador_backend/http/sse.dart';
import 'package:validador_backend/modules/sulamerica/data/agendador_lotes.dart';
import 'package:validador_backend/modules/sulamerica/data/assinatura_resposta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/disjuntor_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/repositorio_sessoes.dart';
import 'package:validador_backend/modules/sulamerica/data/resultado_consulta_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

import 'elegibilidade_parser.dart';

export 'modules/sulamerica/data/resultado_consulta_portal.dart'
    show ehFalhaDeSessaoPortal;

class ValidadorApi {
  ValidadorApi({
    Logger? logger,
    Map<String, String>? ambiente,
    SessaoPortal Function(Logger logger)? fabricaSessao,
    Future<int> Function()? sondaPortal,
    Future<ResultadoSondaDisjuntor> Function()? sondaDisjuntor,
    Duration janelaCacheAlcance = const Duration(seconds: 10),
    RepositorioSessoes? repositorio,
    RateLimit? rateLimit,
    DisjuntorPortal? disjuntor,
    int limiteSessoesLogicas = 200,
    int limiteRequisicoesPorChave = 20,
    int limiteRequisicoesGlobal = 120,
    int limiteSessoesPorIdentificador = 4,
    int limiteExecucoes = 24,
  }) : _logger = logger ?? Logger(),
       _ambiente = ambiente,
       _janelaCacheAlcance = janelaCacheAlcance,
       _sondaPortal = sondaPortal ?? _sondarPortalPadrao,
       _repositorio =
           repositorio ?? RepositorioSessoes(limite: limiteSessoesLogicas),
       _rateLimit =
           rateLimit ??
           RateLimit(
             limitePorChave: limiteRequisicoesPorChave,
             limiteGlobal: limiteRequisicoesGlobal,
           ) {
    _pool = PoolSessoesPortal(
      logger: _logger,
      fabricaSessao: fabricaSessao,
      limitePorIdentificador: limiteSessoesPorIdentificador,
      repetirFalhasTransitorias: false,
    );
    final Future<int> Function()? sondaPortalPersonalizada = sondaPortal;
    _disjuntor =
        disjuntor ??
        DisjuntorPortal(
          sondarPortal:
              sondaDisjuntor ??
              (sondaPortalPersonalizada == null
                  ? _sondarPortalDisjuntorPadrao
                  : () async => ResultadoSondaDisjuntor(
                      status: await sondaPortalPersonalizada(),
                    )),
        );
    _disjuntor.aoAbrir = (Map<String, Object?> bloqueio) {
      _agendador.cancelarTodos(bloqueio);
    };
    _agendador = AgendadorLotes(
      pool: _pool,
      limiteExecucoes: limiteExecucoes,
      limiteGlobal: SessaoPortal.limiteRequisicoesGlobal,
      executarConsulta: _executarConsultaPortal,
      mapearFalhaSessao: _mapearFalhaSessaoLote,
      validarConsulta: _validarFormatoConsulta,
      disjuntor: _disjuntor,
    );
  }

  final Logger _logger;
  final Map<String, String>? _ambiente;
  final Duration _janelaCacheAlcance;
  final Future<int> Function() _sondaPortal;
  final RepositorioSessoes _repositorio;
  final RateLimit _rateLimit;
  late final PoolSessoesPortal _pool;
  late final AgendadorLotes _agendador;
  late final DisjuntorPortal _disjuntor;

  static const int _maxItensPorLote = 300;
  static const int _maxBytesCorpo = 1 << 20;
  static const Duration _ttlCacheAlcance = Duration(seconds: 10);

  int _rejeicoes429 = 0;
  int _falhas502 = 0;
  int _falhas503 = 0;
  final Map<String, int> _falhasConsulta = <String, int>{};
  Map<String, dynamic>? _alcanceCacheado;
  DateTime? _alcanceColetadoEm;
  Future<Map<String, dynamic>>? _sondaEmAndamento;
  final Map<String, _StreamAtivo> _streamsAtivos = <String, _StreamAtivo>{};

  late final Router _rotas = Router()
    ..post('/api/sessoes', _criarSessao)
    ..post('/api/lotes', _criarLote)
    ..get('/api/lotes/<id>/eventos', _eventos)
    ..get('/api/status', _status)
    ..all('/<ignored|.*>', _naoEncontrado);

  late final Handler _handler = const Pipeline()
      .addMiddleware(_exporRetryAfterCors())
      .addMiddleware(
        cors(
          origens:
              (_ambiente ?? Platform.environment)['CORS_ORIGIN']?.split(',') ??
              const <String>[],
        ),
      )
      .addHandler(_rotas.call);

  Handler get handler => _handler;

  int get lotesAtivos => _agendador.ativas;

  Future<Response> _criarSessao(Request request) async {
    final Map<String, dynamic>? corpo;
    try {
      corpo = await lerCorpoJson(request, limiteBytes: _maxBytesCorpo);
    } on CorpoJsonExcedeLimite {
      return _erroCorpoGrande();
    }
    if (corpo == null) return respostaErro('Corpo JSON invalido.', 400);
    final dynamic recebido = corpo['identificadorPrestador'];
    if (recebido is! String || recebido.trim().isEmpty) {
      return respostaErro('Campo identificadorPrestador e obrigatorio.', 400);
    }
    final String identificador = recebido.trim();
    final CredenciaisPortal? credenciais = CredenciaisPortal.resolver(
      identificador,
      ambiente: _ambiente,
    );
    if (credenciais == null) {
      return respostaErro('Identificador de prestador nao autorizado.', 401);
    }

    final PermissaoDisjuntorPortal? permissao = await _disjuntor
        .tentarAdquirir();
    if (permissao == null) return _respostaDisjuntorAberto();

    final ResultadoRateLimit limite = _rateLimit.consumirPrestador(
      identificador,
    );
    if (!limite.permitido) {
      permissao.concluir(ResultadoDisjuntorPortal.neutra);
      _rejeicoes429++;
      return respostaErro(
        'Muitas requisicoes. Aguarde um instante.',
        429,
        headers: cabecalhosRetryAfter(limite.retryAfterSegundos),
      );
    }

    late final SessaoLogica sessaoLogica;
    try {
      sessaoLogica = _repositorio.criar(identificador);
    } on RepositorioSessoesCheioException {
      permissao.concluir(ResultadoDisjuntorPortal.neutra);
      _rejeicoes429++;
      return respostaErro('Limite de sessoes ativas atingido.', 429);
    }

    try {
      await _pool.garantirAutenticada(identificador, credenciais);
      permissao.concluir(ResultadoDisjuntorPortal.neutra);
    } on FalhaPoolSessoesException catch (erro) {
      permissao.concluir(
        erro.resultado.falhaElegivelCircuito
            ? ResultadoDisjuntorPortal.falhaElegivel
            : ResultadoDisjuntorPortal.neutra,
        motivo: erro.resultado.motivoBloqueio,
        retryAfter: erro.resultado.retryAfter,
      );
      _repositorio.remover(sessaoLogica.token);
      if (_disjuntor.estaBloqueado) return _respostaDisjuntorAberto();
      final int status = _statusFalhaLogin(erro.resultado);
      _contarFalhaUpstream(status);
      _logger.w('Criacao de sessao rejeitada: falha no login do portal.');
      return respostaErro(
        _mensagemFalhaLogin(status),
        status,
      );
    } on Exception {
      permissao.concluir(ResultadoDisjuntorPortal.neutra);
      _repositorio.remover(sessaoLogica.token);
      _logger.e('Falha interna ao criar sessao logica.');
      return respostaErro(_mensagemFalhaLogin(500), 500);
    }

    final Map<String, dynamic> corpoResposta = <String, dynamic>{
      'token': sessaoLogica.token,
      'identificadorPrestador': identificador,
    };
    return respostaJson(corpoResposta, status: 201);
  }

  Future<Response> _criarLote(Request request) async {
    final Map<String, dynamic>? corpo;
    try {
      corpo = await lerCorpoJson(request, limiteBytes: _maxBytesCorpo);
    } on CorpoJsonExcedeLimite {
      return _erroCorpoGrande();
    }
    if (corpo == null) return respostaErro('Corpo JSON invalido.', 400);

    if (corpo['consultas'] is List &&
        (corpo['consultas'] as List).length > _maxItensPorLote) {
      return respostaErro(
        'Lote excede o limite de $_maxItensPorLote itens por requisicao.',
        413,
      );
    }
    final List<Map<String, dynamic>>? consultas = _validarConsultas(
      corpo['consultas'],
    );
    if (consultas == null) {
      return respostaErro('Campo consultas invalido.', 400);
    }

    final String? token = tokenBearer(request);
    if (token == null) {
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }
    final SessaoLogica? sessaoLogica = _repositorio.obter(token);
    if (sessaoLogica == null) {
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }

    final String? chave = request.headers['idempotency-key']?.trim();
    if (chave == null || chave.isEmpty) {
      return respostaErro('Header Idempotency-Key e obrigatorio.', 400);
    }
    final ConsultaIdempotencia anterior = _repositorio.consultarIdempotencia(
      sessaoLogica,
      chave,
      consultas,
    );
    if (anterior.estado == EstadoIdempotencia.conflito) {
      return respostaErro(
        'Idempotency-Key ja usada com payload diferente.',
        409,
      );
    }
    if (anterior.estado == EstadoIdempotencia.repetida) {
      final ExecucaoLote execucao = anterior.execucao!;
      return _respostaLote(anterior.id!, execucao, consultas.length);
    }

    final PermissaoDisjuntorPortal? permissao = await _disjuntor
        .tentarAdquirir();
    if (permissao == null) return _respostaDisjuntorAberto();
    permissao.concluir(ResultadoDisjuntorPortal.neutra);

    final ResultadoRateLimit limite = _rateLimit.consumirToken(token);
    if (!limite.permitido) {
      _rejeicoes429++;
      return respostaErro(
        'Muitas requisicoes. Aguarde um instante.',
        429,
        headers: cabecalhosRetryAfter(limite.retryAfterSegundos),
      );
    }

    final CredenciaisPortal? credenciais = CredenciaisPortal.resolver(
      sessaoLogica.identificadorPrestador,
      ambiente: _ambiente,
    );
    if (credenciais == null) {
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }

    late final ExecucaoAgendada agendada;
    try {
      agendada = _agendador.agendar(
        identificadorPrestador: sessaoLogica.identificadorPrestador,
        tokenDono: token,
        credenciais: credenciais,
        consultas: consultas,
        aoFinalizar: () {
          _repositorio.removerIdempotencia(token, chave, agendada.execucao);
          _repositorio.desvincular(token);
        },
      );
    } on FilaCheiaException {
      _rejeicoes429++;
      return respostaErro(
        'Fila de lotes cheia. Tente novamente.',
        429,
      );
    }
    if (!_repositorio.vincular(token)) {
      agendada.execucao.cancelar();
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }
    _repositorio.registrarIdempotencia(
      sessaoLogica,
      chave,
      consultas,
      agendada.id,
      agendada.execucao,
    );
    return _respostaLote(agendada.id, agendada.execucao, consultas.length);
  }

  Response _respostaLote(String id, ExecucaoLote execucao, int total) {
    final String estado = switch (execucao.estado) {
      EstadoExecucaoLote.naFila => 'na_fila',
      EstadoExecucaoLote.processando => 'processando',
      EstadoExecucaoLote.concluido => 'concluido',
      EstadoExecucaoLote.parcial => 'parcial',
      EstadoExecucaoLote.falhou => 'falhou',
      EstadoExecucaoLote.cancelado => 'cancelado',
    };
    return respostaJson(
      <String, dynamic>{'id': id, 'estado': estado, 'total': total},
      status: 202,
      headers: <String, String>{'location': '/api/lotes/$id/eventos'},
    );
  }

  Future<Response> _eventos(Request request, String id) async {
    final String? token = tokenBearer(request);
    if (token == null || _repositorio.obter(token) == null) {
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }
    final ExecucaoLote? execucao = _agendador.obterExecucao(id, token);
    if (execucao == null) return respostaErro('Lote nao encontrado.', 404);

    final String? desdeTexto =
        request.url.queryParameters['desde'] ??
        request.headers['last-event-id'];
    final int? desde = desdeTexto == null ? null : int.tryParse(desdeTexto);
    if (desdeTexto != null && (desde == null || desde < 0)) {
      return respostaErro('Parametro desde invalido.', 400);
    }
    if (!_repositorio.vincular(token)) {
      return respostaErro('Token de sessao invalido ou ausente.', 401);
    }

    final _StreamAtivo? anterior = _streamsAtivos.remove(id);
    await anterior?.fechar();
    late final _StreamAtivo stream;
    stream = _StreamAtivo(() {
      if (identical(_streamsAtivos[id], stream)) _streamsAtivos.remove(id);
      _repositorio.desvincular(token);
    });
    _streamsAtivos[id] = stream;
    stream.conectar(execucao.assinar(desde: desde));

    return Response(
      200,
      body: stream.stream,
      headers: cabecalhosSse(),
      context: const <String, Object>{'shelf.io.buffer_output': false},
    );
  }

  Future<ResultadoConsultaAgendada> _executarConsultaPortal(
    SessaoPortal sessao,
    Map<String, dynamic> consulta,
    CancelToken cancelToken,
  ) async {
    final String tipo = consulta['tipo'] as String;
    final String chave = consulta['chave'] as String;
    if (tipo == 'elegibilidade') {
      if (!_carteiraValida(chave)) {
        return ResultadoConsultaAgendada(
          dados: _falhaItem(
            consulta,
            'Carteira deve conter exatamente 20 digitos.',
          ),
        );
      }
      final ResultadoConsultaPortal<String> resposta = await sessao
          .consultarBeneficiario(
            carteirinhaCompleta: chave,
            cancelToken: cancelToken,
          );
      if (!resposta.sucesso) {
        _contarFalhaConsulta(resposta);
        return ResultadoConsultaAgendada(
          dados: _falhaItem(
            consulta,
            _mensagemFalhaConsulta(resposta.categoria, resposta.status),
          ),
          retryable: resposta.retryable,
          falhaElegivelCircuito: resposta.falhaElegivelCircuito,
          motivoBloqueio: resposta.motivoBloqueio,
          retryAfter: resposta.retryAfter,
        );
      }
      final String html = resposta.dados!;
      final bool? elegivel = extrairElegivel(html);
      if (elegivel == null) {
        _logger.w('Elegibilidade sem indicador no portal.');
      }
      return ResultadoConsultaAgendada(
        dados: <String, dynamic>{
          ...consulta,
          'sucesso': true,
          'elegivel': elegivel,
          'rotuloElegibilidade': extrairRotuloElegibilidade(html),
        },
      );
    }

    if (tipo == 'senha') {
      if (!_senhaValida(chave)) {
        return ResultadoConsultaAgendada(
          dados: _falhaItem(
            consulta,
            'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
          ),
        );
      }
      final ResultadoConsultaPortal<Map<String, dynamic>> resposta =
          await sessao.consultarSenha(senha: chave, cancelToken: cancelToken);
      if (!resposta.sucesso) {
        _contarFalhaConsulta(resposta);
        return ResultadoConsultaAgendada(
          dados: _falhaItem(
            consulta,
            _mensagemFalhaConsulta(resposta.categoria, resposta.status),
          ),
          retryable: resposta.retryable,
          falhaElegivelCircuito: resposta.falhaElegivelCircuito,
          motivoBloqueio: resposta.motivoBloqueio,
          retryAfter: resposta.retryAfter,
        );
      }
      return ResultadoConsultaAgendada(
        dados: <String, dynamic>{
          ...consulta,
          'sucesso': true,
          'statusSenha': _extrairStatusSenha(resposta.dados!),
        },
      );
    }

    return ResultadoConsultaAgendada(
      dados: _falhaItem(consulta, 'Tipo de consulta desconhecido.'),
    );
  }

  ResultadoConsultaAgendada _mapearFalhaSessaoLote(
    Map<String, dynamic> consulta,
    ResultadoLogin login,
  ) {
    final int status = _statusFalhaLogin(login);
    _contarFalhaUpstream(status);
    return ResultadoConsultaAgendada(
      dados: _falhaItem(consulta, _mensagemFalhaLogin(status)),
      retryable: login.falhaElegivelCircuito,
      falhaElegivelCircuito: login.falhaElegivelCircuito,
      motivoBloqueio: login.motivoBloqueio,
      retryAfter: login.retryAfter,
    );
  }

  Map<String, dynamic>? _validarFormatoConsulta(Map<String, dynamic> consulta) {
    final String tipo = consulta['tipo'] as String;
    final String chave = consulta['chave'] as String;
    if (tipo == 'elegibilidade') {
      if (!_carteiraValida(chave)) {
        return _falhaItem(
          consulta,
          'Carteira deve conter exatamente 20 digitos.',
        );
      }
      return null;
    }
    if (tipo == 'senha') {
      if (!_senhaValida(chave)) {
        return _falhaItem(
          consulta,
          'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
        );
      }
      return null;
    }
    return _falhaItem(consulta, 'Tipo de consulta desconhecido.');
  }

  Map<String, dynamic> _falhaItem(
    Map<String, dynamic> consulta,
    String mensagem,
  ) => <String, dynamic>{...consulta, 'sucesso': false, 'erro': mensagem};

  String _mensagemFalhaConsulta(
    CategoriaFalhaConsultaPortal? categoria,
    int? status,
  ) => switch (categoria) {
    CategoriaFalhaConsultaPortal.sessao => 'Sessao do portal indisponivel.',
    CategoriaFalhaConsultaPortal.transporte =>
      'Falha de rede ao acessar o portal SulAmerica.',
    CategoriaFalhaConsultaPortal.cancelada => 'Consulta cancelada.',
    CategoriaFalhaConsultaPortal.http =>
      status == null
          ? 'Falha na consulta ao portal SulAmerica.'
          : 'Falha na consulta ao portal SulAmerica (HTTP $status).',
    CategoriaFalhaConsultaPortal.respostaInesperada ||
    null => 'Resposta inesperada do portal SulAmerica.',
  };

  String? _extrairStatusSenha(Map<String, dynamic> dados) {
    final dynamic registros = dados['registros'];
    if (registros is! List || registros.isEmpty) return null;
    for (final dynamic registro in registros) {
      final dynamic status = registro is Map
          ? registro['status_solicitacao']
          : null;
      final dynamic descricao = status is Map ? status['descricao'] : null;
      if (descricao is String && descricao.isNotEmpty) return descricao;
    }
    return null;
  }

  Future<Response> _status(Request request) async {
    final bool estavaBloqueado = _disjuntor.estaBloqueado;
    await _disjuntor.verificarRecuperacao();
    final bool recuperou = estavaBloqueado && !_disjuntor.estaBloqueado;
    final Map<String, dynamic> alcancePortal;
    if (_disjuntor.estaBloqueado) {
      alcancePortal = <String, dynamic>{'alcançavel': false};
    } else if (recuperou) {
      final int? status = _disjuntor.statusUltimaSonda;
      alcancePortal = <String, dynamic>{
        'alcançavel': status != null && status < 500 && status != 429,
        if (status != null) 'status': status,
      };
    } else {
      alcancePortal = await _alcancePortal();
    }
    return respostaJson(<String, dynamic>{
      'status': 'ok',
      'portalSulAmerica': alcancePortal,
      'bloqueio': _disjuntor.bloqueio,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> _alcancePortal() {
    final DateTime agora = DateTime.now();
    final Map<String, dynamic>? cache = _alcanceCacheado;
    final DateTime? coletadoEm = _alcanceColetadoEm;
    if (cache != null &&
        coletadoEm != null &&
        agora.difference(coletadoEm) < _ttlCacheAlcance) {
      return Future<Map<String, dynamic>>.value(cache);
    }
    final Future<Map<String, dynamic>>? emAndamento = _sondaEmAndamento;
    if (emAndamento != null) return emAndamento;
    final Future<Map<String, dynamic>> sonda = _testarAlcancePortal();
    _sondaEmAndamento = sonda;
    return sonda.whenComplete(() {
      if (identical(_sondaEmAndamento, sonda)) _sondaEmAndamento = null;
      _alcanceColetadoEm = DateTime.now();
    });
  }

  Future<Map<String, dynamic>> _testarAlcancePortal() async {
    try {
      final int status = await _sondaPortal().timeout(_janelaCacheAlcance);
      final Map<String, dynamic> resultado = <String, dynamic>{
        'alcançavel': true,
        'status': status,
      };
      _alcanceCacheado = resultado;
      return resultado;
    } on Exception catch (erro) {
      _logger.w('Teste de alcance do portal falhou: ${erro.runtimeType}.');
      final Map<String, dynamic> resultado = <String, dynamic>{
        'alcançavel': false,
      };
      _alcanceCacheado = resultado;
      return resultado;
    }
  }

  static Future<int> _sondarPortalPadrao() async {
    final HttpClient http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest requisicao = await http
          .getUrl(Uri.parse('https://saude.sulamericaseguros.com.br/'))
          .timeout(const Duration(seconds: 10));
      final HttpClientResponse resposta = await requisicao.close().timeout(
        const Duration(seconds: 10),
      );
      return resposta.statusCode;
    } finally {
      http.close(force: true);
    }
  }

  static Future<ResultadoSondaDisjuntor> _sondarPortalDisjuntorPadrao() async {
    final HttpClient http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest requisicao = await http
          .getUrl(Uri.parse('https://saude.sulamericaseguros.com.br/'))
          .timeout(const Duration(seconds: 10));
      final HttpClientResponse resposta = await requisicao.close().timeout(
        const Duration(seconds: 10),
      );
      final List<int> corpo = await _lerCorpoSonda(resposta)
          .timeout(const Duration(seconds: 10));
      final assinatura =
          ColetorAssinaturasRespostaPortal().coletar(
            status: resposta.statusCode,
            contentType: resposta.headers.contentType?.mimeType,
            body: corpo,
          );
      return ResultadoSondaDisjuntor(
        status: resposta.statusCode,
        rejeicaoF5: assinatura.f5Rejected,
        retryAfter: _retryAfterPortal(resposta.headers.value('retry-after')),
        respostaInesperada: resposta.statusCode == 302 &&
            resposta.headers.value('location') == null,
      );
    } on Exception {
      return const ResultadoSondaDisjuntor(status: null, falhaTransporte: true);
    } finally {
      http.close(force: true);
    }
  }

  static Future<List<int>> _lerCorpoSonda(HttpClientResponse resposta) async {
    const int limiteBytes = 65536;
    final List<int> corpo = <int>[];
    await for (final List<int> parte in resposta) {
      corpo.addAll(parte.take(limiteBytes - corpo.length));
      if (corpo.length >= limiteBytes) break;
    }

    return corpo;
  }

  static Duration? _retryAfterPortal(String? valor) {
    final int? segundos = int.tryParse(valor?.trim() ?? '');
    return segundos == null || segundos < 0
        ? null
        : Duration(seconds: segundos);
  }

  Response _erroCorpoGrande() => respostaErro(
    'Corpo excede o limite de ${_maxBytesCorpo ~/ (1 << 20)} MB.',
    413,
  );

  Response _respostaDisjuntorAberto() => respostaErro(
    _disjuntor.bloqueio['mensagem'] as String? ??
        'Portal SulAmerica temporariamente indisponivel.',
    503,
    headers: cabecalhosRetryAfter(
      _disjuntor.retryAfterSegundos == 0 ? 1 : _disjuntor.retryAfterSegundos,
    ),
    dadosAdicionais: <String, dynamic>{'bloqueio': _disjuntor.bloqueio},
  );

  List<Map<String, dynamic>>? _validarConsultas(Object? valor) {
    if (valor is! List || valor.isEmpty) return null;
    if (valor.length > _maxItensPorLote) return null;
    final List<Map<String, dynamic>> resultado = <Map<String, dynamic>>[];
    for (final Object? item in valor) {
      if (item is! Map ||
          item['tipo'] is! String ||
          (item['tipo'] as String).isEmpty ||
          item['chave'] is! String ||
          (item['chave'] as String).isEmpty) {
        return null;
      }
      resultado.add(<String, dynamic>{
        'tipo': item['tipo'],
        'chave': item['chave'],
      });
    }
    return resultado;
  }

  Response _naoEncontrado(Request request, String ignorado) =>
      respostaErro('Rota nao encontrada.', 404);

  int _statusFalhaLogin(ResultadoLogin resultado) => switch (resultado.motivo) {
    MotivoFalhaLogin.credenciaisInvalidas => 401,
    MotivoFalhaLogin.falhaRede => 503,
    MotivoFalhaLogin.respostaInesperada => 502,
    MotivoFalhaLogin.falhaInterna || null => 500,
  };

  String _mensagemFalhaLogin(int status) => switch (status) {
    401 => 'Credenciais invalidas para o portal SulAmerica.',
    502 => 'O portal SulAmerica respondeu de forma inesperada.',
    503 => 'Falha de rede ao acessar o portal SulAmerica.',
    _ => 'Falha interna do backend.',
  };

  void _contarFalhaUpstream(int? status) {
    if (status == 502) _falhas502++;
    if (status == 503) _falhas503++;
  }

  void _contarFalhaConsulta<T>(ResultadoConsultaPortal<T> resultado) {
    final String categoria = resultado.categoria?.name ?? 'semCategoria';
    final String status = resultado.status?.toString() ?? 'semStatus';
    _falhasConsulta.update(
      '${categoria}_$status',
      (int valor) => valor + 1,
      ifAbsent: () => 1,
    );
    if (resultado.categoria == CategoriaFalhaConsultaPortal.transporte) {
      _falhas503++;
      return;
    }
    _contarFalhaUpstream(resultado.status);
  }

  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  static bool _senhaValida(String senha) =>
      senha.length == 10 && senha.startsWith('5');

  Middleware _exporRetryAfterCors() => (Handler inner) {
    return (Request request) async {
      final Response resposta = await inner(request);
      return resposta.change(
        headers: const <String, String>{
          'access-control-expose-headers': 'Location, Retry-After',
        },
      );
    };
  };
}

class _StreamAtivo {
  _StreamAtivo(this._aoFechar) {
    _controlador.onCancel = () => unawaited(fechar());
  }

  final void Function() _aoFechar;
  final StreamController<List<int>> _controlador =
      StreamController<List<int>>();
  StreamSubscription<List<int>>? _assinatura;
  bool _fechado = false;

  Stream<List<int>> get stream => _controlador.stream;

  void conectar(Stream<List<int>> origem) {
    _assinatura = origem.listen(
      _controlador.add,
      onError: _controlador.addError,
      onDone: () => unawaited(fechar()),
    );
  }

  Future<void> fechar() async {
    if (_fechado) return;
    _fechado = true;
    await _assinatura?.cancel();
    await _controlador.close();
    _aoFechar();
  }
}
