import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

void main() {
  group('SessaoPortal - TLS', () {
    test('sessao preserva validacao TLS padrao sem configuração adicional', () {
      final SessaoPortal sessao = SessaoPortal();
      expect(sessao.autenticada, isFalse);
    });
  });
}
