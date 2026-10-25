class TussBaseLocalInvalidaException implements Exception {
  const TussBaseLocalInvalidaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
