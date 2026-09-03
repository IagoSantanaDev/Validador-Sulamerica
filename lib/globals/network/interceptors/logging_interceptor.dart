import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Loga apenas método, URL e status — nunca headers de autenticação nem
/// corpo da requisição/resposta, para não vazar dados sensíveis em log.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _logger.i('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.i('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✕ ${err.requestOptions.method} ${err.requestOptions.uri} '
      '(${err.type.name})',
    );
    handler.next(err);
  }
}
