/// Configurações de ambiente.
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
}