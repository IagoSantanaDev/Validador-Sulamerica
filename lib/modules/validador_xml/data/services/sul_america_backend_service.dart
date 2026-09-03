import '../../../../globals/network/dio_client.dart';
import '../../../../globals/network/result.dart';
import '../models/resultado_consulta_beneficiario.dart';

class SulAmericaBackendService {
  SulAmericaBackendService(this._dio);

  final DioClient _dio;

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

  Future<Result<Map<String, dynamic>>> status() {
    return _dio.get<Map<String, dynamic>>(
      '/api/status',
      parser: (dados) => (dados as Map).cast<String, dynamic>(),
    );
  }
}