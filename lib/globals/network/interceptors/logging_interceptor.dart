import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  static const int _maxCaracteresCorpo = 180;
  static const Set<String> _rotasComDadosSensives = {
    '/api/sessoes',
    '/api/lotes',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP] -> ${options.method} ${_urlDe(options)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[HTTP] <- ${response.requestOptions.method} '
        '${_urlDe(response.requestOptions)} -> ${response.statusCode}',
      );

      if (!_corpoContemDadosSensives(response.requestOptions)) {
        _logarCorpo('resposta', response.data);
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final int? status = err.response?.statusCode;

      debugPrint(
        '[HTTP] x ${err.requestOptions.method} '
        '${_urlDe(err.requestOptions)} -> ${status ?? err.type}',
      );
      _logarCorpoSemPii(err.requestOptions, 'erro', err.response?.data);
    }
    handler.next(err);
  }

  void _logarCorpoSemPii(RequestOptions options, String rotulo, dynamic dados) {
    if (_corpoContemDadosSensives(options)) return;
    _logarCorpo(rotulo, dados);
  }

  String _urlDe(RequestOptions options) => '${options.baseUrl}${options.path}';

  bool _corpoContemDadosSensives(RequestOptions options) =>
      _rotasComDadosSensives.contains(options.uri.path);

  void _logarCorpo(String rotulo, dynamic dados) {
    final String? texto = _resumir(dados);
    if (texto == null) return;

    debugPrint('[HTTP] $rotulo: $texto');
  }

  String? _resumir(dynamic dados) {
    if (dados == null) return null;
    String texto;
    if (dados is String) {
      texto = dados;
    } else {
      try {
        texto = const JsonEncoder.withIndent('  ').convert(dados);
      } catch (_) {
        texto = dados.toString();
      }
    }
    if (texto.length > _maxCaracteresCorpo) {
      texto = '${texto.substring(0, _maxCaracteresCorpo)}…';
    }
    return texto;
  }
}
