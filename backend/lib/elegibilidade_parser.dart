library;

String? extrairRotuloElegibilidade(String html) {
  // Permite `&nbsp;`/entidades entre o label e a tag e captura o valor
  // dentro do <span> (qualquer classe: atencao, ok, etc.).
  final RegExp padrao = RegExp(
    r'<strong>\s*Eleg[ií]vel:[^<]*?</strong>\s*<span[^>]*>\s*([^<]+?)\s*</span>',
    caseSensitive: false,
  );
  final Match? match = padrao.firstMatch(html);
  if (match == null) return null;

  final String rotulo = match
      .group(1)!
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim()
      .toUpperCase();
  return rotulo.isEmpty ? null : rotulo;
}

bool? extrairElegivel(String html) {
  final String? rotulo = extrairRotuloElegibilidade(html);
  if (rotulo == null) return null;
  if (rotulo == 'SIM') return true;
  if (rotulo == 'NÃO' || rotulo == 'NAO') return false;
  return null;
}
