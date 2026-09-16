import 'package:test/test.dart';

import 'package:validador_backend/util_texto.dart';

void main() {
  group('resumirTexto', () {
    test('mantém texto curto e normaliza o whitespace', () {
      expect(resumirTexto('  a \n b  '), 'a b');
    });

    test('trunca texto acima do limite', () {
      final String longo = 'x' * 500;
      final String resumo = resumirTexto(longo);
      expect(resumo.length, 301);
      expect(resumo.endsWith('…'), isTrue);
    });

    test('respeita limite customizado', () {
      expect(resumirTexto('123456', maximoCaracteres: 4), '1234…');
    });
  });
}
