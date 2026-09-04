import 'app_exception.dart';

sealed class Result<T> {
  const Result();

  static Success<T> success<T>(T valor) => Success(valor);

  static Failure<T> failure<T>(AppException erro) => Failure(erro);

  R fold<R>({
    required R Function(T sucesso) onSuccess,
    required R Function(AppException erro) onFailure,
  });
}

class Success<T> extends Result<T> {
  const Success(this.valor);

  final T valor;

  @override
  R fold<R>({
    required R Function(T sucesso) onSuccess,
    required R Function(AppException erro) onFailure,
  }) =>
      onSuccess(valor);
}

class Failure<T> extends Result<T> {
  const Failure(this.erro);

  final AppException erro;

  @override
  R fold<R>({
    required R Function(T sucesso) onSuccess,
    required R Function(AppException erro) onFailure,
  }) =>
      onFailure(erro);
}