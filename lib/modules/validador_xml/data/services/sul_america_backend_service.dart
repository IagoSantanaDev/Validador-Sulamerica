import '../../../../globals/network/dio_client.dart';
import '../../../../globals/network/result.dart';
import '../models/resultado_consulta_beneficiario.dart';

/// Cliente dos endpoints do backend intermediário (proxy do portal SulAmérica).
///
/// Substitui as chamadas diretas ao portal (o antigo `SulAmericaService`).
/// O backend resolve CORS e mantém a sessão do portal no servidor; o app
/// aqui só troca JSON com o proxy:
///
/// - `POST /api/login`            → `{token}`
/// - `POST /api/beneficiario`     → `{status, elegivel, rotuloElegibilidade, html}`
/// - `GET  /api/autorizacao`      → JSON do portal (registros/paginacao)
/// - `GET  /api/status`           → health check
///
/// Credenciais do portal são enviadas apenas no login e nunca armazenadas.
class SulAmericaBackendService {
  SulAmericaBackendService(this._dio);

  final DioClient _dio;

  /// Autentica no portal via backend e devolve o token de sessão (32 hex).
  Future<Result<String>> login({
    required String code,
    required String user,
    required String senha,
  }) {
    return _dio.post<String>(
      '/api/login',
      corpo: {'code': code, 'user': user, 'senha': senha},
      parser: (dados) => (dados as Map)['token'] as String,
    );
  }

  /// Consulta a elegibilidade do beneficiário via backend.
  ///
  /// [carteira] deve conter os 20 dígitos (segmentos 3-5-4-4-4,
  /// ex.: 58201824004384300010). O proxy divide e valida o formato.
  Future<Result<ResultadoConsultaBeneficiario>> consultarBeneficiario({
    required String token,
    required String carteira,
  }) {
    return _dio.post<ResultadoConsultaBeneficiario>(
      '/api/beneficiario',
      corpo: {'token': token, 'carteira': carteira},
      parser: (dados) =>
          ResultadoConsultaBeneficiario.fromJson(dados as Map<String, dynamic>),
    );
  }

  /// Consulta a autorização de uma solicitação VPP (JSON do portal).
  Future<Result<Map<String, dynamic>>> autorizacaoVpp({
    required String token,
    required String numeroVpp,
  }) {
    return _dio.get<Map<String, dynamic>>(
      '/api/autorizacao',
      parametrosConsulta: {'token': token, 'numeroVpp': numeroVpp},
      parser: (dados) => (dados as Map).cast<String, dynamic>(),
    );
  }

  /// Health check do proxy (número de sessões ativas, entre outros).
  Future<Result<Map<String, dynamic>>> status() {
    return _dio.get<Map<String, dynamic>>(
      '/api/status',
      parser: (dados) => (dados as Map).cast<String, dynamic>(),
    );
  }
}