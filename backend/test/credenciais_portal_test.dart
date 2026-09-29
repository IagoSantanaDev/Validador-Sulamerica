import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';

void main() {
  group('CredenciaisPortal.resolver', () {
    test('retorna null para identificador desconhecido', () {
      final credenciais = CredenciaisPortal.resolver('desconhecido');
      expect(credenciais, isNull);
    });

    test('retorna null para identificador vazio', () {
      final credenciais = CredenciaisPortal.resolver('');
      expect(credenciais, isNull);
    });

    test('retorna null para identificador com espacos', () {
      final credenciais = CredenciaisPortal.resolver('   ');
      expect(credenciais, isNull);
    });

    test('resolve credenciais quando configurado', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_CODE': '12345',
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha123',
      };

      final credenciais = CredenciaisPortal.resolver(
        'teste',
        ambiente: ambiente,
      );
      expect(credenciais, isNotNull);
      expect(credenciais!.code, '12345');
      expect(credenciais.user, 'usuario');
      expect(credenciais.senha, 'senha123');
    });

    test('retorna null quando code esta ausente', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha123',
      };

      final credenciais = CredenciaisPortal.resolver(
        'teste',
        ambiente: ambiente,
      );
      expect(credenciais, isNull);
    });

    test('retorna null quando user esta ausente', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_CODE': '12345',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha123',
      };

      final credenciais = CredenciaisPortal.resolver(
        'teste',
        ambiente: ambiente,
      );
      expect(credenciais, isNull);
    });

    test('retorna null quando senha esta ausente', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_CODE': '12345',
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario',
      };

      final credenciais = CredenciaisPortal.resolver(
        'teste',
        ambiente: ambiente,
      );
      expect(credenciais, isNull);
    });

    test('retorna null quando code esta vazio', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_CODE': '',
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha123',
      };

      final credenciais = CredenciaisPortal.resolver(
        'teste',
        ambiente: ambiente,
      );
      expect(credenciais, isNull);
    });

    test('normaliza identificador para maiusculas', () {
      final ambiente = {
        'PORTAL_PRESTADOR_ID_TESTE_CODE': '12345',
        'PORTAL_PRESTADOR_ID_TESTE_USER': 'usuario',
        'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha123',
      };

      // Deve funcionar com identificador em maiúsculas.
      final credenciais = CredenciaisPortal.resolver(
        'TESTE',
        ambiente: ambiente,
      );
      expect(credenciais, isNotNull);
    });
  });
}
