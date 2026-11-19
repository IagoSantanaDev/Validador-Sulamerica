import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

const String tipoConteudoJson = 'application/json; charset=utf-8';
const String cabecalhoOrigemErroApi = 'x-validador-api-error-origin';

const int limiteCorpoJsonBytes = 1 << 20;

/// Sinaliza corpo acima de [limiteBytes]; o chamador converte em 413.
class CorpoJsonExcedeLimite implements Exception {
  const CorpoJsonExcedeLimite(this.limiteBytes);

  final int limiteBytes;
}

/// Le o corpo como objeto JSON, respeitando [limiteBytes].
///
/// Devolve `null` para corpo vazio, JSON invalido ou raiz que nao seja objeto.
Future<Map<String, dynamic>?> lerCorpoJson(
  Request request, {
  int limiteBytes = limiteCorpoJsonBytes,
}) async {
  final int? informado = request.contentLength;
  if (informado != null && informado > limiteBytes) {
    throw CorpoJsonExcedeLimite(limiteBytes);
  }

  final BytesBuilder acumulador = BytesBuilder(copy: false);
  await for (final List<int> parte in request.read()) {
    acumulador.add(parte);
    if (acumulador.length > limiteBytes) {
      throw CorpoJsonExcedeLimite(limiteBytes);
    }
  }

  final String corpo = utf8.decode(acumulador.takeBytes(), allowMalformed: true);
  if (corpo.trim().isEmpty) return null;

  try {
    final Object? valor = jsonDecode(corpo);
    return valor is Map<String, dynamic> ? valor : null;
  } on FormatException {
    return null;
  }
}

Response respostaJson(
  Map<String, dynamic> dados, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return Response(
    status,
    body: jsonEncode(dados),
    headers: <String, String>{
      'content-type': tipoConteudoJson,
      ...?headers,
    },
  );
}

Response respostaErro(
  String mensagem,
  int status, {
  Map<String, String>? headers,
}) {
  final Map<String, String> cabecalhos = <String, String>{
    ...?headers,
    if (status == 502) cabecalhoOrigemErroApi: 'api',
  };
  return respostaJson(
    <String, dynamic>{'status': 'erro', 'mensagem': mensagem},
    status: status,
    headers: cabecalhos,
  );
}

Map<String, String> cabecalhosRetryAfter(int segundos) {
  if (segundos < 0) {
    throw ArgumentError.value(segundos, 'segundos', 'deve ser >= 0');
  }
  return <String, String>{'retry-after': '$segundos'};
}
