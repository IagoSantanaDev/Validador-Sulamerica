import 'dart:convert';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/assinatura_resposta_portal.dart';

void main() {
  group('ColetorAssinaturasRespostaPortal', () {
    test('resume HTML rejeitado sem manter body', () {
      final ColetorAssinaturasRespostaPortal coletor =
          ColetorAssinaturasRespostaPortal();
      const String body =
          '<html><title>Request rejected</title>Support ID: ABCD123456</html>';

      final AssinaturaRespostaPortal assinatura = coletor.coletar(
        status: 403,
        contentType: 'text/html; charset=utf-8',
        body: utf8.encode(body),
      );
      final Map<String, dynamic> json = assinatura.toJson();

      expect(assinatura.status, 403);
      expect(assinatura.contentLength, utf8.encode(body).length);
      expect(assinatura.bodySha256, hasLength(64));
      expect(assinatura.title, 'Request rejected');
      expect(assinatura.f5Rejected, isTrue);
      expect(assinatura.hasRejectedMarker, isTrue);
      expect(assinatura.hasSupportIdMarker, isTrue);
      expect(jsonEncode(json), isNot(contains(body)));
      expect(jsonEncode(json), isNot(contains('ABCD123456')));
    });

    test('assinatura não contém nem retém Support ID individual', () {
      final ColetorAssinaturasRespostaPortal coletor =
          ColetorAssinaturasRespostaPortal();
      const String body = '<html>Support ID: WXYZ654321</html>';

      final AssinaturaRespostaPortal assinatura = coletor.coletar(
        status: 403,
        contentType: 'text/html',
        body: utf8.encode(body),
      );

      expect(assinatura.hasSupportIdMarker, isTrue);
      expect(assinatura.toJson(), isNot(contains('supportId')));
      expect(jsonEncode(assinatura.toJson()), isNot(contains('WXYZ654321')));
    });
  });
}
