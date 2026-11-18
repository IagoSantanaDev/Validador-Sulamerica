import 'dart:convert';

/// Codifica um evento `text/event-stream` pronto para o corpo da resposta.
///
/// `dados` que não for `String` é serializado em JSON. `\r` é removido porque
/// um retorno de carro solto invalida o campo `data` e o navegador descarta o
/// evento inteiro.
List<int> codificarEventoSse({
  int? id,
  required String evento,
  required Object? dados,
}) {
  final StringBuffer saida = StringBuffer();
  if (id != null) {
    saida.write('id: $id\n');
  }
  saida.write('event: $evento\n');
  final String texto = dados is String ? dados : jsonEncode(dados);
  for (final String linha in texto.replaceAll('\r', '').split('\n')) {
    saida.write('data: $linha\n');
  }
  saida.write('\n');
  return utf8.encode(saida.toString());
}

/// Comentário SSE, usado como heartbeat (`: ping`). O cliente ignora o
/// conteúdo, mas a linha impede que proxies fechem a conexão ociosa.
List<int> codificarComentarioSse(String comentario) {
  final String linha = comentario.replaceAll(RegExp(r'[\r\n]'), ' ');
  return utf8.encode(': $linha\n\n');
}

/// Instrui o cliente a reconectar depois de [intervalo].
List<int> codificarRetrySse(Duration intervalo) =>
    utf8.encode('retry: ${intervalo.inMilliseconds}\n\n');

/// Headers exigidos pelo contrato do stream em `Response` do shelf.
///
/// `X-Accel-Buffering: no` desliga o buffer do proxy; `no-cache` impede que
/// CDN ou navegador guardem um corpo infinito.
Map<String, String> cabecalhosSse() => const <String, String>{
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache',
      'X-Accel-Buffering': 'no',
      'Connection': 'keep-alive',
    };
