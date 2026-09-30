import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

import 'elegibilidade_parser.dart';
import 'util_texto.dart';

class ValidadorApi {
  /// [ambiente] permite injetar a configuração em testes; em producao usa
  /// `Platform.environment`. Nao altera o contrato HTTP.
  /// [fabricaSessao] permite injetar um `SessaoPortal` falso em testes,
  /// evitando qualquer acesso ao portal real. Em producao usa a construcao
  /// padrao com o logger da instancia.
  /// [sondaPortal] executa a sondagem de rede do teste de alcance. Em teste
  /// permite contar as sondagens sem tocar a rede; em producao usa o
  /// `HttpClient` comum.
  /// [janelaCacheAlcance] define por quanto tempo o resultado da sondagem vale
  /// para chamadas seguidas, evitando handshakes TLS repetidos.
  ValidadorApi({
    Logger? logger,
    Map<String, String>? ambiente,
    SessaoPortal Function(Logger logger)? fabricaSessao,
    Future<int> Function()? sondaPortal,
    Duration janelaCacheAlcance = const Duration(seconds: 10),
    int limiteSessoes = _limiteSessoesPadrao,
  })  : _logger = logger ?? Logger(),
        _ambiente = ambiente,
        _fabricaSessao = fabricaSessao ?? _criarSessaoPortal,
        _janelaCacheAlcance = janelaCacheAlcance,
        _limiteSessoes = limiteSessoes,
        _sondaPortal = sondaPortal ?? _sondarPortalPadrao;

  static SessaoPortal _criarSessaoPortal(Logger logger) =>
      SessaoPortal(logger: logger);

  final SessaoPortal Function(Logger logger) _fabricaSessao;
  final Logger _logger;
  final Map<String, String>? _ambiente;
  final Map<String, SessaoPortal> _sessoes = {};
  final Map<String, _CredenciaisPortal> _credenciaisPorToken = {};
  final Random _aleatorio = Random.secure();
  final Duration _janelaCacheAlcance;
  final int _limiteSessoes;
  final Future<int> Function() _sondaPortal;

  static const int _limiteSessoesPadrao = 10;

  Map<String, dynamic>? _alcanceCacheado;
  DateTime? _alcanceColetadoEm;

  bool _loteEmAndamento = false;

  /// Token cuja sessao esta ocupada por um lote em andamento. A eviccao de
  /// sessao antiga nunca pode fechar o `Dio` de um lote em voo.
  String? _tokenEmUso;

  static const int _maxItensPorLote = 300;
  static const int _maxBytesCorpo = 1 << 20;

  static const Set<String> _rotasDePortal = {
    'api/login',
    'api/consultas',
  };
  static const int _maxRateLimitPorJanela = 40;
  static const Duration _janelaRateLimit = Duration(minutes: 1);

  late final Router _rotas = Router()
    ..post('/api/login', _login)
    ..post('/api/consultas', _consultas)
    ..get('/api/status', _status)
    ..all('/<ignored|.*>', _naoEncontrado);

  // Precisa ser unico por instancia: o rate limit guarda estado na closure
  // do middleware e se reconstruido a cada acesso perderia a contagem.
  late final Handler _handler = const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(ValidadorApi._rateLimitPortal())
      .addHandler(_rotas.call);

  Handler get handler => _handler;

