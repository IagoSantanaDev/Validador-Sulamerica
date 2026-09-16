class NenhumaGuiaEncontradaException implements Exception {
  const NenhumaGuiaEncontradaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class XmlMalFormadoException implements Exception {
  const XmlMalFormadoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
