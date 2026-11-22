import 'package:shelf/shelf.dart';

const String metodosPermitidosCors = 'GET, POST, OPTIONS';

const String cabecalhosPermitidosCors =
    'Content-Type, Authorization, Idempotency-Key, Last-Event-ID, Cache-Control';

const String cabecalhosExpostosCors = 'Location';

/// Normaliza uma lista de origens: sem espacos nas pontas e sem barra final,
/// porque um origin da spec e esquema+host+porta, sem path. Itens vazios
/// (virgula dupla ou virgula no fim) sao descartados.
List<String> normalizarOrigens(Iterable<String> origens) {
  final List<String> normalizadas = <String>[];
  for (final String item in origens) {
    final String? normalizada = _origemNormalizada(item);
    if (normalizada != null) normalizadas.add(normalizada);
  }
  return normalizadas;
}

/// CORS com lista de origens permitidas.
///
/// Lista vazia ou com `*` responde `Access-Control-Allow-Origin: *`. Com lista
/// explicita, a resposta ecoa **apenas** a origem que casou, porque o header
/// aceita um valor so; origem de fora nao recebe o header. Quando a resposta
/// depende da origem, inclui `Vary: Origin` para nao envenenar cache
/// compartilhado.
Middleware cors({Iterable<String> origens = const <String>[]}) {
  final List<String> permitidas = normalizarOrigens(origens);
  return (Handler inner) {
    return (Request request) async {
      final String? permitida = _origemPermitida(
        permitidas,
        request.headers['origin'],
      );
      final Map<String, String> headers = <String, String>{
        if (permitida != null) 'Access-Control-Allow-Origin': permitida,
        if (permitida != null && permitida != '*') 'vary': 'origin',
        'Access-Control-Allow-Methods': metodosPermitidosCors,
        'Access-Control-Allow-Headers': cabecalhosPermitidosCors,
        'Access-Control-Max-Age': '86400',
        'Access-Control-Expose-Headers': cabecalhosExpostosCors,
      };
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final Response resposta = await inner(request);
      return resposta.change(headers: headers);
    };
  };
}

String? _origemNormalizada(String item) {
  final String origem = item.trim().replaceAll(RegExp(r'/+$'), '');
  return origem.isEmpty ? null : origem;
}

String? _origemPermitida(List<String> origens, String? requisicao) {
  if (origens.isEmpty || origens.contains('*')) return '*';
  if (requisicao == null) return null;
  final String? normalizada = _origemNormalizada(requisicao);
  if (normalizada == null || !origens.contains(normalizada)) return null;
  return normalizada;
}
