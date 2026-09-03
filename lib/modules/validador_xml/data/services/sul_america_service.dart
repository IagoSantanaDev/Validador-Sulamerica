import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logger/logger.dart';

/// Integra os formulários Lumis que exigem uma sessão autenticada.
///
/// [camposLogin] e [camposConsulta] devem conter os valores estáticos
/// copiados dos formulários atuais do portal. Os campos dinâmicos são
/// adicionados pelo serviço e sobrescrevem valores com o mesmo nome.
///
/// A instância deve ser reutilizada entre [login] e
/// [consultarBeneficiario]. O [CookieJar] mantém os cookies da sessão e o
/// [CookieManager] os envia automaticamente nas requisições seguintes.
///
/// Divergência deliberada do fluxo original com `package:http` + cópia
/// manual do header `set-cookie`: quando o portal envia mais de um
/// `Set-Cookie` (comum em login), `HttpHeaders`/`http.Response.headers`
/// concatena os valores com vírgula — e o atributo `Expires` de um cookie
/// (ex.: `Expires=Wed, 21 Oct 2026 07:28:00 GMT`) também contém vírgula,
/// o que corrompe o parsing manual. `CookieJar` + `CookieManager` tratam
/// isso corretamente (múltiplos cookies, expiração, domínio/path), então
/// a sessão fica mais confiável sem mudar o formato da requisição
/// (mesmo endpoint, mesmo Content-Type, mesmos campos de formulário).
class SulAmericaService {
  SulAmericaService({
    required Map<String, String> camposLogin,
    required Map<String, String> camposConsulta,
    Dio? dio,
    CookieJar? cookieJar,
    Logger? logger,
  })  : _camposLogin = Map.unmodifiable(camposLogin),
        _camposConsulta = Map.unmodifiable(camposConsulta),
        _dio = dio ?? Dio(),
        _cookieJar = cookieJar ?? CookieJar(),
        _logger = logger ?? Logger() {
    _dio.options = _dio.options.copyWith(
      contentType: Headers.formUrlEncodedContentType,
      validateStatus: (_) => true,
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static const String _urlAutorizador =
      'https://saude.sulamericaseguros.com.br';

  /// Tamanho, em dígitos, de cada segmento da carteirinha, na ordem em que
  /// são enviados como codigo-beneficiario-1..5. Os segmentos NÃO têm o
  /// mesmo tamanho (ex.: 582/01824/0043/8430/0010 = 3-5-4-4-4 dígitos),
  /// então a carteirinha não pode ser dividida em partes iguais.
  static const List<int> _tamanhosSegmentosCarteirinha = [3, 5, 4, 4, 4];
  static const String _contentType = 'application/x-www-form-urlencoded';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  final Map<String, String> _camposLogin;
  final Map<String, String> _camposConsulta;
  final Dio _dio;
  final CookieJar _cookieJar;
  final Logger _logger;

  /// Autentica no portal e mantém o cookie de sessão no [CookieJar].
  Future<bool> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    try {
      final Map<String, String> campos = {
        ..._camposLogin,
        'code': code,
        'user': user,
        'senha': senha,
      };
      _validarCamposLumis(campos, 'login');

      // A URL raiz (sem subdomínio) gera ERR_CERT_COMMON_NAME_INVALID —
      // o destino real é sempre a lumFormAction do próprio formulário
      // (subdomínio saude. + lumPageId da página de login).
      final String urlDestino = campos['lumFormAction']!;

      final Response<dynamic> resposta = await _dio.post<dynamic>(
        urlDestino,
        data: _codificarFormulario(campos),
        options: Options(
          contentType: _contentType,
          headers: {'User-Agent': _userAgent},
        ),
      );

      final bool possuiCookie = (await _cookieJar.loadForRequest(
        Uri.parse(urlDestino),
      )).isNotEmpty;
      if (resposta.statusCode != 200) {
        _registrarStatus('login', resposta.statusCode);
        return false;
      }

      _logger.i('Login Lumis concluído; cookie de sessão: $possuiCookie.');
      return true;
    } on DioException catch (erro) {
      _logger.e('Falha de rede no login Lumis: ${erro.message}');
      return false;
    } catch (erro) {
      _logger.e('Falha inesperada no login Lumis: $erro');
      return false;
    }
  }

  /// Consulta a autorização da solicitação VPP.
  ///
  /// Esta operação é independente de [login]. O chamador deve executá-la
  /// antes de autenticar quando o fluxo exigir essa validação.
  Future<bool> verificarSolicitacaoAutorizada({
    required String numeroVpp,
  }) async {
    try {
      final Response<dynamic> resposta = await _dio.get<dynamic>(
        '$_urlAutorizador/ajax-controller.jsp',
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
          'numero-vpp': numeroVpp,
          'codigo-prestador': '100000015513',
          'codigo-solicitacao': '',
          'tipo-solicitacao.codigo': '',
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'User-Agent': _userAgent},
        ),
      );

      if (resposta.statusCode != 200 || resposta.data is! Map) {
        _registrarStatus('consulta de autorização VPP', resposta.statusCode);
        return false;
      }

      final dynamic registros = (resposta.data as Map)['registros'];
      if (registros is! List) return false;
      return registros.any((dynamic registro) {
        if (registro is! Map) return false;
        final dynamic status = registro['status_solicitacao'];
        return status is Map && status['descricao'] == 'Autorizado';
      });
    } on DioException catch (erro) {
      _logger.e('Falha de rede na consulta de autorização VPP: ${erro.message}');
      return false;
    } catch (erro) {
      _logger.e('Falha inesperada na consulta de autorização VPP: $erro');
      return false;
    }
  }

  /// Consulta o beneficiário usando a sessão criada por [login].
  ///
  /// A carteirinha é repartida nos segmentos de [_tamanhosSegmentosCarteirinha]
  /// e enviada nos campos `codigo-beneficiario-1` até `codigo-beneficiario-5`.
  /// Retorna o HTML bruto em respostas HTTP 200 e `null` nos demais casos.
  Future<String?> consultarBeneficiario({
    required String carteirinhaCompleta,
  }) async {
    try {
      final String urlDestino = _camposConsulta['lumFormAction']!;
      final bool possuiSessao = (await _cookieJar.loadForRequest(
        Uri.parse(urlDestino),
      )).isNotEmpty;
      if (!possuiSessao) {
        _logger.e('Consulta não enviada: não há cookie de sessão Lumis.');
        return null;
      }

      final List<String> partes = _dividirCarteirinha(carteirinhaCompleta);
      final Map<String, String> campos = {..._camposConsulta};
      for (int indice = 0; indice < partes.length; indice++) {
        campos['codigo-beneficiario-${indice + 1}'] = partes[indice];
      }
      _validarCamposLumis(campos, 'consulta');

      final Response<String> resposta = await _dio.post<String>(
        urlDestino,
        data: _codificarFormulario(campos),
        options: Options(
          contentType: _contentType,
          responseType: ResponseType.plain,
          headers: {'User-Agent': _userAgent},
        ),
      );

      if (resposta.statusCode != 200) {
        _registrarStatus('consulta de beneficiário', resposta.statusCode);
        return null;
      }
      return resposta.data;
    } on FormatException catch (erro) {
      _logger.e('Carteirinha inválida: ${erro.message}');
      return null;
    } on DioException catch (erro) {
      _logger.e('Falha de rede na consulta de beneficiário: ${erro.message}');
      return null;
    } catch (erro) {
      _logger.e('Falha inesperada na consulta de beneficiário: $erro');
      return null;
    }
  }

  String _codificarFormulario(Map<String, String> campos) {
    return Uri(queryParameters: campos).query;
  }

  /// Divide a carteirinha nos segmentos fixos definidos em
  /// [_tamanhosSegmentosCarteirinha] (3-5-4-4-4 dígitos), na ordem em que
  /// aparecem — NÃO em partes de tamanho igual, pois o portal exige os
  /// segmentos originais da numeração (ex.: 582/01824/0043/8430/0010).
  List<String> _dividirCarteirinha(String carteirinha) {
    final int tamanhoEsperado =
        _tamanhosSegmentosCarteirinha.fold(0, (soma, parte) => soma + parte);

    if (carteirinha.length != tamanhoEsperado) {
      throw FormatException(
        'A carteirinha deve ter exatamente $tamanhoEsperado dígitos '
        '(segmentos de ${_tamanhosSegmentosCarteirinha.join("-")}).',
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

  void _validarCamposLumis(Map<String, String> campos, String operacao) {
    const List<String> obrigatorios = [
      'destId',
      'destType',
      'lumFromForm',
      'lumFormAction',
      'doui_processActionId',
      'doui_fromForm',
      'lumII',
    ];
    final bool incompleto = obrigatorios.any(
      (campo) => !campos.containsKey(campo) || campos[campo]!.isEmpty,
    );
    if (incompleto) {
      throw StateError(
        'Campos estáticos Lumis incompletos para a operação de $operacao.',
      );
    }
  }

  void _registrarStatus(String operacao, int? statusCode) {
    _logger.e(
      'Falha na $operacao Lumis: o servidor retornou HTTP $statusCode.',
    );
  }
}
