import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  static const int _maxCaracteresCorpo = 180;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[HTTP] -> ${options.method} ${_urlDe(options)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[HTTP] <- ${response.requestOptions.method} '
        '${_urlDe(response.requestOptions)} -> ${response.statusCode}',
      );
      // O corpo do login contém o token da sessão — não logar; as respostas
      // de consulta carregam dados do beneficiário (carteira/senha) — PII.
      if (!_urlDe(response.requestOptions).contains('/api/login') &&
          !_urlDe(response.requestOptions).contains('/api/consultas') &&
          !_urlDe(response.requestOptions).contains('/api/beneficiario') &&
          !_urlDe(response.requestOptions).contains('/api/autorizacao')) {
        _logarCorpo('resposta', response.data);
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final int? status = err.response?.statusCode;
      // ignore: avoid_print
      print(
        '[HTTP] x ${err.requestOptions.method} '
        '${_urlDe(err.requestOptions)} -> ${status ?? err.type}',
      );
      _logarCorpoSemPii(err.requestOptions, 'erro', err.response?.data);
    }
    handler.next(err);
  }

  void _logarCorpoSemPii(RequestOptions options, String rotulo, dynamic dados) {
    final String url = _urlDe(options);
    if (url.contains('/api/consultas') ||
        url.contains('/api/beneficiario') ||
        url.contains('/api/autorizacao')) {
      return;
    }
    _logarCorpo(rotulo, dados);
  }

  String _urlDe(RequestOptions options) => '${options.baseUrl}${options.path}';

  void _logarCorpo(String rotulo, dynamic dados) {
    final String? texto = _resumir(dados);
    if (texto == null) return;
    // ignore: avoid_print
    print('[HTTP] $rotulo: $texto');
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