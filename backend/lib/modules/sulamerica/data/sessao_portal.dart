import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logger/logger.dart';

import 'package:validador_backend/util_texto.dart';

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
      followRedirects: false,
    );

    // Sem `createHttpClient`: o `HttpClient` padrao valida a cadeia do
    // certificado e o hostname. `validateCertificate` so roda depois disso
    // (ver doc do dio), servindo so como registro do host esperado.
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
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
  bool validarCertificado(
    X509Certificate? certificate,
    String host,
    int port,
  ) {
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

  final Dio _dio;
  final CookieJar _cookieJar;
  final Logger _logger;

  bool _autenticada = false;
  String _codigoPrestador = '100000015513';

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

      if (resposta.statusCode == 302) {
        final String? urlFinal = _urlDeRedirect(resposta);
        if (urlFinal == null) {
          _logger.e('Login Lumis: 302 sem Location.');
          return const ResultadoLogin.falha(
            MotivoFalhaLogin.respostaInesperada,
          );
        }
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
      _logger.e('Falha de rede no login: ${erro.type.name} - ${erro.message}');
      return ResultadoLogin.falha(
        MotivoFalhaLogin.falhaRede,
        detalhe: _detalheDioException(erro),
      );
    } catch (erro) {
      _logger.e('Falha inesperada no login: $erro');
      return ResultadoLogin.falha(
        MotivoFalhaLogin.falhaInterna,
        detalhe: erro.toString(),
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

  Future<String?> consultarBeneficiario({
    required String carteirinhaCompleta,
  }) async {
    if (!_autenticada) {
      _ultimoStatusFalha = _statusFalhaSessao;
      _logger.e('Consulta nao enviada: sessao nao estabelecida.');
      return null;
    }

    try {
      final List<String> partes = _dividirCarteirinha(carteirinhaCompleta);
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

      if (resposta.statusCode == 302) {
        final String? urlFinal = _urlDeRedirect(resposta);
        if (urlFinal == null) {
          _logger.e('Consulta: 302 sem Location.');
          _ultimoStatusFalha = resposta.statusCode;
          return null;
        }
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

  Future<void> encerrar() async {
    _dio.close();
  }
}
