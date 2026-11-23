class RegraCredenciaisPortal {
  const RegraCredenciaisPortal();

  String? resolver(String? identificadorPrestador) {
    final String chave = _apenasDigitos(identificadorPrestador);
    if (chave.length != 14) return null;
    if (chave.split('').toSet().length == 1) return null;
    return chave;
  }

  String _apenasDigitos(String? valor) =>
      valor?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
}
