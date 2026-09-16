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

class ErroServidorException extends AppException {
  const ErroServidorException({required this.statusCode, String? mensagem})
      : super(mensagem ?? 'Erro do servidor.');
  final int? statusCode;
}

class ErroDesconhecidoException extends AppException {
  const ErroDesconhecidoException(super.mensagem);
}
