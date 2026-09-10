class AppConfig {
  const AppConfig._();

  /// Backend intermediário (proxy) do portal SulAmérica.
  /// Em produção, definir no build: `--dart-define=API_URL=https://...`
  static const String baseUrlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Credenciais do prestador no portal SulAmérica, usadas para autenticar
  /// via POST /api/login (backend intermediário). Definir no build:
  /// `--dart-define=PORTAL_CODE=... --dart-define=PORTAL_USER=...`
  /// `--dart-define=PORTAL_SENHA=...`. Sem elas o app valida apenas localmente.
  static const String portalCode = String.fromEnvironment('PORTAL_CODE');
  static const String portalUser = String.fromEnvironment('PORTAL_USER');
  static const String portalSenha = String.fromEnvironment('PORTAL_SENHA');

  /// Credenciais extras por prestador (ver RegraCredenciaisPortal), para
  /// lotes cujo identificacaoPrestador não é o prestador padrão acima.
  /// Definir no build: `--dart-define=PORTAL_CODE_CEMED=...
  /// --dart-define=PORTAL_USER_CEMED=... --dart-define=PORTAL_SENHA_CEMED=...`
  /// (idem sufixo `_HSR`). Nunca commitar esses valores — só passar no build.
  static const String portalCodeCemed =
      String.fromEnvironment('PORTAL_CODE_CEMED');
  static const String portalUserCemed =
      String.fromEnvironment('PORTAL_USER_CEMED');
  static const String portalSenhaCemed =
      String.fromEnvironment('PORTAL_SENHA_CEMED');

  static const String portalCodeHsr =
      String.fromEnvironment('PORTAL_CODE_HSR');
  static const String portalUserHsr =
      String.fromEnvironment('PORTAL_USER_HSR');
  static const String portalSenhaHsr =
      String.fromEnvironment('PORTAL_SENHA_HSR');
}