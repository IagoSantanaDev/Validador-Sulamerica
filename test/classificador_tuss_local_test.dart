import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/tuss_base_local_datasource.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/resultado_consulta_tuss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/tuss_item.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/classificador_tuss_local.dart';

import 'support/asset_bundle_fake.dart';

final DateTime _hoje = DateTime(2026, 10, 25);

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

ClassificadorTussLocal _classificador({
  Set<String> tabelasOficiais = const {},
}) {
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
      _item('50001069', fim: '2026-10-25'),
    ]),
  });
  return ClassificadorTussLocal(
    base: TussBaseLocalDatasource(bundle: bundle),
    tabelasOficiais: tabelasOficiais,
    relogio: () => _hoje,
  );
}

void main() {
  group('ClassificadorTussLocal', () {
    test('encontra código na tabela declarada', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '60036842',
        tabela: '18',
      );

      expect(resultado, isA<TussEncontrado>());
      final TussEncontrado encontrado = resultado! as TussEncontrado;
      expect(encontrado.item.id, '60036842');
      expect(encontrado.item.tabela, '18');
      expect(encontrado.vigente, isTrue);
    });

    test('ignora espaços no código e na tabela', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: ' 60036842 ',
        tabela: ' 18 ',
      );

      expect(resultado, isA<TussEncontrado>());
    });

    test('marca como vigente no último dia de vigência', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '50001069',
        tabela: '22',
      );

      expect((resultado! as TussEncontrado).vigente, isTrue);
    });

    test('marca como vencido depois do fim da vigência', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '50001050',
        tabela: '22',
      );

      expect(resultado, isA<TussEncontrado>());
      expect((resultado! as TussEncontrado).vigente, isFalse);
    });

    test('não encontra código ausente da tabela com base local', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '99999999',
        tabela: '18',
      );

      expect(resultado, isA<TussNaoEncontrado>());
      expect((resultado! as TussNaoEncontrado).tabela, '18');
    });

    test('detecta código que pertence a outra tabela', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '50001043',
        tabela: '18',
      );

      expect(resultado, isA<TussTabelaDivergente>());
      final TussTabelaDivergente divergente =
          resultado! as TussTabelaDivergente;
      expect(divergente.tabelaDeclarada, '18');
      expect(divergente.tabelaEncontrada, '22');
    });

    test('detecta divergência mesmo quando a tabela declarada não tem base',
        () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '60036842',
        tabela: '19',
      );

      expect(resultado, isA<TussTabelaDivergente>());
      expect((resultado! as TussTabelaDivergente).tabelaEncontrada, '18');
    });

    test('deixa para o proxy quando a tabela válida não tem base local',
        () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '79993990',
        tabela: '19',
      );

      expect(resultado, isNull);
    });

    test('trata tabela oficial injetada como válida, ainda sem base', () async {
      final ClassificadorTussLocal classificador = _classificador(
        tabelasOficiais: {'87'},
      );
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '12345678',
        tabela: '87',
      );

      expect(resultado, isNull);
    });

    test('marca tabela fora da lista como desconhecida', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '12345678',
        tabela: '87',
      );

      expect(resultado, isA<TussTabelaDesconhecida>());
      expect((resultado! as TussTabelaDesconhecida).tabela, '87');
    });

    test('não trata tabelas 00 e 90–99 como erro de código', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      for (final String tabela in ['00', '90', '98', '99']) {
        final ResultadoConsultaTuss? resultado = classificador.classificar(
          codigo: '60036842',
          tabela: tabela,
        );
        expect(resultado, isA<TussSemReferencia>(), reason: tabela);
      }
    });

    test('não classifica antes de preparar', () {
      final ClassificadorTussLocal classificador = _classificador();

      expect(
        () => classificador.classificar(codigo: '60036842', tabela: '18'),
        throwsStateError,
      );
    });

    test('vigência sem data de fim permanece válida', () async {
      final ClassificadorTussLocal classificador = _classificador();
      await classificador.preparar();

      final TussEncontrado encontrado = classificador.classificar(
        codigo: '60036842',
        tabela: '18',
      )! as TussEncontrado;

      expect(encontrado.item, isA<TussItem>());
      expect(encontrado.item.fimVigencia, isNull);
      expect(encontrado.vigente, isTrue);
    });
  });
}
