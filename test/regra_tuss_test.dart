import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/tuss_base_local_datasource.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/erro_validacao.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/guia_tiss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/procedimento.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/repositories/regras/regra_tuss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/classificador_tuss_local.dart';

import 'support/asset_bundle_fake.dart';

String _dataset(
  String tabela,
  String snapshot,
  List<Map<String, Object?>> itens,
) =>
    jsonEncode({
      'formato': 1,
      'tabela': tabela,
      'snapshot': snapshot,
      'totalItens': itens.length,
      'itens': itens,
    });

Map<String, Object?> _item(String id, {String? fim}) => {
      'id': id,
      'nome': 'Item $id',
      'inicioVigencia': '2020-01-01',
      'fimVigencia': fim,
    };

ClassificadorTussLocal _classificador() {
  final AssetBundleFake bundle = AssetBundleFake({
    TussBaseLocalDatasource.caminhoManifesto: jsonEncode({
      'formato': 1,
      'tabelas': {
        '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
        '19': {'snapshot': '20260526', 'dataset': null},
        '22': {'snapshot': '20261023', 'dataset': 'tuss-22.json'},
      },
    }),
    '${TussBaseLocalDatasource.pasta}/tuss-18.json':
        _dataset('18', '20261025', [
      _item('60036842'),
    ]),
    '${TussBaseLocalDatasource.pasta}/tuss-22.json':
        _dataset('22', '20261023', [
      _item('50001043', fim: '2026-12-31'),
      _item('50001050', fim: '2020-01-01'),
    ]),
  });
  return ClassificadorTussLocal(
    base: TussBaseLocalDatasource(bundle: bundle),
    relogio: () => DateTime(2026, 10, 25),
  );
}

GuiaTiss _guia(List<Procedimento> procedimentos) => GuiaTiss(
      numeroGuiaPrestador: '1',
      numeroCarteira: null,
      senha: null,
      procedimentos: procedimentos,
    );

void main() {
  group('RegraTuss', () {
    late ClassificadorTussLocal classificador;
    late RegraTuss regra;

    setUp(() async {
      classificador = _classificador();
      regra = RegraTuss(classificador);
      await classificador.preparar();
    });

    test('aceita código na tabela declarada e vigente', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '50001043',
            quantidade: 1,
            codigoTabela: '22',
          ),
        ]),
      );

      expect(erro, isNull);
    });

    test('acusa código ausente da tabela declarada', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '99999999',
            quantidade: 1,
            codigoTabela: '18',
          ),
        ]),
      );

      expect(erro, isNotNull);
      expect(erro!.campo, 'tuss');
      expect(
        erro.mensagem,
        contains('Código 99999999 não encontrado na tabela 18'),
      );
    });

    test('acusa código que pertence a outra tabela', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '50001043',
            quantidade: 1,
            codigoTabela: '18',
          ),
        ]),
      );

      expect(erro, isNotNull);
      expect(
        erro!.mensagem,
        contains('Código 50001043 pertence à tabela 22, não à 18'),
      );
    });

    test('acusa código vencido', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '50001050',
            quantidade: 1,
            codigoTabela: '22',
          ),
        ]),
      );

      expect(erro, isNotNull);
      expect(erro!.mensagem, contains('vencido desde 2020-01-01'));
    });

    test('acusa código oficial declarado em tabela sem referência', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '60036842',
            quantidade: 1,
            codigoTabela: '90',
          ),
        ]),
      );

      expect(erro, isNotNull);
      expect(erro!.mensagem, contains('pertence à tabela 18, não à 90'));
    });

    test('ignora código próprio de tabela sem referência', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '00000000',
            quantidade: 1,
            codigoTabela: '90',
          ),
        ]),
      );

      expect(erro, isNull);
    });

    test('ignora tabela desconhecida e tabela sem base local', () {
      for (final String tabela in ['87', '19']) {
        final ErroValidacao? erro = regra.validar(
          _guia([
            Procedimento(
              codigo: '12345678',
              quantidade: 1,
              codigoTabela: tabela,
            ),
          ]),
        );
        expect(erro, isNull, reason: tabela);
      }
    });

    test('ignora procedimento sem codigoTabela', () {
      final ErroValidacao? erro = regra.validar(
        _guia([const Procedimento(codigo: '99999999', quantidade: 1)]),
      );

      expect(erro, isNull);
    });

    test('agrupa e deduplica os problemas da guia', () {
      final ErroValidacao? erro = regra.validar(
        _guia([
          const Procedimento(
            codigo: '99999999',
            quantidade: 1,
            codigoTabela: '18',
          ),
          const Procedimento(
            codigo: '99999999',
            quantidade: 1,
            codigoTabela: '18',
          ),
          const Procedimento(
            codigo: '50001043',
            quantidade: 1,
            codigoTabela: '18',
          ),
        ]),
      );

      expect(erro, isNotNull);
      expect(
        'Código 99999999'.allMatches(erro!.mensagem).length,
        1,
      );
      expect(erro.mensagem, contains('pertence à tabela 22'));
    });

    test('não valida enquanto a base não foi preparada', () {
      final RegraTuss semBase = RegraTuss(_classificador());

      final ErroValidacao? erro = semBase.validar(
        _guia([
          const Procedimento(
            codigo: '99999999',
            quantidade: 1,
            codigoTabela: '18',
          ),
        ]),
      );

      expect(erro, isNull);
    });
  });
}
