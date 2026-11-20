import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logger/logger.dart';

import 'assinatura_resposta_portal.dart';
import 'resultado_consulta_portal.dart';

/// `falhaRede` cobre apenas `DioException`. Erro de codigo, header inesperado
/// ou estado invalido cai em `falhaInterna`: juntar os dois sob o mesmo rotulo
/// escondia a causa real atras de "falha de rede".
enum MotivoFalhaLogin {
  credenciaisInvalidas,
  respostaInesperada,
  falhaRede,
  falhaInterna,
}

class ResultadoLogin {
  const ResultadoLogin.autenticado()
      : autenticada = true,
        motivo = null,
        detalhe = null;

  const ResultadoLogin.falha(this.motivo, {this.detalhe}) : autenticada = false;

  final bool autenticada;
  final MotivoFalhaLogin? motivo;

  final String? detalhe;
}

class SessaoPortal {
  SessaoPortal({Dio? dio, CookieJar? cookieJar, Logger? logger})
      : _dio = dio ?? Dio(),
        _cookieJar = cookieJar ?? CookieJar(),
        _logger = logger ?? Logger() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
      followRedirects: false,
    );

    // O cliente padrao do Dart continua validando a cadeia e o hostname.
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()
          ..maxConnectionsPerHost = 8
          ..idleTimeout = const Duration(seconds: 10),
        validateCertificate: validarCertificado,
      );
    }
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static const String hostPortal = 'saude.sulamericaseguros.com.br';

  /// Confirma que o certificado apresentado foi emitido para o host do portal.
  ///
  /// A validacao de CA e de hostname ja foi feita pelo `HttpClient` antes deste
  /// callback (ver doc do dio: ele so e invocado apos a cadeia ser aceita).
  /// Este metodo nao repete essa checagem; ele registra no log um certificado
  /// de outro host, que indicaria redirecionamento ou interceptacao.
  bool validarCertificado(X509Certificate? certificate, String host, int port) {
    if (host != hostPortal) {
      _logger.e('TLS: host inesperado $host (esperado $hostPortal).');
      return false;
    }
    return true;
  }

  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  static const String _urlLogin =
      'https://saude.sulamericaseguros.com.br/main.jsp'
      '?lumPageId=8A61898253CE1C780153D20B7FF82329'
      '&lumA=1'
      '&lumII=8A61890A697C8A4C01697C9D3DE0250E';

  static const String _urlConsulta =
      'https://saude.sulamericaseguros.com.br/main.jsp'
      '?lumPageId=8A61F4123F396827013F39A6986109F9'
      '&lumA=1'
      '&lumII=8A61F4123F589847013F590540AE113E';

  static const String _urlAjax =
      'https://saude.sulamericaseguros.com.br/ajax-controller.jsp';

  static const Map<String, String> _camposLogin = {
    'destId': '8A61890A697C8A4C01697C9D3DE0250E',
    'destType': 'lumII',
    'lumFromForm': 'Form_8A61890A697C8A4C01697C9D3DE0250E',
    'lumFormAction': _urlLogin,
    'doui_processActionId': 'loginPrestador',
    'doui_fromForm': 'Form_8A61890A697C8A4C01697C9D3DE0250E',
    'lumII': '8A61890A697C8A4C01697C9D3DE0250E',
  };

  static const Map<String, String> _camposConsulta = {
    'destId': '8A61F4123F589847013F590540AE113E',
    'destType': 'lumII',
    'lumFromForm': 'Form_8A61F4123F589847013F590540AE113E',
    'lumFormAction': _urlConsulta,
    'doui_processActionId': 'submitForm',
    'doui_fromForm': 'Form_8A61F4123F589847013F590540AE113E',
    'lumII': '8A61F4123F589847013F590540AE113E',
  };

  static const List<int> _tamanhosSegmentosCarteirinha = [3, 5, 4, 4, 4];
  static final int _maxRetriesFalhaTransitoria = _lerInteiroAmbiente(
    'PORTAL_RETRY_MAX_TENTATIVAS',
    3,
    maximo: 10,
  );
  static final int _baseBackoffMs = _lerInteiroAmbiente(
    'PORTAL_RETRY_BACKOFF_BASE_MS',
    1000,
    maximo: 60000,
  );
  static final int _maxBackoffMs = _lerInteiroAmbiente(
    'PORTAL_RETRY_BACKOFF_MAX_MS',
    20000,
    minimo: 1,
    maximo: 120000,
  );
  static final int _jitterPercent = _lerInteiroAmbiente(
    'PORTAL_RETRY_JITTER_PERCENT',
    30,
    maximo: 100,
  );
  static final Random _aleatorioRetry = Random.secure();

  static int _lerInteiroAmbiente(
    String nome,
    int padrao, {
    int minimo = 0,
    required int maximo,
  }) {
    final int? valor = int.tryParse(Platform.environment[nome] ?? '');
    return (valor ?? padrao).clamp(minimo, maximo).toInt();
  }

  final Dio _dio;
  final CookieJar _cookieJar;
  final Logger _logger;
  static final _SemaforoRequisicoes _semaforoGlobal = _SemaforoRequisicoes(16);

  bool _autenticada = false;
  String _codigoPrestador = '100000015513';
  ({String code, String user, String senha})? _credenciais;
  Future<ResultadoLogin>? _loginEmAndamento;
  bool _loginEmAndamentoRepeteFalhaRede = false;
  final Map<int, Future<ResultadoLogin>> _renovacoesPorGeracao = {};
  int _geracao = 0;
  int _rejeicoes401 = 0;
  int _rejeicoes403 = 0;
  int _rejeicoes401AposRenovacao = 0;
  int _rejeicoes403AposRenovacao = 0;
  int _renovacoesIniciadas = 0;
  int _renovacoesSucesso = 0;
  int _renovacoesFalhaCredenciaisInvalidas = 0;
  int _renovacoesFalhaRespostaInesperada = 0;
  int _renovacoesFalhaRede = 0;
  int _renovacoesFalhaInterna = 0;
  int _renovacoesFalhaSemMotivo = 0;
  int _renovacoesExcecaoInterna = 0;
  final Map<String, int> _diagnosticoEtapas = <String, int>{};
  final ColetorAssinaturasRespostaPortal _assinaturas =
      ColetorAssinaturasRespostaPortal();

  bool get autenticada => _autenticada;

  static Map<String, int> get diagnosticoConcorrencia =>
      _semaforoGlobal.diagnostico;

  Map<String, int> get diagnosticoSessao => <String, int>{
        ..._diagnosticoEtapas,
        'rejeicoes401': _rejeicoes401,
        'rejeicoes403': _rejeicoes403,
        'rejeicoes401AposRenovacao': _rejeicoes401AposRenovacao,
        'rejeicoes403AposRenovacao': _rejeicoes403AposRenovacao,
        'renovacoesIniciadas': _renovacoesIniciadas,
        'renovacoesSucesso': _renovacoesSucesso,
        'renovacoesFalhaCredenciaisInvalidas':
            _renovacoesFalhaCredenciaisInvalidas,
        'renovacoesFalhaRespostaInesperada': _renovacoesFalhaRespostaInesperada,
        'renovacoesFalhaRede': _renovacoesFalhaRede,
        'renovacoesFalhaInterna': _renovacoesFalhaInterna,
        'renovacoesFalhaSemMotivo': _renovacoesFalhaSemMotivo,
        'renovacoesExcecaoInterna': _renovacoesExcecaoInterna,
      };

  List<Map<String, dynamic>> get supportIdsRespostaPortal =>
      _assinaturas.supportIdsRecentes;

  Map<String, String> get _headersNavegador => {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        'Upgrade-Insecure-Requests': '1',
      };

  Map<String, String> get _headersPost => {
        ..._headersNavegador,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://saude.sulamericaseguros.com.br',
        'Referer': _urlLogin,
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Dest': 'document',
      };

  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) =>
      _loginCompartilhado(
        code: code,
        user: user,
        senha: senha,
        repetirFalhaRede: false,
      );

  Future<ResultadoLogin> _loginCompartilhado({
    required String code,
    required String user,
    required String senha,
    required bool repetirFalhaRede,
  }) {
    final Future<ResultadoLogin>? existente = _loginEmAndamento;
    if (existente != null) {
      if (!repetirFalhaRede || _loginEmAndamentoRepeteFalhaRede) {
        return existente;
      }

      final Future<ResultadoLogin> promovido = _loginComRetry(
        code: code,
        user: user,
        senha: senha,
        repetirFalhaRede: true,
        tentativaInicial: existente,
      );
      _loginEmAndamento = promovido;
      _loginEmAndamentoRepeteFalhaRede = true;
      return _limparLoginEmAndamento(promovido);
    }

    final Future<ResultadoLogin> futuro = _loginComRetry(
      code: code,
      user: user,
      senha: senha,
      repetirFalhaRede: repetirFalhaRede,
    );
    _loginEmAndamento = futuro;
    _loginEmAndamentoRepeteFalhaRede = repetirFalhaRede;
    return _limparLoginEmAndamento(futuro);
  }

  Future<ResultadoLogin> _limparLoginEmAndamento(
    Future<ResultadoLogin> futuro,
  ) =>
      futuro.whenComplete(() {
        if (identical(_loginEmAndamento, futuro)) {
          _loginEmAndamento = null;
          _loginEmAndamentoRepeteFalhaRede = false;
        }
      });

  Future<ResultadoLogin> garantirAutenticada() async {
    if (_autenticada) return const ResultadoLogin.autenticado();
    final ({String code, String user, String senha})? credenciais =
        _credenciais;
    if (credenciais == null) {
      return const ResultadoLogin.falha(MotivoFalhaLogin.credenciaisInvalidas);
    }
    return login(
      code: credenciais.code,
      user: credenciais.user,
      senha: credenciais.senha,
    );
  }

  Future<ResultadoLogin> _loginComRetry({
    required String code,
    required String user,
    required String senha,
    required bool repetirFalhaRede,
    Future<ResultadoLogin>? tentativaInicial,
  }) async {
    final ResultadoLogin primeiro = await (tentativaInicial ??
        _executarLogin(code: code, user: user, senha: senha));
    if (primeiro.autenticada ||
        !repetirFalhaRede ||
        primeiro.motivo != MotivoFalhaLogin.falhaRede) {
      return primeiro;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _executarLogin(code: code, user: user, senha: senha);
  }

  Future<ResultadoLogin> _executarLogin({
    required String code,
    required String user,
    required String senha,
  }) async {
    _credenciais = (code: code, user: user, senha: senha);
    _autenticada = false;
    try {
      final Response<String> pagina = await _semaforoGlobal.executar(
        () => _dio.get<String>(
          _urlLogin,
          options: Options(
            headers: _headersNavegador,
            responseType: ResponseType.plain,
          ),
        ),
      );
      if (pagina.statusCode != 200) {
        _registrarStatus('loginGetHttp', pagina.statusCode);
        _incrementarDiagnostico('loginGetRespostaInesperada');
        _registrarAssinaturaResposta(
          status: pagina.statusCode,
          contentType: pagina.headers['content-type']?.join(','),
          body: pagina.data == null ? null : utf8.encode(pagina.data!),
        );
        _logger.e(
          'GET inicial do login retornou HTTP ${pagina.statusCode} '
          '(possivel bloqueio do F5 ASM).',
        );
        return const ResultadoLogin.falha(MotivoFalhaLogin.respostaInesperada);
      }
      _registrarStatus('loginGetHttp', pagina.statusCode);

      final Map<String, String> campos = {
        ..._camposLogin,
        'code': code,
        'user': user,
        'senha': senha,
      };

      final Response<String> resposta = await _semaforoGlobal.executar(
        () => _dio.post<String>(
          _urlLogin,
          data: Uri(queryParameters: campos).query,
          options: Options(
            headers: _headersPost,
            responseType: ResponseType.plain,
          ),
        ),
      );
      _registrarStatus('loginPostHttp', resposta.statusCode);
      if (resposta.statusCode != 302 && resposta.statusCode != 200) {
        _registrarAssinaturaResposta(
          status: resposta.statusCode,
          contentType: resposta.headers['content-type']?.join(','),
          body: resposta.data == null ? null : utf8.encode(resposta.data!),
        );
      }

      if (resposta.statusCode == 302) {
        final String? urlFinal = _urlDeRedirect(resposta);
        if (urlFinal == null) {
          _incrementarDiagnostico('loginRedirectSemLocation');
          _logger.e('Login Lumis: 302 sem Location.');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.respostaInesperada,
          );
        }
        final Response<String> pos = await _semaforoGlobal.executar(
          () => _dio.get<String>(
            urlFinal,
            options: Options(
              headers: {..._headersNavegador, 'Referer': _urlLogin},
              responseType: ResponseType.plain,
            ),
          ),
        );
        _registrarStatus('loginRedirectHttp', pos.statusCode);
        if (pos.statusCode != 200) {
          _registrarAssinaturaResposta(
            status: pos.statusCode,
            contentType: pos.headers['content-type']?.join(','),
            body: pos.data == null ? null : utf8.encode(pos.data!),
          );
          _incrementarDiagnostico('loginRedirectRespostaInesperada');
          _logger.e('Login Lumis: redirect final HTTP ${pos.statusCode}.');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.respostaInesperada,
          );
        }
        final bool paginaAutenticada = (pos.data ?? '').toLowerCase().contains(
              'logout',
            );
        _codigoPrestador = code;
        _autenticada = paginaAutenticada;
        if (_autenticada) _geracao++;
        final int quantidadeCookies = (await _cookieJar.loadForRequest(
          Uri.parse(_urlLogin),
        ))
            .length;
        _logger.i(
          'Login Lumis: redirect concluido | '
          'pagina autenticada: $_autenticada | '
          'sessao: $quantidadeCookies cookies.',
        );
        if (!paginaAutenticada) {
          _incrementarDiagnostico('loginRedirectSemLogout');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.credenciaisInvalidas,
          );
        }
        _incrementarDiagnostico('loginAutenticado');
        return const ResultadoLogin.autenticado();
      }

      if (resposta.statusCode != 200) {
        _incrementarDiagnostico('loginPostRespostaInesperada');
        _logger.e('Login Lumis retornou HTTP ${resposta.statusCode}.');
        return const ResultadoLogin.falha(MotivoFalhaLogin.respostaInesperada);
      }

      final String corpo = resposta.data ?? '';
      _autenticada = corpo.toLowerCase().contains('logout');
      if (_autenticada) {
        _codigoPrestador = code;
        _geracao++;
      }
      final int quantidadeCookies = (await _cookieJar.loadForRequest(
        Uri.parse(_urlLogin),
      ))
          .length;
      _logger.i(
        'Login Lumis: HTTP ${resposta.statusCode} | '
        'pagina autenticada: $_autenticada | '
        'sessao: $quantidadeCookies cookies.',
      );
      if (!_autenticada) {
        _incrementarDiagnostico('loginPostSemLogout');
        _logger.w('Login Lumis: resposta sem sessao autenticada.');
        return const ResultadoLogin.falha(
          MotivoFalhaLogin.credenciaisInvalidas,
        );
      }
      _incrementarDiagnostico('loginAutenticado');
      return const ResultadoLogin.autenticado();
    } on FormatException {
      _incrementarDiagnostico('loginFormatException');
      return const ResultadoLogin.falha(MotivoFalhaLogin.respostaInesperada);
    } on DioException catch (erro) {
      final int? status = erro.response?.statusCode;
      if (status != null) _registrarStatus('loginDioHttp', status);
      _registrarAssinaturaDio(erro);
      _incrementarDiagnostico(
        _ehFalhaTransporte(erro)
            ? 'loginDioFalhaTransporte'
            : 'loginDioRespostaInesperada',
      );
      _logger.e('Falha de rede no login: ${erro.type.name}.');
      return ResultadoLogin.falha(
        _ehFalhaTransporte(erro)
            ? MotivoFalhaLogin.falhaRede
            : MotivoFalhaLogin.respostaInesperada,
        detalhe: _detalheDioException(erro),
      );
    }
  }

  String _detalheDioException(DioException erro) {
    final int? status = erro.response?.statusCode;
    final String tipo = erro.type.name;
    return status != null ? '$tipo (HTTP $status): ${erro.message}' : tipo;
  }

  /// URL absoluta do redirect, ou `null` se a resposta nao tiver `Location`.
  ///
  /// Usa `headers['location']` e nao `headers.value('location')`: o segundo
  /// lanca `Exception` quando o header chega repetido, e essa excecao subia
  /// para o `catch` do login, virando "falha de rede" na resposta ao cliente.
  /// Um `Location` repetido e lido como o primeiro valor.
  String? _urlDeRedirect(Response<String> resposta) {
    final List<String>? valores = resposta.headers['location'];
    if (valores == null || valores.isEmpty) return null;
    final String destino = valores.first;
    return Uri.parse(destino).hasScheme
        ? destino
        : 'https://$hostPortal$destino';
  }

  Future<ResultadoConsultaPortal<String>> consultarBeneficiario({
    required String carteirinhaCompleta,
    CancelToken? cancelToken,
  }) {
    return _consultarComRecuperacao<String>(
      () => _consultarBeneficiario(
        carteirinhaCompleta: carteirinhaCompleta,
        cancelToken: cancelToken,
      ),
      cancelToken,
    );
  }

  Future<ResultadoConsultaPortal<String>> _consultarBeneficiario({
    required String carteirinhaCompleta,
    required CancelToken? cancelToken,
  }) async {
    if (!_autenticada) {
      return const ResultadoConsultaPortal<String>.falha(
        categoria: CategoriaFalhaConsultaPortal.sessao,
        status: 401,
      );
    }

    try {
      final List<String> partes = _dividirCarteirinha(carteirinhaCompleta);
      final Map<String, String> campos = {..._camposConsulta};
      for (int indice = 0; indice < partes.length; indice++) {
        campos['codigo-beneficiario-${indice + 1}'] = partes[indice];
      }

      final Response<String> resposta = await _semaforoGlobal.executar(
        () => _dio.post<String>(
          _urlConsulta,
          data: Uri(queryParameters: campos).query,
          cancelToken: cancelToken,
          options: Options(
            headers: _headersPost,
            responseType: ResponseType.plain,
          ),
        ),
        cancelToken: cancelToken,
      );

      if (resposta.statusCode == 302) {
        final String? urlFinal = _urlDeRedirect(resposta);
        if (urlFinal == null) {
          return ResultadoConsultaPortal<String>.falha(
            categoria: CategoriaFalhaConsultaPortal.respostaInesperada,
            status: resposta.statusCode,
          );
        }
        final Response<String> pos = await _semaforoGlobal.executar(
          () => _dio.get<String>(
            urlFinal,
            cancelToken: cancelToken,
            options: Options(
              headers: {..._headersNavegador, 'Referer': _urlConsulta},
              responseType: ResponseType.plain,
            ),
          ),
          cancelToken: cancelToken,
        );
        if (pos.statusCode != 200) {
          final bool rejeicaoF5 = _registrarAssinaturaResposta(
            status: pos.statusCode,
            contentType: pos.headers['content-type']?.join(','),
            body: pos.data == null ? null : utf8.encode(pos.data!),
          );
          return _falhaHttp<String>(
            pos.statusCode,
            retryable: _statusTransitorio(pos.statusCode) && !rejeicaoF5,
          );
        }
        return ResultadoConsultaPortal<String>.sucesso(
          dados: pos.data ?? '',
          status: pos.statusCode,
        );
      }

      if (resposta.statusCode != 200) {
        final bool rejeicaoF5 = _registrarAssinaturaResposta(
          status: resposta.statusCode,
          contentType: resposta.headers['content-type']?.join(','),
          body: resposta.data == null ? null : utf8.encode(resposta.data!),
        );
        return _falhaHttp<String>(
          resposta.statusCode,
          retryable: _statusTransitorio(resposta.statusCode) && !rejeicaoF5,
        );
      }
      return ResultadoConsultaPortal<String>.sucesso(
        dados: resposta.data ?? '',
        status: resposta.statusCode,
      );
    } on FormatException {
      return const ResultadoConsultaPortal<String>.falha(
        categoria: CategoriaFalhaConsultaPortal.respostaInesperada,
        status: null,
      );
    } on DioException catch (erro) {
      return _falhaDio<String>(erro);
    }
  }

  Future<ResultadoConsultaPortal<Map<String, dynamic>>> consultarSenha({
    required String senha,
    CancelToken? cancelToken,
  }) {
    return _consultarComRecuperacao<Map<String, dynamic>>(
      () => _consultarSenha(senha: senha, cancelToken: cancelToken),
      cancelToken,
    );
  }

  Future<ResultadoConsultaPortal<Map<String, dynamic>>> _consultarSenha({
    required String senha,
    required CancelToken? cancelToken,
  }) async {
    if (!_autenticada) {
      return const ResultadoConsultaPortal<Map<String, dynamic>>.falha(
        categoria: CategoriaFalhaConsultaPortal.sessao,
        status: 401,
      );
    }

    try {
      final Response<List<int>> resposta = await _semaforoGlobal.executar(
        () => _dio.get<List<int>>(
          _urlAjax,
          queryParameters: {
            'metodo': 'autorizador-pesquisar-solicitacoes',
            'total-registro-pagina': '10',
            'pagina-atual': '1',
            'doui_processActionId': '',
            'doui_renderAction': '',
            'doui_renderControlId': '',
            'doui_fromForm': 'Form_8A61F5C6405F961E01405FA8BE140FA1',
            'doui_storedValues': '',
            'lumII': '8A61F5C6405F961E01405FA8BE140FA1',
            'lumReplIntfCommands': '',
            'lumReplIntfParams': '',
            'tipo-solicitacao': '',
            'tipo-pesquisa': '5',
            'codigo-beneficiario-1': '',
            'codigo-beneficiario-2': '',
            'codigo-beneficiario-3': '',
            'codigo-beneficiario-4': '',
            'codigo-beneficiario-5': '',
            'numero-solicitacao': '',
            'codigo-guia-prestador': '',
            'data-inicial': '',
            'data-final': '',
            'status-solicitacao': '',
            'numero-vpp': senha,
            'codigo-prestador': _codigoPrestador,
            'codigo-solicitacao': '',
            'tipo-solicitacao.codigo': '',
          },
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json,text/plain,*/*',
              'Referer': _urlLogin,
            },
            responseType: ResponseType.bytes,
          ),
        ),
        cancelToken: cancelToken,
      );
      _registrarStatus('ajaxHttp', resposta.statusCode);
      _registrarContentTypeAjax(resposta.headers['content-type']);

      if (resposta.statusCode == 200 &&
          (resposta.headers['content-type'] ?? const <String>[])
              .join(',')
              .toLowerCase()
              .startsWith('text/html')) {
        _registrarAssinaturaResposta(
          status: resposta.statusCode,
          contentType: resposta.headers['content-type']?.join(','),
          body: resposta.data,
        );
      }

      if (resposta.statusCode != 200) {
        final bool rejeicaoF5 = _registrarAssinaturaResposta(
          status: resposta.statusCode,
          contentType: resposta.headers['content-type']?.join(','),
          body: resposta.data,
        );
        return _falhaHttp<Map<String, dynamic>>(
          resposta.statusCode,
          retryable: _statusTransitorio(resposta.statusCode) && !rejeicaoF5,
        );
      }

      final String corpo = _decodificarCorpo(resposta.data ?? []);
      final dynamic json;
      try {
        json = jsonDecode(corpo);
      } on FormatException {
        _incrementarDiagnostico('ajaxJsonInvalido');
        rethrow;
      }
      if (json is! Map<String, dynamic>) {
        _incrementarDiagnostico('ajaxJsonRaizInvalida');
        return ResultadoConsultaPortal<Map<String, dynamic>>.falha(
          categoria: CategoriaFalhaConsultaPortal.respostaInesperada,
          status: resposta.statusCode,
        );
      }
      _incrementarDiagnostico('ajaxJsonValido');
      return ResultadoConsultaPortal<Map<String, dynamic>>.sucesso(
        dados: json,
        status: resposta.statusCode,
      );
    } on DioException catch (erro) {
      return _falhaDio<Map<String, dynamic>>(erro);
    } on FormatException {
      return const ResultadoConsultaPortal<Map<String, dynamic>>.falha(
        categoria: CategoriaFalhaConsultaPortal.respostaInesperada,
        status: null,
      );
    }
  }

  bool _registrarAssinaturaResposta({
    required int? status,
    required String? contentType,
    required List<int>? body,
  }) {
    final AssinaturaRespostaPortal assinatura = _assinaturas.coletar(
      status: status,
      contentType: contentType,
      body: body,
    );
    _incrementarDiagnostico('assinaturaResposta');
    if (assinatura.bodySha256 != null) {
      _incrementarDiagnostico('assinaturaBodyComHash');
    }
    if (assinatura.title != null) {
      _incrementarDiagnostico('assinaturaComTitle');
    }
    if (assinatura.f5Rejected) {
      _incrementarDiagnostico('assinaturaF5Rejected');
    }
    if (assinatura.hasRejectedMarker) {
      _incrementarDiagnostico('assinaturaF5MarkerRejected');
    }
    if (assinatura.hasSupportIdMarker) {
      _incrementarDiagnostico('assinaturaF5MarkerSupportId');
    }
    if (assinatura.supportId != null) {
      _incrementarDiagnostico('assinaturaComSupportId');
    }
    return assinatura.f5Rejected;
  }

  bool _registrarAssinaturaDio(DioException erro) {
    final Response<dynamic>? resposta = erro.response;
    if (resposta == null) return false;
    final Object? corpo = resposta.data;
    final List<int>? bytes = switch (corpo) {
      String texto => utf8.encode(texto),
      List<int> conteudo => conteudo,
      _ => null,
    };
    return _registrarAssinaturaResposta(
      status: resposta.statusCode,
      contentType: resposta.headers['content-type']?.join(','),
      body: bytes,
    );
  }

  Future<ResultadoConsultaPortal<T>> _consultarComRecuperacao<T>(
    Future<ResultadoConsultaPortal<T>> Function() consultar,
    CancelToken? cancelToken,
  ) async {
    bool repetiuSessao = false;
    int retriesFalhaTransitoria = 0;
    int? geracaoAcompanhada;
    try {
      while (true) {
        if (cancelToken?.isCancelled ?? false) {
          return ResultadoConsultaPortal<T>.falha(
            categoria: CategoriaFalhaConsultaPortal.cancelada,
            status: null,
          );
        }
        final int geracaoObservada = _geracao;
        if (geracaoAcompanhada != geracaoObservada) {
          if (geracaoAcompanhada != null) _sairConsulta(geracaoAcompanhada);
          _entrarConsulta(geracaoObservada);
          geracaoAcompanhada = geracaoObservada;
        }
        final ResultadoConsultaPortal<T> resultado = await consultar();
        if (resultado.sucesso ||
            resultado.categoria == CategoriaFalhaConsultaPortal.cancelada) {
          return resultado;
        }
        if (resultado.categoria == CategoriaFalhaConsultaPortal.sessao) {
          _registrarRejeicaoSessao(
            resultado.status,
            aposRenovacao: repetiuSessao,
          );
        }
        if (resultado.categoria == CategoriaFalhaConsultaPortal.sessao &&
            !repetiuSessao) {
          repetiuSessao = true;
          final ResultadoLogin login = await _renovar(geracaoObservada);
          if (!login.autenticada) {
            return ResultadoConsultaPortal<T>.falha(
              categoria: CategoriaFalhaConsultaPortal.sessao,
              status: resultado.status,
            );
          }
          continue;
        }
        if (_ehFalhaTransitoria(resultado) &&
            retriesFalhaTransitoria < _maxRetriesFalhaTransitoria) {
          retriesFalhaTransitoria++;
          await Future<void>.delayed(
            _backoffFalhaTransitoria(retriesFalhaTransitoria),
          );
          continue;
        }
        return resultado;
      }
    } finally {
      if (geracaoAcompanhada != null) _sairConsulta(geracaoAcompanhada);
    }
  }

  bool _ehFalhaTransitoria<T>(ResultadoConsultaPortal<T> resultado) {
    return resultado.categoria == CategoriaFalhaConsultaPortal.transporte ||
        resultado.retryable;
  }

  bool _statusTransitorio(int? status) => switch (status) {
        408 || 500 || 502 || 503 || 504 => true,
        _ => false,
      };

  bool _assinaturaFalhaRetryable(int? status, bool rejeicaoF5) =>
      _statusTransitorio(status) && !rejeicaoF5;

  Duration _backoffFalhaTransitoria(int tentativa) {
    final int base = min(
      _maxBackoffMs,
      _baseBackoffMs * (1 << (tentativa - 1)),
    );
    final double variacao = _jitterPercent / 100;
    final double jitter =
        1 - variacao + _aleatorioRetry.nextDouble() * variacao * 2;
    return Duration(
      milliseconds: min(_maxBackoffMs, (base * jitter).round()),
    );
  }

  final Map<int, int> _consultasAtivasPorGeracao = <int, int>{};

  void _entrarConsulta(int geracao) {
    _consultasAtivasPorGeracao.update(
      geracao,
      (int quantidade) => quantidade + 1,
      ifAbsent: () => 1,
    );
  }

  void _sairConsulta(int geracao) {
    final int restante = (_consultasAtivasPorGeracao[geracao] ?? 1) - 1;
    if (restante > 0) {
      _consultasAtivasPorGeracao[geracao] = restante;
      return;
    }
    _consultasAtivasPorGeracao.remove(geracao);
    _renovacoesPorGeracao.remove(geracao);
  }

  Future<ResultadoLogin> _renovar(int geracaoObservada) {
    if (_geracao != geracaoObservada && _autenticada) {
      return Future<ResultadoLogin>.value(const ResultadoLogin.autenticado());
    }
    return _renovacoesPorGeracao.putIfAbsent(geracaoObservada, () {
      _renovacoesIniciadas++;
      final ({String code, String user, String senha})? credenciais =
          _credenciais;
      final Future<ResultadoLogin> renovacao;
      if (credenciais == null) {
        renovacao = Future<ResultadoLogin>.value(
          const ResultadoLogin.falha(MotivoFalhaLogin.credenciaisInvalidas),
        );
      } else {
        renovacao = _loginCompartilhado(
          code: credenciais.code,
          user: credenciais.user,
          senha: credenciais.senha,
          repetirFalhaRede: true,
        );
      }
      return _contabilizarRenovacao(renovacao);
    });
  }

  Future<ResultadoLogin> _contabilizarRenovacao(
    Future<ResultadoLogin> renovacao,
  ) async {
    try {
      final ResultadoLogin resultado = await renovacao;
      if (resultado.autenticada) {
        _renovacoesSucesso++;
      } else {
        switch (resultado.motivo) {
          case MotivoFalhaLogin.credenciaisInvalidas:
            _renovacoesFalhaCredenciaisInvalidas++;
          case MotivoFalhaLogin.respostaInesperada:
            _renovacoesFalhaRespostaInesperada++;
          case MotivoFalhaLogin.falhaRede:
            _renovacoesFalhaRede++;
          case MotivoFalhaLogin.falhaInterna:
            _renovacoesFalhaInterna++;
          case null:
            _renovacoesFalhaSemMotivo++;
        }
      }
      return resultado;
    } on Object {
      _renovacoesExcecaoInterna++;
      rethrow;
    }
  }

  void _registrarRejeicaoSessao(int? status, {required bool aposRenovacao}) {
    if (status == 401) {
      if (aposRenovacao) {
        _rejeicoes401AposRenovacao++;
      } else {
        _rejeicoes401++;
      }
    } else if (status == 403) {
      if (aposRenovacao) {
        _rejeicoes403AposRenovacao++;
      } else {
        _rejeicoes403++;
      }
    }
  }

  void _incrementarDiagnostico(String chave) {
    _diagnosticoEtapas.update(
      chave,
      (int valor) => valor + 1,
      ifAbsent: () => 1,
    );
  }

  void _registrarStatus(String etapa, int? status) {
    if (status == null) {
      _incrementarDiagnostico('${etapa}SemStatus');
      return;
    }
    _incrementarDiagnostico('$etapa$status');
  }

  void _registrarContentTypeAjax(List<String>? valores) {
    if (valores == null || valores.isEmpty) {
      _incrementarDiagnostico('ajaxContentTypeAusente');
      return;
    }
    final String mime = valores.first.split(';').first.trim().toLowerCase();
    if (mime == 'application/json' || mime.endsWith('+json')) {
      _incrementarDiagnostico('ajaxContentTypeJson');
    } else if (mime.startsWith('text/html')) {
      _incrementarDiagnostico('ajaxContentTypeHtml');
    } else {
      _incrementarDiagnostico('ajaxContentTypeOutro');
    }
  }

  ResultadoConsultaPortal<T> _falhaHttp<T>(
    int? status, {
    bool retryable = false,
  }) {
    return ResultadoConsultaPortal<T>.falha(
      categoria: ehFalhaDeSessaoPortal(status)
          ? CategoriaFalhaConsultaPortal.sessao
          : CategoriaFalhaConsultaPortal.http,
      status: status,
      retryable: retryable,
    );
  }

  ResultadoConsultaPortal<T> _falhaDio<T>(DioException erro) {
    if (CancelToken.isCancel(erro)) {
      return ResultadoConsultaPortal<T>.falha(
        categoria: CategoriaFalhaConsultaPortal.cancelada,
        status: null,
      );
    }
    final int? status = erro.response?.statusCode;
    final bool rejeicaoF5 = _registrarAssinaturaDio(erro);
    return ResultadoConsultaPortal<T>.falha(
      categoria: ehFalhaDeSessaoPortal(status)
          ? CategoriaFalhaConsultaPortal.sessao
          : _ehFalhaTransporte(erro)
              ? CategoriaFalhaConsultaPortal.transporte
              : CategoriaFalhaConsultaPortal.http,
      status: status,
      retryable: _assinaturaFalhaRetryable(status, rejeicaoF5),
    );
  }

  bool _ehFalhaTransporte(DioException erro) => switch (erro.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };

  String _decodificarCorpo(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  List<String> _dividirCarteirinha(String carteirinha) {
    final int tamanhoEsperado = _tamanhosSegmentosCarteirinha.fold(
      0,
      (soma, parte) => soma + parte,
    );

    if (carteirinha.length != tamanhoEsperado) {
      throw FormatException(
        'A carteirinha deve ter exatamente $tamanhoEsperado digitos '
        '(segmentos de ${_tamanhosSegmentosCarteirinha.join('-')}).',
      );
    }

    final List<String> partes = [];
    int inicio = 0;
    for (final int tamanho in _tamanhosSegmentosCarteirinha) {
      partes.add(carteirinha.substring(inicio, inicio + tamanho));
      inicio += tamanho;
    }
    return partes;
  }

  Future<void> encerrar() async {
    _dio.close();
  }
}

class _SemaforoRequisicoes {
  _SemaforoRequisicoes(this.limite);

  final int limite;
  int _ativas = 0;
  int _picoAtivas = 0;
  int _picoEspera = 0;
  int _totalEspera = 0;
  final List<Completer<void>> _espera = <Completer<void>>[];

  Map<String, int> get diagnostico => <String, int>{
        'limite': limite,
        'ativasAgora': _ativas,
        'picoAtivas': _picoAtivas,
        'aguardandoAgora': _espera.length,
        'picoAguardando': _picoEspera,
        'totalAguardas': _totalEspera,
      };

  Future<T> executar<T>(
    Future<T> Function() operacao, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw _erroCancelamento(cancelToken!);
    }

    bool possuiVaga = false;
    if (_ativas < limite && _espera.isEmpty) {
      _ativas++;
      if (_ativas > _picoAtivas) _picoAtivas = _ativas;
      possuiVaga = true;
    } else {
      final Completer<void> livre = Completer<void>();
      _espera.add(livre);
      _totalEspera++;
      if (_espera.length > _picoEspera) _picoEspera = _espera.length;
      try {
        if (cancelToken == null) {
          await livre.future;
        } else {
          await Future.any<void>(<Future<void>>[
            livre.future,
            cancelToken.whenCancel.then<void>(
              (_) => throw _erroCancelamento(cancelToken),
            ),
          ]);
        }
        possuiVaga = livre.isCompleted;
      } finally {
        _espera.remove(livre);
      }
    }

    if (cancelToken?.isCancelled ?? false) {
      if (possuiVaga) _liberarVaga();
      throw _erroCancelamento(cancelToken!);
    }
    try {
      return await operacao();
    } finally {
      _liberarVaga();
    }
  }

  void _liberarVaga() {
    if (_espera.isNotEmpty) {
      _espera.removeAt(0).complete();
    } else {
      _ativas--;
    }
  }

  DioException _erroCancelamento(CancelToken cancelToken) =>
      cancelToken.cancelError ??
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );
}
