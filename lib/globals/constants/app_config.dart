/// Configurações de ambiente do app.
///
/// [baseUrlApi] aponta para o **backend intermediário** (proxy do portal
/// SulAmérica), em `backend/` do repositório. O app NÃO chama o portal
/// diretamente — o proxy resolve CORS e mantém a sessão (JSESSIONID).
/// Em produção, troque para a URL publicada do backend (sempre HTTPS).
class AppConfig {
  const AppConfig._();

  static const String baseUrlApi = 'http://localhost:8080';
}