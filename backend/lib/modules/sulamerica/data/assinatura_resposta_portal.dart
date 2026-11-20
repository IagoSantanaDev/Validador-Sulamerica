import 'dart:convert';

import 'package:crypto/crypto.dart';

class AssinaturaRespostaPortal {
  const AssinaturaRespostaPortal({
    required this.status,
    required this.contentType,
    required this.contentLength,
    required this.bodySha256,
    required this.title,
    required this.f5Rejected,
    required this.hasRejectedMarker,
    required this.hasSupportIdMarker,
  });

  final int? status;
  final String? contentType;
  final int? contentLength;
  final String? bodySha256;
  final String? title;
  final bool f5Rejected;
  final bool hasRejectedMarker;
  final bool hasSupportIdMarker;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status,
    'contentType': contentType,
    'contentLength': contentLength,
    'bodySha256': bodySha256,
    'title': title,
    'f5Rejected': f5Rejected,
    'f5Markers': <String, bool>{
      'rejected': hasRejectedMarker,
      'supportId': hasSupportIdMarker,
    },
  };
}

class ColetorAssinaturasRespostaPortal {
  AssinaturaRespostaPortal coletar({
    required int? status,
    required String? contentType,
    required List<int>? body,
  }) {
    final String corpo = body == null ? '' : _decodificar(body);
    final String normalizado = corpo.toLowerCase();
    final String? titulo = _extrairTitulo(corpo);
    final String mime =
        contentType?.split(';').first.trim().toLowerCase() ?? '';
    final bool ehHtml = mime.startsWith('text/html');
    final bool rejectedMarker = ehHtml && normalizado.contains('rejected');
    final bool supportIdMarker = ehHtml && normalizado.contains('support id');
    final AssinaturaRespostaPortal assinatura = AssinaturaRespostaPortal(
      status: status,
      contentType: contentType,
      contentLength: body?.length,
      bodySha256: body == null || body.isEmpty
          ? null
          : sha256.convert(body).toString(),
      title: titulo,
      f5Rejected: rejectedMarker || supportIdMarker,
      hasRejectedMarker: rejectedMarker,
      hasSupportIdMarker: supportIdMarker,
    );
    return assinatura;
  }

  static String _decodificar(List<int> body) {
    try {
      return utf8.decode(body);
    } on FormatException {
      return latin1.decode(body, allowInvalid: true);
    }
  }

  static String? _extrairTitulo(String body) {
    final RegExpMatch? match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return null;
    final String titulo =
        match.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (titulo.isEmpty) return null;
    return titulo.length <= 120 ? titulo : titulo.substring(0, 120);
  }
}
