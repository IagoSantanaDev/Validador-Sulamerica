import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/consulta_guia.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_validada.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/presentation/widgets/grade_guias.dart';

void main() {
  const GuiaTiss guia = GuiaTiss(
    numeroGuiaPrestador: '111',
    numeroCarteira: '42509512809910100031',
    senha: null,
  );

  const GuiaValidada guiaMulti = GuiaValidada(
    guia: guia,
    erros: [
      ErroValidacao(
        campo: 'numeroCarteira',
        mensagem: 'numeroCarteira não informado',
      ),
      ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
    ],
    consultas: [
      ConsultaGuia(
        sucesso: false,
        descricao: 'Carteira não encontrada',
      ),
    ],
  );

  group('linhasDeGuia - expansão da grade', () {
    test('cada erro local vira uma linha própria e a consulta outra linha', () {
      final List<LinhaGradeGuia> linhas = linhasDeGuia(guiaMulti);

      expect(linhas, hasLength(3));
      expect(linhas[0].detalhe, 'numeroCarteira não informado');
      expect(linhas[1].detalhe, 'Carteira não encontrada');
      // Todos apontam para a mesma guia.
      for (final LinhaGradeGuia linha in linhas) {
        expect(linha.guia, same(guiaMulti));
      }
    });

    test('senha não informada fica sempre por último', () {
      final List<LinhaGradeGuia> linhas = linhasDeGuia(guiaMulti);

      expect(linhas.last.detalhe, 'senha não informada');
    });

    test('sem consulta gera uma linha por erro local', () {
      const GuiaValidada soErroLocal = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
        ],
      );

      final List<LinhaGradeGuia> linhas = linhasDeGuia(soErroLocal);
      expect(linhas, hasLength(1));
      expect(linhas.single.detalhe, 'senha não informada');
    });

    test('consulta bem-sucedida (Elegível: SIM) não vira linha de erro', () {
      const GuiaValidada elegivelSim = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(campo: 'senha', mensagem: 'senha não informada'),
        ],
        consultas: [
          ConsultaGuia(
            tipo: TipoConsultaGuia.elegibilidade,
            sucesso: true,
            descricao: 'Elegível: SIM',
          ),
        ],
      );

      final List<LinhaGradeGuia> linhas = linhasDeGuia(elegivelSim);
      expect(linhas, hasLength(1));
      expect(linhas.single.detalhe, 'senha não informada');
    });
  });

  group('agruparPorDetalhe - ordenação da grade', () {
    test('detalhes iguais ficam agrupados e senha não informada por último',
        () {
      final List<LinhaGradeGuia> linhas = agruparPorDetalhe([
        const LinhaGradeGuia(guia: guiaMulti, detalhe: 'Senha não informada'),
        const LinhaGradeGuia(
          guia: guiaMulti,
          detalhe: 'Carteira não encontrada',
        ),
        const LinhaGradeGuia(guia: guiaMulti, detalhe: 'Senha não informada'),
        const LinhaGradeGuia(
          guia: guiaMulti,
          detalhe: 'Carteira não encontrada',
        ),
      ]);

      expect(linhas, hasLength(4));
      // Blocos por detalhe: carteira primeiro, senha por último.
      expect(linhas[0].detalhe, 'Carteira não encontrada');
      expect(linhas[1].detalhe, 'Carteira não encontrada');
      expect(linhas[2].detalhe, 'Senha não informada');
      expect(linhas[3].detalhe, 'Senha não informada');
    });
  });

  group('tipoErroDeLinha - filtro por detalhe', () {
    test('linha de erro local de senha é filtrada como Senha', () {
      const GuiaValidada guiaLocal = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(campo: 'senha', mensagem: 'Senha não informada'),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaLocal).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.senha);
    });

    test('linha da consulta de elegibilidade é filtrada pelo motivo', () {
      const GuiaValidada guiaConsulta = GuiaValidada(
        guia: guia,
        erros: [],
        consultas: [
          ConsultaGuia(
            sucesso: false,
            descricao: 'Beneficiário não elegível',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaConsulta).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.carteira);
    });

    test('linha de carteira não encontrada é filtrada como Carteira', () {
      const GuiaValidada guiaCarteira = GuiaValidada(
        guia: guia,
        erros: [],
        consultas: [
          ConsultaGuia(
            sucesso: false,
            descricao: 'Carteira não encontrada',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaCarteira).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.carteira);
    });

    test('linha de VPP (senha inválida/negada) é filtrada como Senha', () {
      const GuiaValidada guiaVpp = GuiaValidada(
        guia: guia,
        erros: [],
        consultas: [
          ConsultaGuia(
            tipo: TipoConsultaGuia.autorizacaoVpp,
            sucesso: false,
            descricao: 'Senha inválida (5056430843)',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaVpp).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.senha);
    });
  });
}
