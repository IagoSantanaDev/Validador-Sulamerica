/// Configurações de ambiente do app.
///
/// baseUrlApi é um placeholder para uma futura API própria — o fluxo
/// atual com a SulAmérica usa SulAmericaService, que tem sua própria
/// baseUrl fixa (o portal Lumis), independente desta.
class AppConfig {
  const AppConfig._();

  static const String baseUrlApi = 'https://api.sulamerica.exemplo.com';
}
