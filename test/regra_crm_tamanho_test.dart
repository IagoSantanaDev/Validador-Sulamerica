import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/profissional_solicitante.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_crm_tamanho.dart';

void main() {
  const RegraCrmTamanho regra = RegraCrmTamanho();

  GuiaTiss guiaComCrm(String? numeroConselho) => GuiaTiss(
        numeroGuiaPrestador: '',
        numeroCarteira: null,
        senha: null,
        solicitante: ProfissionalSolicitante(
          numeroConselho: numeroConselho,
        ),
      );

  test('aceita CRM literal com quatro ou cinco caracteres', () {
    expect(regra.validar(guiaComCrm('1234')), isNull);
    expect(regra.validar(guiaComCrm('12345')), isNull);
  });

  test('rejeita seis caracteres sem remover zero à esquerda', () {
    for (final String crm in ['123456', '014481']) {
      final erro = regra.validar(guiaComCrm(crm));

      expect(erro?.campo, 'crm');
      expect(erro?.mensagem, 'CRM deve ter no máximo 5 dígitos ($crm)');
    }
  });

  test('não valida CRM ausente ou vazio', () {
    expect(regra.validar(guiaComCrm(null)), isNull);
    expect(regra.validar(guiaComCrm('')), isNull);
  });

  test('conta espaços como caracteres, sem trim', () {
    expect(regra.validar(guiaComCrm(' 123 ')), isNull);
    expect(regra.validar(guiaComCrm(' 1234 '))?.campo, 'crm');
  });
}
