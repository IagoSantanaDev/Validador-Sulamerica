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

/// Prestadores fora de [_credenciaisPorPrestador] usam [credenciaisPadrao]
/// (AppConfig/DI) — assim lotes de prestadores diferentes autenticam com
/// contas distintas do mesmo backend, sem selecao manual no app.
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

  // Apenas digitos: o XML pode trazer o identificador do prestador sem
  // mascara (formato mais comum no codigoPrestadorNaOperadora).
  CredenciaisPortal resolver(
    String? identificadorPrestador, {
    required CredenciaisPortal credenciaisPadrao,
  }) {
    final String chave = _apenasDigitos(identificadorPrestador);
    return _credenciaisPorPrestador[chave] ?? credenciaisPadrao;
  }

  String _apenasDigitos(String? valor) =>
      valor?.replaceAll(RegExp(r'\D'), '') ?? '';
}
