import 'package:dio/dio.dart';

import 'app_exception.dart';
import 'interceptors/logging_interceptor.dart';
import 'network_constants.dart';
import 'result.dart';

class DioClient {
  DioClient({
    required String baseUrl,
    Dio? dio,
    List<Interceptor> interceptoresExtras = const [],
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: NetworkConstants.connectTimeout,
      receiveTimeout: NetworkConstants.receiveTimeout,
      sendTimeout: NetworkConstants.sendTimeout,
    );
    _dio.interceptors.addAll([LoggingInterceptor(), ...interceptoresExtras]);
  }

  final Dio _dio;

  Dio get instancia => _dio;

  Future<Result<T>> get<T>(
    String caminho, {
    Map<String, dynamic>? parametrosConsulta,
    required T Function(dynamic dados) parser,
  }) {
    return _executar(
      () => _dio.get(caminho, queryParameters: parametrosConsulta),
      parser,
    );
  }

  Future<Result<T>> post<T>(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? parametrosConsulta,
    required T Function(dynamic dados) parser,
  }) {
    return _executar(
      () => _dio.post(
        caminho,
        data: corpo,
        queryParameters: parametrosConsulta,
      ),
      parser,
    );
  }

  Future<Result<T>> put<T>(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? parametrosConsulta,
    required T Function(dynamic dados) parser,
  }) {
    return _executar(
      () => _dio.put(
        caminho,
        data: corpo,
        queryParameters: parametrosConsulta,
      ),
      parser,
    );
  }

  Future<Result<T>> patch<T>(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? parametrosConsulta,
    required T Function(dynamic dados) parser,
  }) {
    return _executar(
      () => _dio.patch(
        caminho,
        data: corpo,
        queryParameters: parametrosConsulta,
      ),
      parser,
    );
  }

  Future<Result<T>> delete<T>(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? parametrosConsulta,
    required T Function(dynamic dados) parser,
  }) {
    return _executar(
      () => _dio.delete(
        caminho,
        data: corpo,
        queryParameters: parametrosConsulta,
      ),
      parser,
    );
  }

  Future<Result<T>> _executar<T>(
    Future<Response<dynamic>> Function() requisicao,
    T Function(dynamic dados) parser,
  ) async {
    try {
      final Response<dynamic> resposta = await requisicao();
      return Result.success(parser(resposta.data));
    } on DioException catch (erro) {
      return Result.failure(_mapearErro(erro));
    } catch (erro) {
      return Result.failure(ErroDesconhecidoException(erro.toString()));
    }
  }

  AppException _mapearErro(DioException erro) {
    return switch (erro.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        const RequisicaoExpiradaException(),
      DioExceptionType.connectionError => const SemConexaoException(),
      DioExceptionType.cancel => const RequisicaoCanceladaException(),
      DioExceptionType.badResponse => _mapearRespostaComErro(erro),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown =>
        ErroDesconhecidoException(erro.message ?? 'Erro desconhecido'),
    };
  }

  AppException _mapearRespostaComErro(DioException erro) {
    final int? statusCode = erro.response?.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      return const NaoAutorizadoException();
    }
    if (statusCode == 404) {
      return const RecursoNaoEncontradoException();
    }
    return ErroServidorException(
      statusCode: statusCode,
      mensagem: 'O servidor retornou um erro (status $statusCode).',
    );
  }
}