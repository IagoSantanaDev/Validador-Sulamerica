/// Fonte única do resumo de texto usado em logs/diagnóstico: normaliza o
/// whitespace e trunca, evitando páginas HTML inteiras ou corpos grandes no
/// log.
String resumirTexto(String texto, {int maximoCaracteres = 300}) {
  final String normalizado = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalizado.length <= maximoCaracteres
      ? normalizado
      : '${normalizado.substring(0, maximoCaracteres)}…';
}