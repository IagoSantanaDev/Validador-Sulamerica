import '../../../../globals/network/dio_client.dart';
import '../../../../globals/network/result.dart';
import '../models/consulta_lote.dart';
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

  Future<Result<Map<String, dynamic>>> consultarSenha({
    required String token,
    required String senha,
  }) {
    return _dio.get<Map<String, dynamic>>(
      '/api/autorizacao',
      parametrosConsulta: { 'token': token, 'senha': senha},
      parser: (dados) => (dados as Map).cast<String, dynamic>(),
    );
  }

  Future<Result<Map<String, dynamic>>> status() {
    return _dio.get<Map<String, dynamic>>(
      '/api/status',
      parser: (dados) => (dados as Map).cast<String, dynamic>(),
    );
  }

  /// Consulta em lote: envia todas as solicitações (elegibilidade/senha) de uma
  /// única vez ao backend, que executa contra o portal e devolve os resultados.
  Future<Result<List<ResultadoConsultaLote>>> consultarLote({
    required String token,
    required List<ConsultaLoteItem> consultas,
  }) {
    return _dio.post<List<ResultadoConsultaLote>>(
      '/api/consultas',
      corpo: {
        'token': token,
        'consultas': [
          for (final ConsultaLoteItem item in consultas)
            {'tipo': item.tipo.name, 'chave': item.chave},
        ],
      },
      parser: (dados) {
        final dynamic resultados = (dados as Map)['resultados'];
        if (resultados is! List) return const [];
        return resultados
            .map(
              (r) => ResultadoConsultaLote.fromJson(
                r as Map<String, dynamic>,
              ),
            )
            .toList();
      },
    );
  }
}