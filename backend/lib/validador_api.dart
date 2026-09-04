import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'elegibilidade_parser.dart';
import 'sessao_portal.dart';
import 'util_texto.dart';

class ValidadorApi {
  ValidadorApi({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<String, SessaoPortal> _sessoes = {};
  final Map<String, _CredenciaisPortal> _credenciaisPorToken = {};
  final Random _aleatorio = Random.secure();
  static const int _limiteSessoes = 10;

  bool _loteEmAndamento = false;

  /// Teto de itens por lote e de bytes de corpo (proteção contra abuso do
  /// proxy aberto — cada item gera chamada real ao portal SulAmerica).
  static const int _maxItensPorLote = 300;
  static const int _maxBytesCorpo = 1 << 20; // 1 MB

  /// Rate limit por IP nas rotas que tocam o portal (evita varredura e
  /// bloqueio do F5 ASM em uso concorrente).
  static const Set<String> _rotasDePortal = {
    'api/login',
    'api/beneficiario',
    'api/autorizacao',
    'api/consultas',
  };
  static const int _maxRateLimitPorJanela = 40;
  static const Duration _janelaRateLimit = Duration(minutes: 1);

  late final Router _rotas = Router()
    ..post('/api/login', _login)
    ..post('/api/beneficiario', _beneficiario)
    ..get('/api/autorizacao', _autorizacao)
    ..post('/api/consultas', _consultas)
    ..get('/api/status', _status)
    ..all('/<ignored|.*>', _naoEncontrado);

  Handler get handler => const Pipeline()
      .addMiddleware(ValidadorApi._cors())
      .addMiddleware(ValidadorApi._rateLimitPortal())
      .addHandler(_rotas.call);


  Future<Response> _login(Request request) async {
    final _LeituraJson leitura = await _lerJson(request);
    if (leitura.excedeLimite) return _erroCorpoGrande();
    final Map<String, dynamic>? corpo = leitura.valor;
    if (corpo == null) {
      return _erro('Corpo JSON invalido.', 400);
    }

    final String? code = corpo['code'] as String?;
    final String? user = corpo['user'] as String?;
    final String? senha = corpo['senha'] as String?;
    if (code == null ||
        code.isEmpty ||
        user == null ||
        user.isEmpty ||
        senha == null ||
        senha.isEmpty) {
      return _erro('Campos code, user e senha sao obrigatorios.', 400);
    }

    final SessaoPortal sessao = SessaoPortal(logger: _logger);
    final ResultadoLogin resultado = await sessao.login(
      code: code,
      user: user,
      senha: senha,
    );
    if (!resultado.autenticada) {
      final String mensagem = switch (resultado.motivo) {
        MotivoFalhaLogin.credenciaisInvalidas =>
          'Credenciais invalidas para o portal SulAmerica. '
          'Confira PORTAL_CODE, PORTAL_USER e PORTAL_SENHA.',
        MotivoFalhaLogin.falhaRede =>
          'Falha de rede ao acessar o portal SulAmerica. '
          'Detalhe: ${resultado.detalhe ?? 'sem detalhe'}.',
        MotivoFalhaLogin.respostaInesperada || null =>
          'O portal SulAmerica respondeu de forma inesperada '
          '(possivel bloqueio do F5 ASM).',
      };
      _logger.w('Login recusado: $mensagem');
      return _erro(mensagem, 401);
    }

    final String token = _novoToken(sessao);
    // Retém as credenciais apenas para abrir sessões extras (logins), em
    // memória, e as remove junto com a sessão.
    _credenciaisPorToken[token] = _CredenciaisPortal(
      code: code,
      user: user,
      senha: senha,
    );
    _logger.i('Sessao criada para o prestador code=$code (mascarado).');
    return _json({'token': token, 'autenticada': true});
  }

  Future<Response> _beneficiario(Request request) async {
    final _LeituraJson leitura = await _lerJson(request);
    if (leitura.excedeLimite) return _erroCorpoGrande();
    final Map<String, dynamic>? corpo = leitura.valor;
    if (corpo == null) {
      return _erro('Corpo JSON invalido.', 400);
    }

    final SessaoPortal? sessao = _sessaoPorCorpo(corpo);
    if (sessao == null) {
      return _erro('Token de sessao invalido ou ausente.', 401);
    }

    final String? carteira = corpo['carteira'] as String?;
    if (carteira == null || carteira.isEmpty) {
      return _erro('Campo carteira e obrigatorio.', 400);
    }
    if (!_carteiraValida(carteira)) {
      return _erro(
        'Carteira deve conter exatamente 20 digitos '
        '(segmentos 3-5-4-4-4).',
        400,
      );
    }

    final String? html = await sessao.consultarBeneficiario(
      carteirinhaCompleta: carteira,
    );
    if (html == null) {
      return _erro('Falha na consulta ao portal SulAmerica.', 502);
    }

    return _json({
      'status': 'ok',
      // Elegibilidade extraída do elegibilidade-resultado.htm (SIM/NÃO);
      // null quando o portal não renderiza o resultado (carteira não
      // encontrada). O html original não é devolvido ao cliente: só o
      // indicador importa e reduz o payload da rede.
      'elegivel': extrairElegivel(html),
      'rotuloElegibilidade': extrairRotuloElegibilidade(html),
    });
  }

  Future<Response> _autorizacao(Request request) async {
    final String? token = request.url.queryParameters['token'];
    final String? numeroVpp = request.url.queryParameters['numeroVpp'];
    final SessaoPortal? sessao = token == null ? null : _sessoes[token];

    if (sessao == null) {
      return _erro('Token de sessao invalido ou ausente.', 401);
    }
    if (numeroVpp == null || numeroVpp.isEmpty) {
      return _erro('Parametro numeroVpp e obrigatorio.', 400);
    }
    if (!_senhaValidaParaVpp(numeroVpp)) {
      return _erro(
        'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
        400,
      );
    }

    final Map<String, dynamic>? dados = await sessao
        .consultarAutorizacaoVpp(numeroVpp: numeroVpp);
    if (dados == null) {
      return _erro('Falha na consulta de autorizacao VPP.', 502);
    }

    // Resposta compacta: o cliente só precisa saber se há autorização e a
    // descricao do status — o JSON cru do portal não é devolvido.
    final String? descricao = _extrairStatusVpp(dados);
    return _json({
      'status': 'ok',
      'encontrada': descricao != null,
      'descricao': descricao,
    });
  }

  /// Consulta em lote: recebe várias solicitações (elegibilidade/vpp) e
  /// executa contra o portal com paralelismo controlado, devolvendo cada
  /// resultado na ordem da requisição — o cliente faz uma única chamada HTTP.
  Future<Response> _consultas(Request request) async {
    final _LeituraJson leitura = await _lerJson(request);
    if (leitura.excedeLimite) return _erroCorpoGrande();
    final Map<String, dynamic>? corpo = leitura.valor;
    if (corpo == null) return _erro('Corpo JSON invalido.', 400);

    final SessaoPortal? sessao = _sessaoPorCorpo(corpo);
    if (sessao == null) {
      return _erro('Token de sessao invalido ou ausente.', 401);
    }
    final String? token = corpo['token'] as String?;

    final dynamic consultas = corpo['consultas'];
    if (consultas is! List || consultas.isEmpty) {
      return _erro('Campo consultas e obrigatorio.', 400);
    }
    if (consultas.length > _maxItensPorLote) {
      return _erro(
        'Lote excede o limite de $_maxItensPorLote itens por requisicao.',
        413,
      );
    }
    if (_loteEmAndamento) {
      return _erro('Ja existe um lote em andamento. Aguarde.', 429);
    }

    _loteEmAndamento = true;
    List<Map<String, dynamic>> resultados;
    try {
      resultados = await _executarConsultas(
        sessaoBase: sessao,
        credenciais: token == null ? null : _credenciaisPorToken[token],
        consultas: consultas,
      );
    } finally {
      _loteEmAndamento = false;
    }

    // Reordena para a ordem da requisição original.
    final Map<String, Map<String, dynamic>> porChave = {
      for (final Map<String, dynamic> r in resultados)
        '${r['tipo']}|${r['chave']}': r,
    };
    return _json({
      'status': 'ok',
      'resultados': [
        for (final dynamic c in consultas)
          porChave['${(c as Map)['tipo']}|${c['chave']}'],
      ],
    });
  }

  /// Nº máximo de sessões do portal usadas em paralelo num lote (1 por lote
  /// pequeno + extras via login quando há muitas elegibilidades).
  static const int _limiteSessoesParalelas = 10;

  /// A partir deste volume de elegibilidades vale criar sessões extras.
  static const int _minElegibilidadeParaMultiplasSessoes = 10;

  /// Teto de consultas VPP simultâneas POR SESSÃO (GET sem estado de form,
  /// leve). Distribuir também os VPPs entre as sessões evita concentrar os
  /// 100 VPPs na sessão base.
  static const int _limiteVppPorSessao = 3;

  /// Executa as consultas: elegibilidade é sempre serial POR SESSÃO (o form
  /// do portal tem estado); com muitas carteiras abre sessões extras (logins
  /// em paralelo) e divide elegibilidade e VPPs entre todas as sessões.
  Future<List<Map<String, dynamic>>> _executarConsultas({
    required SessaoPortal sessaoBase,
    required _CredenciaisPortal? credenciais,
    required List<dynamic> consultas,
  }) async {
    final List<dynamic> elegibilidades = [
      for (final dynamic c in consultas)
        if ((c as Map)['tipo'] == 'elegibilidade') c,
    ];
    final List<dynamic> vpps = [
      for (final dynamic c in consultas)
        if ((c as Map)['tipo'] != 'elegibilidade') c,
    ];

    // Reúne as sessões (base + extras autenticadas) com logins EM PARALELO.
    final List<SessaoPortal> sessoes = [sessaoBase];
    if (credenciais != null &&
        elegibilidades.length >= _minElegibilidadeParaMultiplasSessoes) {
      final int extras =
          min(_limiteSessoesParalelas - 1, elegibilidades.length - 1);
      final List<Future<SessaoPortal?>> futuros = [
        for (int i = 0; i < extras; i++) _criarSessaoExtra(credenciais, i),
      ];
      for (final SessaoPortal? extra in await Future.wait(futuros)) {
        if (extra != null) sessoes.add(extra);
      }
    }

    // Distribui elegibilidades (serial por sessão) e VPPs (pool por sessão)
    // em round-robin por todas as sessões.
    final List<List<dynamic>> particoesEleg =
        List.generate(sessoes.length, (_) => <dynamic>[]);
    final List<List<dynamic>> particoesVpp =
        List.generate(sessoes.length, (_) => <dynamic>[]);
    for (int i = 0; i < elegibilidades.length; i++) {
      particoesEleg[i % sessoes.length].add(elegibilidades[i]);
    }
    for (int i = 0; i < vpps.length; i++) {
      particoesVpp[i % sessoes.length].add(vpps[i]);
    }

    final List<Future<List<Map<String, dynamic>>>> trabalhos = [];
    for (int i = 0; i < sessoes.length; i++) {
      trabalhos.add(
        _processarSessao(
          sessao: sessoes[i],
          fatiaElegibilidade: particoesEleg[i],
          fatiaVpps: particoesVpp[i],
        ),
      );
    }

    final List<Map<String, dynamic>> resultados = [];
    for (final List<Map<String, dynamic>> parte
        in await Future.wait(trabalhos)) {
      resultados.addAll(parte);
    }

    // Sessões extras são descartáveis: libera as conexões após o lote
    // (a base permanece para as próximas consultas do cliente).
    for (final SessaoPortal extra in sessoes.skip(1)) {
      await extra.encerrar();
    }
    return resultados;
  }

  Future<SessaoPortal?> _criarSessaoExtra(
    _CredenciaisPortal credenciais,
    int indice,
  ) async {
    final SessaoPortal nova = SessaoPortal(logger: _logger);
    final ResultadoLogin login = await nova.login(
      code: credenciais.code,
      user: credenciais.user,
      senha: credenciais.senha,
    );
    if (login.autenticada) return nova;
    _logger.w(
      'Sessao de elegibilidade extra ${indice + 1} nao autenticada '
      '(segue com as demais).',
    );
    return null;
  }

  /// Uma sessão: elegibilidade da fatia uma a uma (serial, preserva o form);
  /// os VPPs da fatia rodam em paralelo até [_limiteVppPorSessao].
  Future<List<Map<String, dynamic>>> _processarSessao({
    required SessaoPortal sessao,
    required List<dynamic> fatiaElegibilidade,
    required List<dynamic> fatiaVpps,
  }) async {
    final List<Map<String, dynamic>> resultados = [];
    for (final dynamic item in fatiaElegibilidade) {
      resultados.add(await _executarConsulta(sessao, item));
    }
    if (fatiaVpps.isNotEmpty) {
      resultados.addAll(
        await _processarEmParalelo(fatiaVpps, sessao, _limiteVppPorSessao),
      );
    }
    return resultados;
  }

  /// Pool de workers nativo (sem dependência): processa [consultas] com até
  /// [limite] requisições simultâneas, preservando a ordem dos resultados.
  Future<List<Map<String, dynamic>>> _processarEmParalelo(
    List<dynamic> consultas,
    SessaoPortal sessao,
    int limite,
  ) async {
    final List<Map<String, dynamic>?> resultados =
        List<Map<String, dynamic>?>.filled(consultas.length, null);
    int proximo = 0;

    Future<void> trabalhador() async {
      while (true) {
        final int indice = proximo++;
        if (indice >= consultas.length) return;
        resultados[indice] =
            await _executarConsulta(sessao, consultas[indice]);
      }
    }

    final int qtdTrabalhadores = min(limite, consultas.length);
    await Future.wait([
      for (int i = 0; i < qtdTrabalhadores; i++) trabalhador(),
    ]);
    return resultados.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> _executarConsulta(
    SessaoPortal sessao,
    dynamic item,
  ) async {
    final String? tipo = item is Map ? item['tipo'] as String? : null;
    final String? chave = item is Map ? item['chave'] as String? : null;
    if (chave == null || chave.isEmpty) {
      return {
        'chave': chave ?? '',
        'tipo': tipo ?? '',
        'sucesso': false,
        'erro': 'chave invalida.',
      };
    }

    if (tipo == 'elegibilidade') {
      if (!_carteiraValida(chave)) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro': 'Carteira deve conter exatamente 20 digitos.',
        };
      }
      final String? html = await sessao
          .consultarBeneficiario(carteirinhaCompleta: chave);
      if (html == null) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro': 'Falha na consulta ao portal SulAmerica.',
        };
      }
      final bool? elegivel = extrairElegivel(html);
      if (elegivel == null) {
        // Diagnóstico: o portal voltou sem o bloco de elegibilidade — pode
        // ser carteira realmente não encontrada OU estado de sessão perdido.
        _logger.w(
          'Elegibilidade sem indicador | carteira ${_mascararChave(chave)} | '
          'pagina: ${
              resumirTexto(html.replaceAll(RegExp(r'<[^>]*>'), ' '))}',
        );
      }
      return {
        'chave': chave,
        'tipo': tipo,
        'sucesso': true,
        'elegivel': elegivel,
        'rotuloElegibilidade': extrairRotuloElegibilidade(html),
      };
    }

    if (tipo == 'autorizacaoVpp') {
      if (!_senhaValidaParaVpp(chave)) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro': 'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
        };
      }
      final Map<String, dynamic>? dados = await sessao
          .consultarAutorizacaoVpp(numeroVpp: chave);
      if (dados == null) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro': 'Falha na consulta de autorizacao VPP.',
        };
      }
      return {
        'chave': chave,
        'tipo': tipo,
        'sucesso': true,
        'statusVpp': _extrairStatusVpp(dados),
      };
    }

    return {
      'chave': chave,
      'tipo': tipo ?? '',
      'sucesso': false,
      'erro': 'Tipo de consulta desconhecido.',
    };
  }

  /// "primeiro.ultimo" da chave (não vaza dados sensíveis em log).
  String _mascararChave(String chave) => chave.length <= 5
      ? chave
      : '${chave.substring(0, 4)}…${chave.substring(chave.length - 2)}';

  /// Descricao do status da autorização (ex.: "Autorizado", "Negado") a
  /// partir do JSON do portal; null quando não há registro com status.
  String? _extrairStatusVpp(Map<String, dynamic> dados) {
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
    final Map<String, dynamic> alcancePortal = await _testarAlcancePortal();
    return _json({
      'status': 'ok',
      'sessoesAtivas': _sessoes.length,
      'portalSulAmerica': alcancePortal,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// GET simples (sem headers de navegador) ao portal para saber se o
  /// servidor consegue abrir conexão com ele — distingue bloqueio de rede
  /// (F5 ASM / datacenter) de falha de autenticação.
  Future<Map<String, dynamic>> _testarAlcancePortal() async {
    final HttpClient http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = SessaoPortal.aceitarCertificadoDoPortal;
    try {
      final HttpClientRequest requisicao = await http
          .getUrl(Uri.parse('https://saude.sulamericaseguros.com.br/'))
          .timeout(const Duration(seconds: 10));
      final HttpClientResponse resposta = await requisicao
          .close()
          .timeout(const Duration(seconds: 10));
      return {
        'alcançavel': true,
        'status': resposta.statusCode,
      };
    } catch (erro) {
      return {
        'alcançavel': false,
        'detalhe': erro.toString(),
      };
    } finally {
      http.close(force: true);
    }
  }

  Response _naoEncontrado(Request request, String ignorado) {
    return _erro('Rota nao encontrada.', 404);
  }


  String _novoToken(SessaoPortal sessao) {
    if (_sessoes.length >= _limiteSessoes) {
      final String antiga = _sessoes.keys.first;
      _sessoes.remove(antiga);
      _credenciaisPorToken.remove(antiga);
    }
    final String token = _gerarToken();
    _sessoes[token] = sessao;
    return token;
  }

  String _gerarToken() {
    final List<int> bytes = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  SessaoPortal? _sessaoPorCorpo(Map<String, dynamic> corpo) {
    final String? token = corpo['token'] as String?;
    return token == null ? null : _sessoes[token];
  }


  /// Fonte única das regras de formato: carteira com exatamente 20 dígitos e
  /// senha VPP com exatamente 10 dígitos começando com 5 (mesmas do app).
  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  static bool _senhaValidaParaVpp(String senha) =>
      senha.length == 10 && senha.startsWith('5');

  Future<_LeituraJson> _lerJson(Request request) async {
    final int? informado = request.contentLength;
    if (informado != null && informado > _maxBytesCorpo) {
      return const _LeituraJson(null, excedeLimite: true);
    }
    try {
      final BytesBuilder acumulador = BytesBuilder(copy: false);
      await for (final List<int> parte in request.read()) {
        acumulador.add(parte);
        if (acumulador.length > _maxBytesCorpo) {
          return const _LeituraJson(null, excedeLimite: true);
        }
      }
      final String corpo =
          utf8.decode(acumulador.takeBytes(), allowMalformed: true);
      if (corpo.trim().isEmpty) return const _LeituraJson(null);
      return _LeituraJson(jsonDecode(corpo) as Map<String, dynamic>);
    } catch (_) {
      return const _LeituraJson(null);
    }
  }

  Response _erroCorpoGrande() =>
      _erro('Corpo excede o limite de ${_maxBytesCorpo ~/ (1 << 20)} MB.', 413);

  static Middleware _rateLimitPortal() {
    final Map<String, List<DateTime>> acessos = {};
    return (Handler inner) => (Request request) async {
          if (!_rotasDePortal.contains(request.url.path)) {
            return inner(request);
          }
          final String ip = _ipDe(request);
          final DateTime agora = DateTime.now();
          final List<DateTime> recentes = (acessos[ip] ?? const [])
              .where((t) => agora.difference(t) < _janelaRateLimit)
              .toList();
          if (recentes.length >= _maxRateLimitPorJanela) {
            return Response(
              429,
              body: jsonEncode({
                'status': 'erro',
                'mensagem': 'Muitas requisicoes. Aguarde um instante.',
              }),
              headers: const {'content-type': 'application/json; charset=utf-8'},
            );
          }
          recentes.add(agora);
          acessos[ip] = recentes;
          return inner(request);
        };
  }

  static String _ipDe(Request request) {
    final String? forward = request.headers['x-forwarded-for'];
    if (forward != null && forward.isNotEmpty) {
      return forward.split(',').first.trim();
    }
    final dynamic info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) return info.remoteAddress.address;
    return 'desconhecido';
  }

  Response _json(Map<String, dynamic> dados, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(dados),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Response _erro(String mensagem, int statusCode) {
    return _json({'status': 'erro', 'mensagem': mensagem}, statusCode: statusCode);
  }

  static Middleware _cors() {
    // Lida em runtime (Platform.environment) para permitir configurar via
    // `fly secrets set CORS_ORIGIN=...`; default aberto pois o token vai no
    // corpo/query (sem cookie cross-origin).
    const String origemPadrao = '*';
    return (Handler inner) {
      final String origemPermitida =
          Platform.environment['CORS_ORIGIN'] ?? origemPadrao;
      return (Request request) async {
        final Map<String, String> headers = {
          'Access-Control-Allow-Origin': origemPermitida,
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        };
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: headers);
        }
        final Response resposta = await inner(request);
        return resposta.change(headers: headers);
      };
    };
  }
}

/// Resultado da leitura do corpo JSON: [valor] nulo quando vazio/parsing
/// falhou; [excedeLimite] distingue o corpo acima de [_maxBytesCorpo]
/// (413) do corpo malformado (400).
class _LeituraJson {
  const _LeituraJson(this.valor, {this.excedeLimite = false});

  final Map<String, dynamic>? valor;
  final bool excedeLimite;
}

/// Credenciais do prestador retidas em memória por token de sessão, usadas
/// apenas para abrir sessões extras (paralelas) quando um lote tem muitas
/// elegibilidades. Nunca são logadas e saem quando a sessão é removida.
class _CredenciaisPortal {
  const _CredenciaisPortal({
    required this.code,
    required this.user,
    required this.senha,
  });

  final String code;
  final String user;
  final String senha;
}
