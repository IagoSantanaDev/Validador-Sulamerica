import '../../../../../globals/constants/app_config.dart';

class CredenciaisPortal {
  const CredenciaisPortal({
    required this.code,
    required this.user,
    required this.senha,
  });

  final String code;
  final String user;
  final String senha;

  bool get completas => code.isNotEmpty && user.isNotEmpty && senha.isNotEmpty;
}

class RegraCredenciaisPortal {
  const RegraCredenciaisPortal();

  static const String _cnpjCemed = '27372066000673';
  static const String _cnpjHsr = '27372066000169';

  static const Map<String, CredenciaisPortal> _credenciaisPorPrestador = {
    _cnpjCemed: CredenciaisPortal(
      code: AppConfig.portalCodeCemed,
      user: AppConfig.portalUserCemed,
      senha: AppConfig.portalSenhaCemed,
    ),
    _cnpjHsr: CredenciaisPortal(
      code: AppConfig.portalCodeHsr,
      user: AppConfig.portalUserHsr,
      senha: AppConfig.portalSenhaHsr,
    ),
  };

  CredenciaisPortal? resolver(String? identificadorPrestador) {
    final String chave = _apenasDigitos(identificadorPrestador);
    return _credenciaisPorPrestador[chave];
  }

  String _apenasDigitos(String? valor) =>
      valor?.replaceAll(RegExp(r'\D'), '') ?? '';
}