  Future<Response> _login(Request request) async {
    final _LeituraJson leitura = await _lerJson(request);
    if (leitura.excedeLimite) return _erroCorpoGrande();
    final Map<String, dynamic>? corpo = leitura.valor;
    if (corpo == null) {
      return _erro('Corpo JSON invalido.', 400);
    }

    final String? identificador = corpo['identificadorPrestador'] as String?;
    if (identificador == null || identificador.trim().isEmpty) {
      return _erro('Campo identificadorPrestador e obrigatorio.', 400);
    }

    final CredenciaisPortal? credenciais = CredenciaisPortal.resolver(
      identificador.trim(),
      ambiente: _ambiente,
    );
    if (credenciais == null) {
      _logger.w('Login recusado: identificador desconhecido.');
      return _erro('Identificador de prestador nao autorizado.', 401);
    }

    final SessaoPortal sessao = _fabricaSessao(_logger);
    final ResultadoLogin resultado = await sessao.login(
      code: credenciais.code,
      user: credenciais.user,
      senha: credenciais.senha,
    );
    if (!resultado.autenticada) {
      final String mensagem = switch (resultado.motivo) {
        MotivoFalhaLogin.credenciaisInvalidas =>
          'Credenciais invalidas para o portal SulAmerica.',
        MotivoFalhaLogin.falhaRede =>
          'Falha de rede ao acessar o portal SulAmerica.',
        MotivoFalhaLogin.falhaInterna =>
          'Falha interna ao processar a resposta do portal SulAmerica.',
        MotivoFalhaLogin.respostaInesperada ||
        null =>
          'O portal SulAmerica respondeu de forma inesperada '
              '(possivel bloqueio do F5 ASM).',
      };
      // O detalhe crus (URL, fragmento de requisicao) nao pode sair para um
      // cliente ainda nao autenticado: fica apenas no log do servidor.
      _logger.w(
        'Login recusado: $mensagem'
        '${resultado.detalhe == null ? '' : ' (log) ${resultado.detalhe}'}',
      );
      return _erro(mensagem, 401);
    }

    final String? token = await _novoToken(sessao);
    if (token == null) {
      await sessao.encerrar();
      _logger.w('Login recusado: limite de sessoes todas em uso.');
      return _erro(
        'Limite de sessoes ativas em uso. Tente novamente em instantes.',
        503,
      );
    }

    _credenciaisPorToken[token] = _CredenciaisPortal(
      code: credenciais.code,
      user: credenciais.user,
      senha: credenciais.senha,
    );
    _logger.i('Sessao criada para o prestador (identificador mascarado).');
    return _json({'token': token, 'autenticada': true});
  }

