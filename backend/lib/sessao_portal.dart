import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logger/logger.dart';

import 'util_texto.dart';

/// Motivo da falha ao autenticar no portal (para o proxy distinguir
/// credencial inválida de bloqueio/resposta inesperada).
enum MotivoFalhaLogin { credenciaisInvalidas, respostaInesperada, falhaRede }

class ResultadoLogin {
  const ResultadoLogin.autenticado()
      : autenticada = true,
        motivo = null,
        detalhe = null;

  const ResultadoLogin.falha(this.motivo, {this.detalhe}) : autenticada = false;

  final bool autenticada;
  final MotivoFalhaLogin? motivo;

  /// Contexto da falha (ex.: tipo de DioException) para diagnóstico.
  final String? detalhe;
}

/// Cliente do portal Lumis. O login exige GET inicial na pagina (senão o F5
/// ASM responde 403 sem o cookie NSC_*), e a consulta de senha exige sessão (401 sem login).
class SessaoPortal {
  SessaoPortal({
    Dio? dio,
    CookieJar? cookieJar,
    Logger? logger,
  })  : _dio = dio ?? Dio(),
        _cookieJar = cookieJar ?? CookieJar(),
        _logger = logger ?? Logger() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
      // O login retorna 302 (Location: /prestador/) apos autenticar; o
      // redirect deve ser seguido manualmente (GET) para chegar na pagina
      // autenticada e confirmar a sessao.
      followRedirects: false,
    );
    // Workaround F5/CDN: o portal envia cadeia com cert self-signed que o
    // root store do container rejeita (CERTIFICATE_VERIFY_FAILED). O
    // badCertificateCallback do HttpClient tolera a cadeia e o
    // validateCertificate avalia o certificado final — ambos restritos ao
    // host do portal; qualquer outro destino mantém a verificação padrão.
    // Só aplica quando o Dio não foi injetado.
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient cliente = HttpClient();
          cliente.badCertificateCallback = aceitarCertificadoDoPortal;
          return cliente;
        },
        validateCertificate: _validarCertificadoDoPortal,
      );
    }
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static const String hostPortal = 'saude.sulamericaseguros.com.br';

  /// Aceita o certificado somente quando o host é o próprio portal (caso
  /// F5/CDN com cadeia não confiável pela CA pública). Qualquer outro host
  /// permanece com a validação padrão.
  static bool aceitarCertificadoDoPortal(
    X509Certificate? certificate,
    String host,
    int port,
  ) =>
      host == hostPortal;

  /// `validateCertificate` do adapter: chamado apenas quando a validação CA
  /// falhou; registra e aceita o cert do portal (uso exclusivo de integração).
  bool _validarCertificadoDoPortal(
    X509Certificate? certificate,
    String host,
    int port,
  ) {
    if (!aceitarCertificadoDoPortal(certificate, host, port)) return false;
    _logger.w(
      'TLS do portal nao verificado pela CA publica (cadeia com self-signed); '
      'aceitando certificado apresentado por $host para a integracao.',
    );
    return true;
  }

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
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

  // Segmentos reais da carteirinha (3-5-4-4-4 digitos); nao dividir em
  // partes iguais — o portal exige os segmentos originais da numeracao.
  static const List<int> _tamanhosSegmentosCarteirinha = [3, 5, 4, 4, 4];

  final Dio _dio;
  final CookieJar _cookieJar;
  final Logger _logger;

  bool _autenticada = false;
  String _codigoPrestador = '100000015513';

  /// Status HTTP da última falha de consulta; null quando a última consulta
  /// foi bem-sucedida ou falhou por rede/timeout. Usado para distinguir
  /// sessão rejeitada (401/403) de falha transitória e renovar o login.
  static const int _statusFalhaSessao = 401;
  int? _ultimoStatusFalha;

  bool get autenticada => _autenticada;
  int? get ultimoStatusFalha => _ultimoStatusFalha;

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
  }) async {
    _ultimoStatusFalha = null;
    try {
      final Response<String> pagina = await _dio.get<String>(
        _urlLogin,
        options: Options(
          headers: _headersNavegador,
          responseType: ResponseType.plain,
        ),
      );
      if (pagina.statusCode != 200) {
        _logger.e(
          'GET inicial do login retornou HTTP ${pagina.statusCode} '
          '(possivel bloqueio do F5 ASM).',
        );
        return const ResultadoLogin.falha(
          MotivoFalhaLogin.respostaInesperada,
        );
      }

      final Map<String, String> campos = {
        ..._camposLogin,
        'code': code,
        'user': user,
        'senha': senha,
      };

      final Response<String> resposta = await _dio.post<String>(
        _urlLogin,
        data: Uri(queryParameters: campos).query,
        options: Options(
          headers: _headersPost,
          responseType: ResponseType.plain,
        ),
      );

      // 302 = login aceito: o portal redireciona para /prestador/.
      // Segue o redirect via GET (com a sessao) para confirmar a pagina
      // autenticada — comportamento identico ao de um navegador.
      if (resposta.statusCode == 302) {
        final String? destino = resposta.headers.value('location');
        if (destino == null) {
          _logger.e('Login Lumis: 302 sem Location.');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.respostaInesperada,
          );
        }
        final Uri uri = Uri.parse(destino);
        final String urlFinal = uri.hasScheme
            ? destino
            : 'https://saude.sulamericaseguros.com.br$destino';
        final Response<String> pos = await _dio.get<String>(
          urlFinal,
          options: Options(
            headers: {..._headersNavegador, 'Referer': _urlLogin},
            responseType: ResponseType.plain,
          ),
        );
        if (pos.statusCode != 200) {
          _logger.e('Login Lumis: redirect final HTTP ${pos.statusCode}.');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.respostaInesperada,
          );
        }
        final bool paginaAutenticada =
            (pos.data ?? '').toLowerCase().contains('logout');
        _codigoPrestador = code;
        _autenticada = paginaAutenticada;
        final int quantidadeCookies =
            (await _cookieJar.loadForRequest(Uri.parse(_urlLogin))).length;
        _logger.i(
          'Login Lumis: 302 -> $urlFinal | '
          'pagina autenticada: $_autenticada | '
          'sessao: $quantidadeCookies cookies.',
        );
        if (!paginaAutenticada) {
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.credenciaisInvalidas,
          );
        }
        return const ResultadoLogin.autenticado();
      }

      if (resposta.statusCode != 200) {
        _logger.e('Login Lumis retornou HTTP ${resposta.statusCode}.');
        return const ResultadoLogin.falha(
          MotivoFalhaLogin.respostaInesperada,
        );
      }

      // HTTP 200 sem redirect: o portal devolveu a propria pagina de login
      // (credenciais rejeitadas) ou uma pagina de erro — confirma logando
      // um trecho do corpo para diagnostico.
      final String corpo = resposta.data ?? '';
      _autenticada = corpo.toLowerCase().contains('logout');
      final int quantidadeCookies =
          (await _cookieJar.loadForRequest(Uri.parse(_urlLogin))).length;
      _logger.i(
        'Login Lumis: HTTP ${resposta.statusCode} | '
        'pagina autenticada: $_autenticada | '
        'sessao: $quantidadeCookies cookies.',
      );
      if (!_autenticada) {
        _logger.w(
          'Login Lumis: corpo sem sessao autenticada — trecho: '
          '${resumirTexto(corpo)}',
        );
        return const ResultadoLogin.falha(
          MotivoFalhaLogin.credenciaisInvalidas,
        );
      }
      return const ResultadoLogin.autenticado();
    } on DioException catch (erro) {
      _logger.e('Falha de rede no login: ${erro.message}');
      return ResultadoLogin.falha(
        MotivoFalhaLogin.falhaRede,
        detalhe: _detalheDioException(erro),
      );
    } catch (erro) {
      _logger.e('Falha inesperada no login: $erro');
      return ResultadoLogin.falha(
        MotivoFalhaLogin.falhaRede,
        detalhe: erro.toString(),
      );
    }
  }

  String _detalheDioException(DioException erro) {
    final int? status = erro.response?.statusCode;
    final String tipo = erro.type.name;
    return status != null ? '$tipo (HTTP $status): ${erro.message}' : tipo;
  }


  Future<String?> consultarBeneficiario({
    required String carteirinhaCompleta,
  }) async {
    if (!_autenticada) {
      _ultimoStatusFalha = _statusFalhaSessao;
      _logger.e('Consulta nao enviada: sessao nao estabelecida.');
      return null;
    }

    try {
      final List<String> partes =
          _dividirCarteirinha(carteirinhaCompleta);
      final Map<String, String> campos = {..._camposConsulta};
      for (int indice = 0; indice < partes.length; indice++) {
        campos['codigo-beneficiario-${indice + 1}'] = partes[indice];
      }

      final Response<String> resposta = await _dio.post<String>(
        _urlConsulta,
        data: Uri(queryParameters: campos).query,
        options: Options(
          headers: _headersPost,
          responseType: ResponseType.plain,
        ),
      );

      // A consulta valida retorna 302 para a pagina de resultado
      // (elegibilidade-resultado.htm). Segue o redirect via GET (com a
      // sessao) e devolve o HTML final — comportamento de navegador.
      if (resposta.statusCode == 302) {
        final String? destino = resposta.headers.value('location');
        if (destino == null) {
          _logger.e('Consulta: 302 sem Location.');
          _ultimoStatusFalha = resposta.statusCode;
          return null;
        }
        final Uri uri = Uri.parse(destino);
        final String urlFinal = uri.hasScheme
            ? destino
            : 'https://saude.sulamericaseguros.com.br$destino';
        final Response<String> pos = await _dio.get<String>(
          urlFinal,
          options: Options(
            headers: {..._headersNavegador, 'Referer': _urlConsulta},
            responseType: ResponseType.plain,
          ),
        );
        if (pos.statusCode != 200) {
          _logger.e('Consulta: redirect final HTTP ${pos.statusCode}.');
          _ultimoStatusFalha = pos.statusCode;
          return null;
        }
        _ultimoStatusFalha = null;
        return pos.data;
      }

      if (resposta.statusCode != 200) {
        _ultimoStatusFalha = resposta.statusCode;
        _logger.e('Consulta de beneficiario: HTTP ${resposta.statusCode}.');
        return null;
      }
      _ultimoStatusFalha = null;
      return resposta.data;
    } on FormatException catch (erro) {
      _logger.e('Carteirinha invalida: ${erro.message}');
      _ultimoStatusFalha = null;
      return null;
    } on DioException catch (erro) {
      _logger.e(
        'Falha de rede na consulta de beneficiario: ${erro.message}',
      );
      _ultimoStatusFalha = null;
      return null;
    } catch (erro) {
      _logger.e('Falha inesperada na consulta: $erro');
      _ultimoStatusFalha = null;
      return null;
    }
  }


  Future<Map<String, dynamic>?> consultarSenha({
    required String senha,
  }) async {
    if (!_autenticada) {
      _ultimoStatusFalha = _statusFalhaSessao;
      _logger.e('Consulta de senha nao enviada: sessao nao estabelecida.');
      return null;
    }

    try {
      final Response<List<int>> resposta = await _dio.get<List<int>>(
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
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json,text/plain,*/*',
            'Referer': _urlLogin,
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (resposta.statusCode != 200) {
        _ultimoStatusFalha = resposta.statusCode;
        _logger.e('Consulta de senha: HTTP ${resposta.statusCode}.');
        return null;
      }

      // O portal devolve text/plain com charset ISO-8859-1; tenta UTF-8
      // primeiro e cai para Latin-1 (mesma heuristica do app).
      final String corpo = _decodificarCorpo(resposta.data ?? []);
      final dynamic json = jsonDecode(corpo);
      if (json is! Map<String, dynamic>) {
        _logger.e('Consulta de senha: JSON inesperado no corpo.');
        return null;
      }
      return json;
    } on DioException catch (erro) {
      _logger.e('Falha de rede na consulta de senha: ${erro.message}');
      return null;
    } catch (erro) {
      _logger.e('Falha inesperada na consulta de senha: $erro');
      return null;
    }
  }

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

  /// Libera as conexões HTTP desta sessão (usada para sessões extras
  /// descartáveis após o lote; a sessão base permanece para o cliente).
  Future<void> encerrar() async {
    _dio.close();
  }
}