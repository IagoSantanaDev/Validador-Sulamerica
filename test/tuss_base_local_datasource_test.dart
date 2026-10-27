import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/tuss_base_local_datasource.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/tuss_base_local_exceptions.dart';

import 'support/asset_bundle_fake.dart';

String _manifesto(Map<String, Map<String, Object?>> tabelas) => jsonEncode({
      'formato': 1,
      'tabelas': tabelas,
    });

String _dataset({
  required String tabela,
  required String snapshot,
  required List<Map<String, Object?>> itens,
  int? totalItens,
  String? tabelaDeclarada,
}) =>
    jsonEncode({
      'formato': 1,
      'tabela': tabelaDeclarada ?? tabela,
      'snapshot': snapshot,
      'totalItens': totalItens ?? itens.length,
      'itens': itens,
    });

Map<String, Object?> _item(
  String id, {
  String nome = 'Procedimento',
  String? inicio = '2020-01-01',
  String? fim,
}) =>
    {
      'id': id,
      'nome': nome,
      'inicioVigencia': inicio,
      'fimVigencia': fim,
    };

AssetBundleFake _bundle({
  required Map<String, Map<String, Object?>> tabelas,
  required Map<String, String> datasets,
}) =>
    AssetBundleFake({
      TussBaseLocalDatasource.caminhoManifesto: _manifesto(tabelas),
      for (final MapEntry<String, String> dataset in datasets.entries)
        '${TussBaseLocalDatasource.pasta}/${dataset.key}': dataset.value,
    });

void main() {
  group('TussBaseLocalDatasource', () {
    test('indexa datasets e expõe tabela, snapshot e base local', () async {
      final TussBaseLocalDatasource base = TussBaseLocalDatasource(
        bundle: _bundle(
          tabelas: {
            '18': {
              'tabela': '18',
              'snapshot': '20261025',
              'dataset': 'tuss-18.json',
            },
            '19': {'tabela': '19', 'snapshot': '20260526', 'dataset': null},
            '22': {
              'tabela': '22',
              'snapshot': '20261023',
              'dataset': 'tuss-22.json',
            },
          },
          datasets: {
            'tuss-18.json': _dataset(
              tabela: '18',
              snapshot: '20261025',
              itens: [_item('60036842', nome: 'Taxa de ventilação')],
            ),
            'tuss-22.json': _dataset(
              tabela: '22',
              snapshot: '20261023',
              itens: [
                _item('50001043', nome: 'Fisioterapia', fim: '2026-12-31'),
              ],
            ),
          },
        ),
      );

      expect(base.carregada, isFalse);
      await base.carregar();

      expect(base.carregada, isTrue);
      expect(base.tabelas, {'18', '19', '22'});
      expect(base.tabelasComBase, {'18', '22'});
      expect(base.temBaseLocal('19'), isFalse);
      expect(base.temBaseLocal('18'), isTrue);
      expect(base.snapshotDaTabela('19'), '20260526');
      expect(base.snapshotDaTabela('87'), isNull);
      expect(base.buscar('60036842')?.tabela, '18');
      expect(base.buscar('60036842')?.nome, 'Taxa de ventilação');
      expect(base.buscar('50001043')?.fimVigencia, '2026-12-31');
      expect(base.buscar('99999999'), isNull);
    });

    test('recusa o mesmo código em duas tabelas', () async {
      final TussBaseLocalDatasource base = TussBaseLocalDatasource(
        bundle: _bundle(
          tabelas: {
            '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
            '22': {'snapshot': '20261023', 'dataset': 'tuss-22.json'},
          },
          datasets: {
            'tuss-18.json': _dataset(
              tabela: '18',
              snapshot: '20261025',
              itens: [_item('50001043')],
            ),
            'tuss-22.json': _dataset(
              tabela: '22',
              snapshot: '20261023',
              itens: [_item('50001043')],
            ),
          },
        ),
      );

      await expectLater(
        base.carregar(),
        throwsA(
          isA<TussBaseLocalInvalidaException>().having(
            (erro) => erro.mensagem,
            'mensagem',
            contains('18 e 22'),
          ),
        ),
      );
    });

    test('recusa dataset com contagem diferente da declarada', () async {
      final TussBaseLocalDatasource base = TussBaseLocalDatasource(
        bundle: _bundle(
          tabelas: {
            '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
          },
          datasets: {
            'tuss-18.json': _dataset(
              tabela: '18',
              snapshot: '20261025',
              itens: [_item('60036842')],
              totalItens: 2,
            ),
          },
        ),
      );

      await expectLater(
        base.carregar(),
        throwsA(
          isA<TussBaseLocalInvalidaException>().having(
            (erro) => erro.mensagem,
            'mensagem',
            contains('declara 2'),
          ),
        ),
      );
    });

    test('recusa dataset de tabela diferente da anunciada', () async {
      final TussBaseLocalDatasource base = TussBaseLocalDatasource(
        bundle: _bundle(
          tabelas: {
            '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
          },
          datasets: {
            'tuss-18.json': _dataset(
              tabela: '18',
              tabelaDeclarada: '22',
              snapshot: '20261025',
              itens: [_item('60036842')],
            ),
          },
        ),
      );

      await expectLater(
        base.carregar(),
        throwsA(isA<TussBaseLocalInvalidaException>()),
      );
    });

    test('recusa item sem id ou nome', () async {
      final TussBaseLocalDatasource base = TussBaseLocalDatasource(
        bundle: _bundle(
          tabelas: {
            '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
          },
          datasets: {
            'tuss-18.json': _dataset(
              tabela: '18',
              snapshot: '20261025',
              itens: [
                {
                  'id': '',
                  'nome': 'Sem id',
                  'inicioVigencia': null,
                  'fimVigencia': null,
                },
              ],
            ),
          },
        ),
      );

      await expectLater(
        base.carregar(),
        throwsA(isA<TussBaseLocalInvalidaException>()),
      );
    });

    test('não fica carregada com manifesto inválido e permite nova tentativa',
        () async {
      final AssetBundleFake bundle = _bundle(
        tabelas: {
          '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
        },
        datasets: {
          'tuss-18.json': _dataset(
            tabela: '18',
            snapshot: '20261025',
            itens: [_item('60036842')],
          ),
        },
      );
      bundle.conteudos[TussBaseLocalDatasource.caminhoManifesto] = '{';
      final TussBaseLocalDatasource base =
          TussBaseLocalDatasource(bundle: bundle);

      await expectLater(
        base.carregar(),
        throwsA(isA<TussBaseLocalInvalidaException>()),
      );
      expect(base.carregada, isFalse);
      expect(base.buscar('60036842'), isNull);

      bundle.conteudos[TussBaseLocalDatasource.caminhoManifesto] = _manifesto({
        '18': {'snapshot': '20261025', 'dataset': 'tuss-18.json'},
      });
      await base.carregar();

      expect(base.carregada, isTrue);
      expect(base.buscar('60036842')?.tabela, '18');
    });
  });
}
