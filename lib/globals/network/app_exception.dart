/// Hierarquia de exceções de rede. Nunca usamos null para sinalizar erro
/// de requisição — todo erro vira uma dessas classes específicas.
sealed class AppException implements Exception {
  const AppException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class SemConexaoException extends AppException {
  const SemConexaoException()
      : super(
          'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        );
}

class RequisicaoExpiradaException extends AppException {
  const RequisicaoExpiradaException()
      : super('A requisição demorou demais para responder. Tente novamente.');
}

class RequisicaoCanceladaException extends AppException {
  const RequisicaoCanceladaException() : super('A requisição foi cancelada.');
}

class NaoAutorizadoException extends AppException {
  const NaoAutorizadoException()
      : super('Sessão expirada ou acesso não autorizado.');
}

class RecursoNaoEncontradoException extends AppException {
  const RecursoNaoEncontradoException() : super('Recurso não encontrado.');
}

class ErroServidorException extends AppException {
  const ErroServidorException({
    required this.statusCode,
    required String mensagem,
  }) : super(mensagem);

  final int? statusCode;
}

class ErroDesconhecidoException extends AppException {
  const ErroDesconhecidoException(super.mensagem);
}
