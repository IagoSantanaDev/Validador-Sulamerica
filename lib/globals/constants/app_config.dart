class AppConfig {
  const AppConfig._();

  /// Backend intermediário (proxy) do portal SulAmérica.
  /// Em produção, definir no build: `--dart-define=API_URL=https://...`
  static const String baseUrlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Credenciais extras por prestador (ver RegraCredenciaisPortal). Cada
  /// lote autentica com a conta do próprio prestador — não existe mais
  /// credencial "padrão" para prestadores fora do mapa.
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