import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/xml_lote_guias_datasource.dart';

void main() {
  group('XmlLoteGuiasDatasource solicitante', () {
    const XmlLoteGuiasDatasource datasource = XmlLoteGuiasDatasource();

    test('extrai conselho literal do profissional no namespace TISS', () {
      const String xml = '''
<tiss:mensagemTISS xmlns:tiss="http://www.ans.gov.br/padroes/tiss/schemas">
  <tiss:guiaSP-SADT>
    <tiss:dadosSolicitante>
      <tiss:profissionalSolicitante>
        <tiss:numeroConselhoProfissional>  014481  </tiss:numeroConselhoProfissional>
      </tiss:profissionalSolicitante>
    </tiss:dadosSolicitante>
    <tiss:equipeSadt>
      <tiss:numeroConselhoProfissional>999999</tiss:numeroConselhoProfissional>
    </tiss:equipeSadt>
  </tiss:guiaSP-SADT>
</tiss:mensagemTISS>
''';

      final guia = datasource.extrairGuias(xml).single;

      expect(guia.solicitante?.numeroConselho, '  014481  ');
    });

    test('deixa solicitante ausente quando só há conselho em equipeSadt', () {
      const String xml = '''
<tiss:mensagemTISS xmlns:tiss="http://www.ans.gov.br/padroes/tiss/schemas">
  <tiss:guiaSP-SADT>
    <tiss:equipeSadt>
      <tiss:numeroConselhoProfissional>999999</tiss:numeroConselhoProfissional>
    </tiss:equipeSadt>
  </tiss:guiaSP-SADT>
</tiss:mensagemTISS>
''';

      final guia = datasource.extrairGuias(xml).single;

      expect(guia.solicitante, isNull);
    });

    test('deixa conselho ausente quando o elemento está vazio', () {
      const String xml = '''
<tiss:mensagemTISS xmlns:tiss="http://www.ans.gov.br/padroes/tiss/schemas">
  <tiss:guiaSP-SADT>
    <tiss:dadosSolicitante>
      <tiss:profissionalSolicitante>
        <tiss:numeroConselhoProfissional></tiss:numeroConselhoProfissional>
      </tiss:profissionalSolicitante>
    </tiss:dadosSolicitante>
  </tiss:guiaSP-SADT>
</tiss:mensagemTISS>
''';

      final guia = datasource.extrairGuias(xml).single;

      expect(guia.solicitante, isNull);
    });
  });
}
