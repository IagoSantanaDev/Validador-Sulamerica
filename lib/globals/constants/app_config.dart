class AppConfig {
  const AppConfig._();

  static const String baseUrlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String portalCodeCemed =
      String.fromEnvironment('PORTAL_CODE_CEMED');
  static const String portalUserCemed =
      String.fromEnvironment('PORTAL_USER_CEMED');
  static const String portalSenhaCemed =
      String.fromEnvironment('PORTAL_SENHA_CEMED');

  static const String portalCodeHsr = String.fromEnvironment('PORTAL_CODE_HSR');
  static const String portalUserHsr = String.fromEnvironment('PORTAL_USER_HSR');
  static const String portalSenhaHsr =
      String.fromEnvironment('PORTAL_SENHA_HSR');
}
