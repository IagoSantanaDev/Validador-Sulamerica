import 'dart:convert';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/assinatura_resposta_portal.dart';

void main() {
  group('ColetorAssinaturasRespostaPortal', () {
    test('resume HTML rejeitado sem manter body', () {
      final ColetorAssinaturasRespostaPortal coletor =
          ColetorAssinaturasRespostaPortal(supportIdsHabilitados: false);
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
      expect(assinatura.supportId, isNull);
      expect(jsonEncode(json), isNot(contains(body)));
      expect(coletor.supportIdsRecentes, isEmpty);
    });

    test('support IDs opt-in e buffer mantém somente registros recentes', () {
      final ColetorAssinaturasRespostaPortal coletor =
          ColetorAssinaturasRespostaPortal(
        supportIdsHabilitados: true,
        tamanhoBuffer: 1,
      );

      coletor.coletar(
        status: 403,
        contentType: 'text/html',
        body: utf8.encode('<html>Support ID: ABCD123456</html>'),
      );
      coletor.coletar(
        status: 403,
        contentType: 'text/html',
        body: utf8.encode('<html>Support ID: WXYZ654321</html>'),
      );

      final List<Map<String, dynamic>> recentes = coletor.supportIdsRecentes;
      expect(recentes, hasLength(1));
      expect(recentes.single['supportId'], 'WXYZ654321');
      expect(recentes.single['status'], 403);
      expect(
        DateTime.tryParse(recentes.single['timestamp'] as String),
        isNotNull,
      );
    });
  });
}
