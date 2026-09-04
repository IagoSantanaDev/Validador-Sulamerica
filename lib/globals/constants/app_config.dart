/// Configurações de ambiente.
class AppConfig {
  const AppConfig._();

  /// Backend intermediário (proxy) do portal SulAmérica.
  /// Em produção, definir no build: `--dart-define=API_URL=https://...`
  static const String baseUrlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );
}