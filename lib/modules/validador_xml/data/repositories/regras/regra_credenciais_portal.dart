class RegraCredenciaisPortal {
  const RegraCredenciaisPortal();

  static const String _cnpjCemed = '27372066000673';
  static const String _cnpjHsr = '27372066000169';

  static const Set<String> _identificadoresPrestadores = {
    _cnpjCemed,
    _cnpjHsr,
  };

  String? resolver(String? identificadorPrestador) {
    final String chave = _apenasDigitos(identificadorPrestador);
    return _identificadoresPrestadores.contains(chave) ? chave : null;
  }

  String _apenasDigitos(String? valor) =>
      valor?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
}
