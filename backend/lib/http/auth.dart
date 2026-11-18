import 'package:shelf/shelf.dart';

/// Extrai o token de `Authorization: Bearer <token>`.
///
/// Devolve `null` para header ausente, esquema diferente de `Bearer`, token
/// vazio ou valor com espacos internos. O token nunca e registrado em log.
String? tokenBearer(Request request) {
  final String? cabecalho = request.headers['authorization'];
  if (cabecalho == null) return null;

  final List<String> partes = cabecalho.trim().split(RegExp(r'\s+'));
  if (partes.length != 2) return null;
  if (partes.first.toLowerCase() != 'bearer') return null;

  final String token = partes[1];
  return token.isEmpty ? null : token;
}
