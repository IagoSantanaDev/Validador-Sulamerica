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
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
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
    Duration janelaCacheAlcance = const Duration(seconds: 10),
    RepositorioSessoes? repositorio,
    RateLimit? rateLimit,
    int limiteSessoesLogicas = 200,
    int limiteRequisicoesPorChave = 20,
    int limiteRequisicoesGlobal = 120,
    int limiteExecucoes = 24,
  })  : _logger = logger ?? Logger(),
        _ambiente = ambiente,
        _janelaCacheAlcance = janelaCacheAlcance,
        _sondaPortal = sondaPortal ?? _sondarPortalPadrao,
        _repositorio =
            repositorio ?? RepositorioSessoes(limite: limiteSessoesLogicas),
        _rateLimit = rateLimit ??
            RateLimit(
              limitePorChave: limiteRequisicoesPorChave,
              limiteGlobal: limiteRequisicoesGlobal,
            ) {
    _pool = PoolSessoesPortal(logger: _logger, fabricaSessao: fabricaSessao);
    _agendador = AgendadorLotes(
      pool: _pool,
      limiteExecucoes: limiteExecucoes,
      executarConsulta: _executarConsultaPortal,
      validarConsulta: _validarFormatoConsulta,
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

  static const int _maxItensPorLote = 300;
  static const int _maxBytesCorpo = 1 << 20;
  static const Duration _ttlCacheAlcance = Duration(seconds: 10);

  int _rejeicoes429 = 0;
  int _falhas502 = 0;
  int _falhas503 = 0;
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

    final ResultadoRateLimit limite = _rateLimit.consumirPrestador(
      identificador,
    );
    if (!limite.permitido) {
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
      _rejeicoes429++;
      return respostaErro('Limite de sessoes ativas atingido.', 429);
    }

    try {
      await _pool.garantirAutenticada(identificador, credenciais);
    } on FalhaPoolSessoesException catch (erro) {
      _repositorio.remover(sessaoLogica.token);
      final int status = _statusFalhaLogin(erro.resultado);
      _contarFalhaUpstream(status);
      _logger.w('Criacao de sessao rejeitada: falha no login do portal.');
      return respostaErro(_mensagemFalhaLogin(status), status);
    } on Exception {
      _repositorio.remover(sessaoLogica.token);
      _logger.e('Falha interna ao criar sessao logica.');
      return respostaErro(_mensagemFalhaLogin(500), 500);
    }

    return respostaJson(
      <String, dynamic>{
        'token': sessaoLogica.token,
        'identificadorPrestador': identificador,
      },
      status: 201,
    );
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

    final ResultadoRateLimit limite = _rateLimit.consumirToken(token);
    if (!limite.permitido) {
      _rejeicoes429++;
      return respostaErro(
        'Muitas requisicoes. Aguarde um instante.',
        429,
        headers: cabecalhosRetryAfter(limite.retryAfterSegundos),
      );
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
        headers: cabecalhosRetryAfter(10),
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

    final String? desdeTexto = request.url.queryParameters['desde'] ??
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

  Future<Map<String, dynamic>> _executarConsultaPortal(
    SessaoPortal sessao,
    Map<String, dynamic> consulta,
    CancelToken cancelToken,
  ) async {
    final String tipo = consulta['tipo'] as String;
    final String chave = consulta['chave'] as String;
    if (tipo == 'elegibilidade') {
      if (!_carteiraValida(chave)) {
        return _falhaItem(
          consulta,
          'Carteira deve conter exatamente 20 digitos.',
        );
      }
      final ResultadoConsultaPortal<String> resposta =
          await sessao.consultarBeneficiario(
        carteirinhaCompleta: chave,
        cancelToken: cancelToken,
      );
      if (!resposta.sucesso) {
        _contarFalhaConsulta(resposta);
        return _falhaItem(consulta, _mensagemFalhaConsulta(resposta.categoria));
      }
      final String html = resposta.dados!;
      final bool? elegivel = extrairElegivel(html);
      if (elegivel == null) {
        _logger.w('Elegibilidade sem indicador no portal.');
      }
      return <String, dynamic>{
        ...consulta,
        'sucesso': true,
        'elegivel': elegivel,
        'rotuloElegibilidade': extrairRotuloElegibilidade(html),
      };
    }

    if (tipo == 'senha') {
      if (!_senhaValida(chave)) {
        return _falhaItem(
          consulta,
          'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
        );
      }
      final ResultadoConsultaPortal<Map<String, dynamic>> resposta =
          await sessao.consultarSenha(senha: chave, cancelToken: cancelToken);
      if (!resposta.sucesso) {
        _contarFalhaConsulta(resposta);
        return _falhaItem(consulta, _mensagemFalhaConsulta(resposta.categoria));
      }
      return <String, dynamic>{
        ...consulta,
        'sucesso': true,
        'statusSenha': _extrairStatusSenha(resposta.dados!),
      };
    }

    return _falhaItem(consulta, 'Tipo de consulta desconhecido.');
  }

  Map<String, dynamic>? _validarFormatoConsulta(
    Map<String, dynamic> consulta,
  ) {
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
  ) =>
      <String, dynamic>{...consulta, 'sucesso': false, 'erro': mensagem};

  String _mensagemFalhaConsulta(CategoriaFalhaConsultaPortal? categoria) =>
      switch (categoria) {
        CategoriaFalhaConsultaPortal.sessao => 'Sessao do portal indisponivel.',
        CategoriaFalhaConsultaPortal.transporte =>
          'Falha de rede ao acessar o portal SulAmerica.',
        CategoriaFalhaConsultaPortal.cancelada => 'Consulta cancelada.',
        CategoriaFalhaConsultaPortal.http =>
          'Falha na consulta ao portal SulAmerica.',
        CategoriaFalhaConsultaPortal.respostaInesperada ||
        null =>
          'Resposta inesperada do portal SulAmerica.',
      };

  String? _extrairStatusSenha(Map<String, dynamic> dados) {
    final dynamic registros = dados['registros'];
    if (registros is! List || registros.isEmpty) return null;
    for (final dynamic registro in registros) {
      final dynamic status =
          registro is Map ? registro['status_solicitacao'] : null;
      final dynamic descricao = status is Map ? status['descricao'] : null;
      if (descricao is String && descricao.isNotEmpty) return descricao;
    }
    return null;
  }

  Future<Response> _status(Request request) async {
    final Map<String, dynamic> alcancePortal = await _alcancePortal();
    return respostaJson(<String, dynamic>{
      'status': 'ok',
      'sessoesAtivas': _pool.sessoesAtivas,
      'lotes': <String, int>{
        'ativos': _agendador.ativas,
        'naFila': _agendador.naFila,
        'concluidos': _agendador.concluidos,
      },
      'memoriaRssMb': (ProcessInfo.currentRss / (1024 * 1024)).round(),
      'rateLimit': <String, int>{'rejeicoes429': _rejeicoes429},
      'falhasPortal': <String, int>{'502': _falhas502, '503': _falhas503},
      'portalSulAmerica': alcancePortal,
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

  Response _erroCorpoGrande() => respostaErro(
        'Corpo excede o limite de ${_maxBytesCorpo ~/ (1 << 20)} MB.',
        413,
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
