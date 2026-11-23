sealed class AppException implements Exception {
  const AppException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class SemConexaoException extends AppException {
  const SemConexaoException() : super('Sem conexão com a internet.');
}

class RequisicaoExpiradaException extends AppException {
  const RequisicaoExpiradaException() : super('A requisição expirou.');
}

class RequisicaoCanceladaException extends AppException {
  const RequisicaoCanceladaException() : super('A requisição foi cancelada.');
}

class NaoAutorizadoException extends AppException {
  const NaoAutorizadoException() : super('Acesso não autorizado (401/403).');
}

class RecursoNaoEncontradoException extends AppException {
  const RecursoNaoEncontradoException()
      : super('Recurso não encontrado (404).');
}

class FilaCheiaException extends AppException {
  const FilaCheiaException({this.retryAfter, String? mensagem})
      : super(mensagem ?? 'A fila de lotes está cheia. Tente novamente.');

  /// Valor de `Retry-After` devolvido pelo backend, quando presente.
  final Duration? retryAfter;
}

class ServicoIndisponivelException extends AppException {
  const ServicoIndisponivelException({
    this.retryAfter,
    this.bloqueio,
    String? mensagem,
  })
      : super(mensagem ?? 'O serviço está temporariamente indisponível.');

  final Duration? retryAfter;
  final Map<String, dynamic>? bloqueio;
}

class ErroServidorException extends AppException {
  const ErroServidorException({required this.statusCode, String? mensagem})
      : super(mensagem ?? 'Erro do servidor.');
  final int? statusCode;
}

class ErroDesconhecidoException extends AppException {
  const ErroDesconhecidoException(super.mensagem);
}
