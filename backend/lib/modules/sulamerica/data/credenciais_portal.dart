import 'dart:io';

/// Resolve credenciais do portal SulAmérica a partir de configuração do servidor.
///
/// O identificador do prestador é a chave pública; as credenciais reais
/// (code, user, senha) são resolvidas no servidor via variáveis de ambiente.
/// Nunca loga credenciais.
class CredenciaisPortal {
  const CredenciaisPortal._({
    required this.code,
    required this.user,
    required this.senha,
  });

  final String code;
  final String user;
  final String senha;

  /// Resolve credenciais para um identificador de prestador.
  ///
  /// Retorna `null` se o identificador for desconhecido.
  /// Configuração via variáveis de ambiente:
  /// - `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_CODE`
  /// - `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_USER`
  /// - `PORTAL_PRESTADOR_ID_<IDENTIFICADOR>_SENHA`
  ///
  /// O parâmetro `ambiente` permite injetar um mapa de configuração para
  /// testes. Se não for fornecido, usa `Platform.environment`.
  static CredenciaisPortal? resolver(
    String identificadorPrestador, {
    Map<String, String>? ambiente,
  }) {
    final Map<String, String> env = ambiente ?? Platform.environment;
    final String prefixo =
        'PORTAL_PRESTADOR_ID_${identificadorPrestador.toUpperCase()}_';

    final String? code = env['${prefixo}CODE'];
    final String? user = env['${prefixo}USER'];
    final String? senha = env['${prefixo}SENHA'];

    if (code == null || code.isEmpty) return null;
    if (user == null || user.isEmpty) return null;
    if (senha == null || senha.isEmpty) return null;

    return CredenciaisPortal._(code: code, user: user, senha: senha);
  }
}
