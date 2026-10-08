import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/procedimento.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/codigos_vpp.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_senha_prefixo.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_senha_procedimento.dart';

Future<List<String>> _codigosDaFonte() async {
  final List<String> codigos = CodigosVpp.todos.toList();
  codigos.sort();
  return codigos;
}

GuiaTiss _guia({String? senha, List<String> codigos = const []}) => GuiaTiss(
      numeroGuiaPrestador: 'synthetic',
      numeroCarteira: null,
      senha: senha,
      procedimentos: codigos
          .map((String codigo) => Procedimento(codigo: codigo, quantidade: 1))
          .toList(),
    );

void main() {
  group('RegraSenhaProcedimento', () {
    const RegraSenhaProcedimento regra = RegraSenhaProcedimento();

    test('conjunto runtime corresponde à fonte e tem 2.792 códigos únicos',
        () async {
      final List<String> fonte = await _codigosDaFonte();
      final Set<String> codigosFonte = fonte.toSet();

      expect(fonte, hasLength(2792));
      expect(codigosFonte, hasLength(2792));
      expect(CodigosVpp.todos, equals(codigosFonte));
    });

    test('exige senha para códigos do início, meio e fim da fonte', () async {
      final List<String> fonte = await _codigosDaFonte();
      final List<String> amostras = [
        fonte.first,
        fonte[fonte.length ~/ 2],
        fonte.last,
      ];

      for (final String codigo in amostras) {
        final erro = regra.validar(_guia(codigos: [codigo]));

        expect(erro?.campo, 'senha');
        expect(erro?.mensagem, contains(codigo));
        expect(erro?.mensagem, isNot(contains('senha não informada')));
      }
    });

    test('lista todos os códigos aplicáveis em um único erro', () async {
      final List<String> fonte = await _codigosDaFonte();
      final List<String> codigos = [fonte.first, fonte.last, fonte.first];
      final erro = regra.validar(_guia(codigos: codigos));

      expect(erro?.mensagem, contains(fonte.first));
      expect(erro?.mensagem, contains(fonte.last));
      expect(erro?.mensagem, isNot(contains('senha não informada')));
    });

    test('não exige senha sem alvo VPP ou quando a senha existe', () async {
      final List<String> fonte = await _codigosDaFonte();

      expect(regra.validar(_guia(codigos: ['00000000'])), isNull);
      expect(
        regra.validar(_guia(senha: 'qualquer', codigos: [fonte.first])),
        isNull,
      );
    });

    test('RegraSenhaPrefixo não duplica senha ausente para alvo VPP', () async {
      final List<String> fonte = await _codigosDaFonte();
      const RegraSenhaPrefixo prefixo = RegraSenhaPrefixo();

      expect(prefixo.validar(_guia(codigos: [fonte.first])), isNull);
    });

    test('RegraSenhaPrefixo não exige senha quando ela não é informada',
        () async {
      const RegraSenhaPrefixo prefixo = RegraSenhaPrefixo();

      expect(prefixo.validar(_guia()), isNull);
      expect(prefixo.validar(_guia(senha: '')), isNull);
    });
  });
}
