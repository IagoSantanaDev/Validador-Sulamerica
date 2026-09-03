/// Lançada quando o conteúdo do arquivo não é um XML bem formado.
class XmlMalFormadoException implements Exception {
  const XmlMalFormadoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Lançada quando o XML é válido, mas não contém nenhuma guia guiaSP-SADT.
class NenhumaGuiaEncontradaException implements Exception {
  const NenhumaGuiaEncontradaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
