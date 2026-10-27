import 'package:flutter/material.dart';
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
      ErroValidacao(campo: 'crm', mensagem: 'CRM inválido'),
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
      expect(linhas[1].detalhe, 'CRM inválido');
      expect(linhas[2].detalhe, 'Carteira não encontrada');
      for (final LinhaGradeGuia linha in linhas) {
        expect(linha.guia, same(guiaMulti));
      }
    });

    test('mantém a ordem de erros locais antes das consultas', () {
      final List<LinhaGradeGuia> linhas = linhasDeGuia(guiaMulti);

      expect(linhas.last.detalhe, 'Carteira não encontrada');
    });

    test('sem consulta gera uma linha por erro local', () {
      const GuiaValidada soErroLocal = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(campo: 'crm', mensagem: 'CRM inválido'),
        ],
      );

      final List<LinhaGradeGuia> linhas = linhasDeGuia(soErroLocal);
      expect(linhas, hasLength(1));
      expect(linhas.single.detalhe, 'CRM inválido');
    });

    test('consulta bem-sucedida (Elegível: SIM) não vira linha de erro', () {
      const GuiaValidada elegivelSim = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(campo: 'crm', mensagem: 'CRM inválido'),
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
      expect(linhas.single.detalhe, 'CRM inválido');
    });
  });

  group('agruparPorDetalhe - ordenação da grade', () {
    test('agrupa detalhes iguais sem reordenar categorias especiais', () {
      final List<LinhaGradeGuia> linhas = agruparPorDetalhe([
        const LinhaGradeGuia(guia: guiaMulti, detalhe: 'CRM inválido'),
        const LinhaGradeGuia(
          guia: guiaMulti,
          detalhe: 'Carteira não encontrada',
        ),
        const LinhaGradeGuia(guia: guiaMulti, detalhe: 'CRM inválido'),
        const LinhaGradeGuia(
          guia: guiaMulti,
          detalhe: 'Carteira não encontrada',
        ),
      ]);

      expect(linhas, hasLength(4));
      expect(linhas[0].detalhe, 'CRM inválido');
      expect(linhas[1].detalhe, 'CRM inválido');
      expect(linhas[2].detalhe, 'Carteira não encontrada');
      expect(linhas[3].detalhe, 'Carteira não encontrada');
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

    test('erro local do CRM é filtrado como CRM', () {
      const GuiaValidada guiaCrm = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(
            campo: 'crm',
            mensagem: 'CRM deve ter no máximo 5 dígitos (123456)',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaCrm).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.crm);
      expect(rotuloTipoErro(TipoErroGuia.crm), 'CRM');
    });

    test('erro de tabela TUSS é filtrado como Procedimento', () {
      const GuiaValidada guiaTuss = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(
            campo: 'tuss',
            mensagem: 'Código 50001043 pertence à tabela 22, não à 18.',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaTuss).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.procedimento);
      expect(rotuloTipoErro(TipoErroGuia.procedimento), 'Procedimento');
    });

    test('erro local VPP aparece nos filtros Senha e Procedimento', () {
      const GuiaValidada guiaVpp = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(
            campo: 'senha',
            mensagem: 'Senha obrigatória para procedimento(s): 12345678',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaVpp).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.senha);
      expect(
        tiposErroDeLinha(linha),
        containsAll([TipoErroGuia.senha, TipoErroGuia.procedimento]),
      );
    });

    test('erro de data de autorização é filtrado como Data', () {
      const GuiaValidada guiaData = GuiaValidada(
        guia: guia,
        erros: [
          ErroValidacao(
            campo: 'dataAutorizacao',
            mensagem:
                'Data de autorização (2026-10-14) posterior à execução (2026-10-01)',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaData).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.data);
      expect(rotuloTipoErro(TipoErroGuia.data), 'Data');
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
      const GuiaValidada guiaSenha = GuiaValidada(
        guia: guia,
        erros: [],
        consultas: [
          ConsultaGuia(
            tipo: TipoConsultaGuia.senha,
            sucesso: false,
            descricao: 'Senha inválida (5056430843)',
          ),
        ],
      );
      final LinhaGradeGuia linha = linhasDeGuia(guiaSenha).single;

      expect(tipoErroDeLinha(linha), TipoErroGuia.senha);
    });
  });

  testWidgets('exibe carteira e senha sem alterar espacos', (tester) async {
    const String carteiraLiteral = ' 557888884823194700 20 ';
    const String senhaLiteral = ' 5056430843 ';
    const GuiaTiss guiaComEspacos = GuiaTiss(
      numeroGuiaPrestador: '222',
      numeroCarteira: carteiraLiteral,
      senha: senhaLiteral,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GradeGuias(
            linhas: [
              LinhaGradeGuia(
                guia: GuiaValidada(guia: guiaComEspacos, erros: []),
                detalhe: 'Senha invalida',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.text(carteiraLiteral), findsOneWidget);
    expect(find.text(senhaLiteral), findsOneWidget);
  });

  testWidgets('exibe o rótulo CRM no detalhe do erro local', (tester) async {
    const GuiaValidada guiaCrm = GuiaValidada(
      guia: guia,
      erros: [
        ErroValidacao(
          campo: 'crm',
          mensagem: 'CRM deve ter no máximo 5 dígitos (123456)',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GradeGuias(
            linhas: [
              LinhaGradeGuia(
                guia: guiaCrm,
                detalhe: 'CRM deve ter no máximo 5 dígitos (123456)',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.text('CRM'), findsOneWidget);
  });
}
