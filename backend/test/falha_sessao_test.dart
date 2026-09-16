import 'package:test/test.dart';

import 'package:validador_backend/validador_api.dart';

void main() {
  group('ehFalhaDeSessaoPortal', () {
    test('401 e 403 são rejeição de sessão (renovar login)', () {
      expect(ehFalhaDeSessaoPortal(401), isTrue);
      expect(ehFalhaDeSessaoPortal(403), isTrue);
    });

    test('demais status e falhas de rede são transitórios', () {
      expect(ehFalhaDeSessaoPortal(500), isFalse);
      expect(ehFalhaDeSessaoPortal(502), isFalse);
      expect(ehFalhaDeSessaoPortal(408), isFalse);
      expect(ehFalhaDeSessaoPortal(null), isFalse);
    });
  });
}