  Future<Response> _consultas(Request request) async {
    final _LeituraJson leitura = await _lerJson(request);
    if (leitura.excedeLimite) return _erroCorpoGrande();
    final Map<String, dynamic>? corpo = leitura.valor;
    if (corpo == null) return _erro('Corpo JSON invalido.', 400);

    // Valida payload antes de verificar token.
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

    // Valida estrutura de cada item antes de processar.
    for (int i = 0; i < consultas.length; i++) {
      final dynamic item = consultas[i];
      if (item is! Map) {
        return _erro(
          'Item $i deve ser um objeto com campos tipo e chave.',
          400,
        );
      }
      final dynamic tipo = item['tipo'];
      final dynamic chave = item['chave'];
      if (tipo is! String || tipo.isEmpty) {
        return _erro('Item $i: campo tipo deve ser uma string nao vazia.', 400);
      }
      if (chave is! String || chave.isEmpty) {
        return _erro(
          'Item $i: campo chave deve ser uma string nao vazia.',
          400,
        );
      }
    }

    final SessaoPortal? sessao = _sessaoPorCorpo(corpo);
    if (sessao == null) {
      return _erro('Token de sessao invalido ou ausente.', 401);
    }
    final String? token = corpo['token'] as String?;

    if (_loteEmAndamento) {
      return _erro('Ja existe um lote em andamento. Aguarde.', 429);
    }

    // Sem `await` entre a checagem e as duas marcacoes: o event loop do Dart
    // garante que ninguem intercala aqui.
    _loteEmAndamento = true;
    _tokenEmUso = token;
    List<Map<String, dynamic>> resultados;
    try {
      resultados = await _executarConsultas(
        sessaoBase: sessao,
        credenciais: token == null ? null : _credenciaisPorToken[token],
        consultas: consultas,
      );
    } finally {
      _loteEmAndamento = false;
      _tokenEmUso = null;
    }

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

  static const int _limiteSessoesParalelas = 10;

  static const int _minElegibilidadeParaMultiplasSessoes = 10;

  static const int _limiteSenhaPorSessao = 3;

  Future<List<Map<String, dynamic>>> _executarConsultas({
    required SessaoPortal sessaoBase,
    required _CredenciaisPortal? credenciais,
    required List<dynamic> consultas,
  }) async {
    final List<dynamic> elegibilidades = [
      for (final dynamic c in consultas)
        if ((c as Map)['tipo'] == 'elegibilidade') c,
    ];
    final List<dynamic> senhas = [
      for (final dynamic c in consultas)
        if ((c as Map)['tipo'] != 'elegibilidade') c,
    ];

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

    final List<List<dynamic>> particoesEleg =
        List.generate(sessoes.length, (_) => <dynamic>[]);
    final List<List<dynamic>> particoesSenha =
        List.generate(sessoes.length, (_) => <dynamic>[]);
    for (int i = 0; i < elegibilidades.length; i++) {
      particoesEleg[i % sessoes.length].add(elegibilidades[i]);
    }
    for (int i = 0; i < senhas.length; i++) {
      particoesSenha[i % sessoes.length].add(senhas[i]);
    }

    final List<Future<List<Map<String, dynamic>>>> trabalhos = [];
    for (int i = 0; i < sessoes.length; i++) {
      trabalhos.add(
        _processarSessao(
          sessao: sessoes[i],
          fatiaElegibilidade: particoesEleg[i],
          fatiaSenhas: particoesSenha[i],
          credenciais: credenciais,
        ),
      );
    }

    final List<Map<String, dynamic>> resultados = [];
    for (final List<Map<String, dynamic>> parte
        in await Future.wait(trabalhos)) {
      resultados.addAll(parte);
    }

    for (final SessaoPortal extra in sessoes.skip(1)) {
      await extra.encerrar();
    }
    return resultados;
  }

  Future<SessaoPortal?> _criarSessaoExtra(
    _CredenciaisPortal credenciais,
    int indice,
  ) async {
    final SessaoPortal nova = _fabricaSessao(_logger);
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

  Future<List<Map<String, dynamic>>> _processarSessao({
    required SessaoPortal sessao,
    required List<dynamic> fatiaElegibilidade,
    required List<dynamic> fatiaSenhas,
    required _CredenciaisPortal? credenciais,
  }) async {
    final List<Map<String, dynamic>> resultados = [];
    for (final dynamic item in fatiaElegibilidade) {
      resultados.add(await _executarConsulta(sessao, item, credenciais));
    }
    if (fatiaSenhas.isNotEmpty) {
      resultados.addAll(
        await _processarEmParalelo(
          fatiaSenhas,
          sessao,
          _limiteSenhaPorSessao,
          credenciais,
        ),
      );
    }
    return resultados;
  }

  Future<List<Map<String, dynamic>>> _processarEmParalelo(
    List<dynamic> consultas,
    SessaoPortal sessao,
    int limite,
    _CredenciaisPortal? credenciais,
  ) async {
    final List<Map<String, dynamic>?> resultados =
        List<Map<String, dynamic>?>.filled(consultas.length, null);
    int proximo = 0;

    Future<void> trabalhador() async {
      while (true) {
        final int indice = proximo++;
        if (indice >= consultas.length) return;
        resultados[indice] = await _executarConsulta(
          sessao,
          consultas[indice],
          credenciais,
        );
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
    _CredenciaisPortal? credenciais,
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
      final String? html = await _consultarComRecuperacao(
        sessao: sessao,
        credenciais: credenciais,
        consulta: () =>
            sessao.consultarBeneficiario(carteirinhaCompleta: chave),
      );
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
        _logger.w(
          'Elegibilidade sem indicador | carteira ${_mascararChave(chave)} | '
          'pagina: ${resumirTexto(html.replaceAll(RegExp(r'<[^>]*>'), ' '))}',
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

    if (tipo == 'senha') {
      if (!_senhaValida(chave)) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro':
              'Senha invalida: deve ter exatamente 10 digitos comecando com 5.',
        };
      }
      final Map<String, dynamic>? dados = await _consultarComRecuperacao(
        sessao: sessao,
        credenciais: credenciais,
        consulta: () => sessao.consultarSenha(senha: chave),
      );
      if (dados == null) {
        return {
          'chave': chave,
          'tipo': tipo,
          'sucesso': false,
          'erro': 'Falha na consulta ao portal SulAmerica.',
        };
      }
      return {
        'chave': chave,
        'tipo': tipo,
        'sucesso': true,
        'statusSenha': _extrairStatusSenha(dados),
      };
    }

    return {
      'chave': chave,
      'tipo': tipo ?? '',
      'sucesso': false,
      'erro': 'Tipo de consulta desconhecido.',
    };
  }

  Future<T?> _consultarComRecuperacao<T>({
    required SessaoPortal sessao,
    required _CredenciaisPortal? credenciais,
    required Future<T?> Function() consulta,
  }) async {
    final T? resultado = await consulta();
    if (resultado != null) return resultado;

    final int? status = sessao.ultimoStatusFalha;
    final bool sessaoRejeitada =
        ehFalhaDeSessaoPortal(status) || !sessao.autenticada;
    if (sessaoRejeitada) {
      if (credenciais == null) return null;
      _logger.w(
        'Sessao do portal rejeitada (HTTP $status); renovando login.',
      );
      final ResultadoLogin login = await sessao.login(
        code: credenciais.code,
        user: credenciais.user,
        senha: credenciais.senha,
      );
      if (!login.autenticada) return null;
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return consulta();
  }

  String _mascararChave(String chave) => chave.length <= 5
      ? chave
      : '${chave.substring(0, 4)}…${chave.substring(chave.length - 2)}';

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
    return _json({
      'status': 'ok',
      'sessoesAtivas': _sessoes.length,
      'portalSulAmerica': alcancePortal,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Sonda o portal no maximo uma vez por [_janelaCacheAlcance].
  ///
  /// O cache e a protecao principal: sem ele, cada `GET /api/status` de um
  /// cliente anonimo-forjador abriria um handshake TLS de saida. Nao ha rate
  /// limit nesta rota de proposito (ver README): 429 conta como falha para o
  /// health check do Render, que descarta trafego apos 15 s de falhas
  /// consecutivas e reinicia a instancia apos 60 s.
  Future<Map<String, dynamic>> _alcancePortal() async {
    final DateTime agora = DateTime.now();
    final Map<String, dynamic>? cache = _alcanceCacheado;
    final DateTime? coletadoEm = _alcanceColetadoEm;
    if (cache != null &&
        coletadoEm != null &&
        agora.difference(coletadoEm) < _janelaCacheAlcance) {
      return cache;
    }
    final Map<String, dynamic> resultado = await _testarAlcancePortal();
    _alcanceCacheado = resultado;
    _alcanceColetadoEm = agora;
    return resultado;
  }

  Future<Map<String, dynamic>> _testarAlcancePortal() async {
    try {
      return {
        'alcançavel': true,
        'status': await _sondaPortal(),
      };
    } catch (erro) {
      // `erro.toString()` carrega subject/issuer do certificado e detalhes de
      // rede interna: fica no log, nunca no corpo de uma rota anonima.
      _logger.w('Teste de alcance do portal falhou: $erro');
      return {'alcançavel': false};
    }
  }

  static Future<int> _sondarPortalPadrao() async {
    final HttpClient http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest requisicao = await http
          .getUrl(Uri.parse('https://saude.sulamericaseguros.com.br/'))
          .timeout(const Duration(seconds: 10));
      final HttpClientResponse resposta =
          await requisicao.close().timeout(const Duration(seconds: 10));
      return resposta.statusCode;
    } finally {
      http.close(force: true);
    }
  }

  Response _naoEncontrado(Request request, String ignorado) {
    return _erro('Rota nao encontrada.', 404);
  }

  /// Retorna `null` quando todas as sessoes estao em uso.
  ///
  /// A eviccao nunca encerra a sessao de um lote em andamento: fechar o `Dio`
  /// dela no meio de uma consulta quebraria o lote em voo. Como existe apenas
  /// um lote simultaneo, basta proteger o token corrente.
  Future<String?> _novoToken(SessaoPortal sessao) async {
    if (_sessoes.length >= _limiteSessoes) {
      final Iterable<String> antigas =
          _sessoes.keys.where((String token) => token != _tokenEmUso).toList();
      if (antigas.isEmpty) return null;
      final String antiga = antigas.first;
      final SessaoPortal? sessaoAntiga = _sessoes.remove(antiga);
      _credenciaisPorToken.remove(antiga);
      await sessaoAntiga?.encerrar();
    }
    final String token = _gerarToken();
    _sessoes[token] = sessao;
    return token;
  }

  String _gerarToken() {
    final List<int> bytes =
        List<int>.generate(16, (_) => _aleatorio.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  SessaoPortal? _sessaoPorCorpo(Map<String, dynamic> corpo) {
    final String? token = corpo['token'] as String?;
    return token == null ? null : _sessoes[token];
  }

  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  static bool _senhaValida(String senha) =>
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

          // Remove janelas expiradas para evitar crescimento ilimitado.
          acessos.removeWhere((_, timestamps) {
            timestamps.removeWhere(
              (t) => agora.difference(t) >= _janelaRateLimit,
            );
            return timestamps.isEmpty;
          });

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
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          recentes.add(agora);
          acessos[ip] = recentes;
          return inner(request);
        };
  }

  /// Obtém o IP de origem da conexão.
  ///
  /// NÃO confia em `X-Forwarded-For` arbitrário recebido do cliente,
  /// pois pode ser falsificado para burlar o rate limit. Usa apenas o
  /// endereço de conexão real (`shelf.io.connection_info`).
  static String _ipDe(Request request) {
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
    return _json(
      {'status': 'erro', 'mensagem': mensagem},
      statusCode: statusCode,
    );
  }

  /// `CORS_ORIGIN` aceita uma ou mais origens separadas por virgula. A
  /// resposta ecoa **apenas** a origem que casa com o `Origin` da requisicao,
  /// porque `Access-Control-Allow-Origin` aceita um valor so: ecoar a lista
  /// inteira produz um header invalido e o navegador bloqueia a chamada.
  /// Ausente ou vazia, vale `*` (default de desenvolvimento). Com lista
  /// explicita, origem de fora da lista nao recebe o header.
  Middleware _cors() {
    final String configurado =
        (_ambiente ?? Platform.environment)['CORS_ORIGIN'] ?? '';
    final List<String> origens = <String>[
      for (final String item in configurado.split(','))
        if (_origemNormalizada(item) != null) _origemNormalizada(item)!,
    ];
    return (Handler inner) {
      return (Request request) async {
        final String? permitida =
            _origemPermitida(origens, request.headers['origin']);
        final Map<String, String> headers = <String, String>{
          if (permitida != null) 'Access-Control-Allow-Origin': permitida,
          // A resposta passa a depender de `Origin`: sem `Vary`, um cache
          // compartilhado (CDN/proxy) poderia servir a resposta de uma origem
          // para outra.
          if (permitida != null && permitida != '*') 'vary': 'origin',
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

  /// Normaliza um item de `CORS_ORIGIN`: sem espacos nas pontas e sem barra
  /// final, porque um origin da spec e esquema+host+porta, sem path. Itens
  /// vazios (virgula dupla ou virgula no fim) viram `null` e sao ignorados.
  static String? _origemNormalizada(String item) {
    String origem = item.trim();
    while (origem.endsWith('/')) {
      origem = origem.substring(0, origem.length - 1);
    }
    return origem.isEmpty ? null : origem;
  }

  /// Valor de `Access-Control-Allow-Origin` para a requisicao, ou `null` para
  /// nao enviar o header e deixar o navegador bloquear.
  static String? _origemPermitida(List<String> origens, String? requisicao) {
    if (origens.isEmpty || origens.contains('*')) return '*';
    if (requisicao == null) return null;
    final String? normalizada = _origemNormalizada(requisicao);
    if (normalizada == null || !origens.contains(normalizada)) return null;
    return normalizada;
  }
}

class _LeituraJson {
  const _LeituraJson(this.valor, {this.excedeLimite = false});

  final Map<String, dynamic>? valor;
  final bool excedeLimite;
}

bool ehFalhaDeSessaoPortal(int? status) => status == 401 || status == 403;

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
