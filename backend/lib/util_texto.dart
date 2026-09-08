String resumirTexto(String texto, {int maximoCaracteres = 300}) {
  final String normalizado = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalizado.length <= maximoCaracteres
      ? normalizado
      : '${normalizado.substring(0, maximoCaracteres)}…';
}
