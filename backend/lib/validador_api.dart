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
  /// executa contra o portal com concorrência limitada, devolvendo cada
  /// resultado individualmente — o cliente faz uma única requisição HTTP.
  Future<Response> _consultas(Request request) async {
    final Map<String, dynamic>? corpo = await _lerJson(request);
    if (corpo == null) return _erro('Corpo JSON invalido.', 400);

    final SessaoPortal? sessao = _sessaoPorCorpo(corpo);
    if (sessao == null) {
      return _erro('Token de sessao invalido ou ausente.', 401);
    }

    final dynamic consultas = corpo['consultas'];
    if (consultas is! List || consultas.isEmpty) {
      return _erro('Campo consultas e obrigatorio.', 400);
    }

    final List<Map<String, dynamic>> resultados =
        await _processarEmParalelo(consultas, sessao, _limiteConcorrencia);
    return _json({'status': 'ok', 'resultados': resultados});
  }

  /// Teto de requisições simultâneas ao portal: alto o bastante para lotes
  /// grandes (100+ guias) terminarem rápido, e contido para não sobrecarregar
  /// o F5 ASM do portal nem a memória do free tier (respostas são enxutas).
  static const int _limiteConcorrencia = 10;

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
        final dynamic item = consultas[indice];
        final String tipo =
            item is Map ? (item['tipo'] as String? ?? '') : '';
        // Elegibilidade usa form com estado por sessão no portal: dois POSTs
        // simultâneos corrompem o resultado (falso "carteira não
        // encontrada"). Serializa só a elegibilidade; o VPP (GET) segue
        // paralelo dentro do limite do pool.
        resultados[indice] = tipo == 'elegibilidade'
            ? await _executarElegibilidadeSerializada(
                () => _executarConsulta(sessao, item),
              )
            : await _executarConsulta(sessao, item);
      }
    }

    final int qtdTrabalhadores = min(limite, consultas.length);
    await Future.wait([
      for (int i = 0; i < qtdTrabalhadores; i++) trabalhador(),
    ]);
    return resultados.whereType<Map<String, dynamic>>().toList();
  }

  /// Encadeia as consultas de elegibilidade (uma de cada vez) para preservar
  /// o estado do form do portal por sessão.
  Future<void> _ultimaElegibilidade = Future.value();

  Future<T> _executarElegibilidadeSerializada<T>(
    Future<T> Function() acao,
  ) {
    final Future<T> resultado =
        _ultimaElegibilidade.then((_) => acao());
    _ultimaElegibilidade =
        resultado.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return resultado;
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
      _sessoes.remove(_sessoes.keys.first);
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