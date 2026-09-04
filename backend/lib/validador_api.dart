import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'elegibilidade_parser.dart';
import 'sessao_portal.dart';

class ValidadorApi {
  ValidadorApi({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<String, SessaoPortal> _sessoes = {};
  final Map<String, _CredenciaisPortal> _credenciaisPorToken = {};
  final Random _aleatorio = Random.secure();
  static const int _limiteSessoes = 10;

  late final Router _rotas = Router()
    ..post('/api/login', _login)
    ..post('/api/beneficiario', _beneficiario)
    ..get('/api/autorizacao', _autorizacao)
    ..post('/api/consultas', _consultas)
    ..get('/api/status', _status)
    ..all('/<ignored|.*>', _naoEncontrado);

  Handler get handler => const Pipeline()
      .addMiddleware(ValidadorApi._cors())
      .addHandler(_rotas.call);


  Future<Response> _login(Request request) async {
    final Map<String, dynamic>? corpo = await _lerJson(request);
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
    // Retém apenas para abrir sessões extras (logins paralelos) em lotes
    // grandes de elegibilidade; vive só em memória e sai junto com a sessão.
    _credenciaisPorToken[token] = _CredenciaisPortal(
      code: code,
      user: user,
      senha: senha,
    );
    _logger.i('Sessao criada para o prestador code=$code (mascarado).');
    return _json({'token': token, 'autenticada': true});
  }

  Future<Response> _beneficiario(Request request) async {
    final Map<String, dynamic>? corpo = await _lerJson(request);
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
    if (carteira.length != 20 || !RegExp(r'^\d+$').hasMatch(carteira)) {
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
    final Map<String, dynamic>? corpo = await _lerJson(request);
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

    final List<Map<String, dynamic>> resultados = await _executarConsultas(
      sessaoBase: sessao,
      credenciais: token == null ? null : _credenciaisPorToken[token],
      consultas: consultas,
    );

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
  static const int _limiteSessoesParalelas = 4;

  /// A partir deste volume de elegibilidades vale criar sessões extras.
  static const int _minElegibilidadeParaMultiplasSessoes = 10;

  /// Teto de requisições simultâneas ao portal dentro de uma sessão
  /// (aplicado ao VPP, que é um GET sem estado de form).
  static const int _limiteConcorrencia = 10;

  /// Executa as consultas: elegibilidade é sempre serial POR SESSÃO (o form
  /// do portal tem estado); quando há muitas carteiras, abre sessões extras
  /// (logins) e divide a fila entre elas — só a elegibilidade, o VPP fica
  /// paralelo na sessão base.
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

    // Reúne as sessões de elegibilidade (base + extras se valer a pena).
    final List<SessaoPortal> sessoes = [sessaoBase];
    if (credenciais != null &&
        elegibilidades.length >= _minElegibilidadeParaMultiplasSessoes) {
      final int extras =
          min(_limiteSessoesParalelas - 1, elegibilidades.length - 1);
      for (int i = 0; i < extras; i++) {
        final SessaoPortal nova = SessaoPortal(logger: _logger);
        final ResultadoLogin login = await nova.login(
          code: credenciais.code,
          user: credenciais.user,
          senha: credenciais.senha,
        );
        if (login.autenticada) {
          sessoes.add(nova);
        } else {
          _logger.w(
            'Sessao de elegibilidade extra ${i + 1} nao autenticada '
            '(segue com as demais).',
          );
        }
      }
    }

    // Distribui as carteiras em round-robin pelas sessões (serial por sessão).
    final List<List<dynamic>> particoes =
        List.generate(sessoes.length, (_) => <dynamic>[]);
    for (int i = 0; i < elegibilidades.length; i++) {
      particoes[i % sessoes.length].add(elegibilidades[i]);
    }

    final List<Future<List<Map<String, dynamic>>>> trabalhos = [];
    for (int i = 0; i < sessoes.length; i++) {
      trabalhos.add(
        _processarSessao(
          sessao: sessoes[i],
          fatiaElegibilidade: particoes[i],
          vpps: i == 0 ? vpps : const [],
        ),
      );
    }

    final List<Map<String, dynamic>> resultados = [];
    for (final List<Map<String, dynamic>> parte
        in await Future.wait(trabalhos)) {
      resultados.addAll(parte);
    }
    return resultados;
  }

  /// Uma sessão: elegibilidade da fatia uma a uma (serial, preserva o form);
  /// os VPPs rodam em paralelo até [_limiteConcorrencia].
  Future<List<Map<String, dynamic>>> _processarSessao({
    required SessaoPortal sessao,
    required List<dynamic> fatiaElegibilidade,
    required List<dynamic> vpps,
  }) async {
    final List<Map<String, dynamic>> resultados = [];
    for (final dynamic item in fatiaElegibilidade) {
      resultados.add(await _executarConsulta(sessao, item));
    }
    if (vpps.isNotEmpty) {
      resultados.addAll(
        await _processarEmParalelo(vpps, sessao, _limiteConcorrencia),
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
      if (chave.length != 20 || !RegExp(r'^\d+$').hasMatch(chave)) {
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
          'pagina: ${_resumirTexto(html)}',
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

  String _resumirTexto(String html) {
    final String texto = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return texto.length > 300 ? '${texto.substring(0, 300)}…' : texto;
  }

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


  Future<Map<String, dynamic>?> _lerJson(Request request) async {
    try {
      final String corpo = await request.readAsString();
      if (corpo.isEmpty) return null;
      return jsonDecode(corpo) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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
