import 'package:dio/dio.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logar(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logar(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _logar(RequestOptions options, int? status) {
    final String metodo = options.method.padRight(6);
    final String base = options.baseUrl;
    final String caminho = options.path;
    // ignore: avoid_print
    print('$metodo $base$caminho -> $status');
  }
}