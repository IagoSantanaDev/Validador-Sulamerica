import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_credenciais_portal.dart';

void main() {
  const RegraCredenciaisPortal regra = RegraCredenciaisPortal();

  test('normaliza o identificador e preserva apenas prestadores conhecidos',
      () {
    expect(regra.resolver('27.372.066/0006-73'), '27372066000673');
    expect(regra.resolver('27.372.066/0001-69'), '27372066000169');
    expect(regra.resolver('00.000.000/0000-00'), isNull);
    expect(regra.resolver(null), isNull);
  });
}
