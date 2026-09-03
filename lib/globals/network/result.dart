import 'app_exception.dart';

/// Result pattern: toda chamada de rede retorna um [Result], nunca lança
/// exceção para o chamador nem retorna null para sinalizar falha.
sealed class Result<T> {
  const Result();

  const factory Result.success(T valor) = Success<T>;
  const factory Result.failure(AppException erro) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R fold<R>({
    required R Function(T valor) onSuccess,
    required R Function(AppException erro) onFailure,
  }) {
    final Result<T> resultado = this;
    return switch (resultado) {
      Success<T>(valor: final valor) => onSuccess(valor),
      Failure<T>(erro: final erro) => onFailure(erro),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.valor);

  final T valor;
}

class Failure<T> extends Result<T> {
  const Failure(this.erro);

  final AppException erro;
}
