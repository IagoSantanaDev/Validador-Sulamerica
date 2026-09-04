import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/utils/formatos.dart';

void main() {
  group('formatarMoeda', () {
    test('formata valor inteiro com milhar em real', () {
      expect(formatarMoeda('3031.41'), 'R\$ 3.031,41');
    });

    test('formata valores com milhares maiores', () {
      expect(formatarMoeda('95000.00'), 'R\$ 95.000,00');
      expect(formatarMoeda('1234567.89'), 'R\$ 1.234.567,89');
    });

    test('formata valor sem casas decimais', () {
      expect(formatarMoeda('1000'), 'R\$ 1.000,00');
    });

    test('formata valor negativo', () {
      expect(formatarMoeda('-50.5'), 'R\$ -50,50');
    });

    test('retorna placeholder para valor não numérico', () {
      expect(formatarMoeda(null), '—');
      expect(formatarMoeda('abc'), '—');
    });
  });
}
