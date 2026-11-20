import 'dart:async';

import 'package:dio/dio.dart';

/// Limita quantas operações podem rodar ao mesmo tempo e publica diagnóstico.
///
/// A fila é justa: quem chega depois de uma vaga ocupada espera, mesmo que
/// outra vaga fique livre no meio do caminho.
class SemaforoRequisicoes {
  SemaforoRequisicoes(this.limite) : assert(limite > 0);

  final int limite;
  int _ativas = 0;
  int _picoAtivas = 0;
  int _picoEspera = 0;
  int _totalEspera = 0;
  final List<Completer<void>> _espera = <Completer<void>>[];

  Map<String, int> get diagnostico => <String, int>{
    'limite': limite,
    'ativasAgora': _ativas,
    'picoAtivas': _picoAtivas,
    'aguardandoAgora': _espera.length,
    'picoAguardando': _picoEspera,
    'totalAguardas': _totalEspera,
  };

  Future<T> executar<T>(
    Future<T> Function() operacao, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw _erroCancelamento(cancelToken!);
    }

    bool possuiVaga = false;
    if (_ativas < limite && _espera.isEmpty) {
      _ativas++;
      if (_ativas > _picoAtivas) _picoAtivas = _ativas;
      possuiVaga = true;
    } else {
      final Completer<void> livre = Completer<void>();
      _espera.add(livre);
      _totalEspera++;
      if (_espera.length > _picoEspera) _picoEspera = _espera.length;
      try {
        if (cancelToken == null) {
          await livre.future;
        } else {
          try {
            await Future.any<void>(<Future<void>>[
              livre.future,
              cancelToken.whenCancel.then<void>(
                (_) => throw _erroCancelamento(cancelToken),
              ),
            ]);
          } on DioException catch (error, stackTrace) {
            if (livre.isCompleted) {
              _liberarVaga();
            } else {
              _espera.remove(livre);
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
        }
        possuiVaga = livre.isCompleted;
      } finally {
        _espera.remove(livre);
      }
    }

    if (cancelToken?.isCancelled ?? false) {
      if (possuiVaga) _liberarVaga();
      throw _erroCancelamento(cancelToken!);
    }

    try {
      return await operacao();
    } finally {
      if (possuiVaga) _liberarVaga();
    }
  }

  void _liberarVaga() {
    if (_espera.isNotEmpty) {
      _espera.removeAt(0).complete();
    } else {
      _ativas--;
    }
  }

  DioException _erroCancelamento(CancelToken cancelToken) =>
      cancelToken.cancelError ??
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );
}
