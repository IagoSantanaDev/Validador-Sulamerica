class AppConfig {
  const AppConfig._();

  static const String baseUrlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );
}
