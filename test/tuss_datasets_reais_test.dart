import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/datasources/tuss_base_local_datasource.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/models/resultado_consulta_tuss.dart';
import 'package:validador_xml_sulamerica/modules/validador_xml/data/services/classificador_tuss_local.dart';

/// Lê os assets direto do disco, para validar os datasets realmente versionados.
class _BundleDeArquivos extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

void main() {
  group('Datasets TUSS versionados', () {
    late TussBaseLocalDatasource base;
    late ClassificadorTussLocal classificador;

    setUpAll(() async {
      base = TussBaseLocalDatasource(bundle: _BundleDeArquivos());
      classificador = ClassificadorTussLocal(
        base: base,
        relogio: () => DateTime(2026, 10, 25),
      );
      await classificador.preparar();
    });

    test('carrega 18, 20 e 22 e mantém a 19 sem base local', () {
      expect(base.tabelasComBase, {'18', '20', '22'});
      expect(base.temBaseLocal('19'), isFalse);
      expect(base.buscar('60036842')?.tabela, '18');
      expect(base.buscar('90609468')?.tabela, '20');
      expect(base.buscar('50001043')?.tabela, '22');
    });

    test('confirma código na tabela declarada', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '30101492',
        tabela: '22',
      );

      expect(resultado, isA<TussEncontrado>());
      expect((resultado! as TussEncontrado).item.nome, isNotEmpty);
    });

    test('acusa código de outra tabela', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '30101492',
        tabela: '18',
      );

      expect(resultado, isA<TussTabelaDivergente>());
      expect((resultado! as TussTabelaDivergente).tabelaEncontrada, '22');
    });

    test('não encontra código inexistente na tabela com base', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '00000000',
        tabela: '20',
      );

      expect(resultado, isA<TussNaoEncontrado>());
    });

    test('deixa código da tabela 19 para o proxy', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '79993990',
        tabela: '19',
      );

      expect(resultado, isNull);
    });

    test('acusa código oficial declarado como 98', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '30101492',
        tabela: '98',
      );

      expect(resultado, isA<TussTabelaDivergente>());
      expect((resultado! as TussTabelaDivergente).tabelaEncontrada, '22');
    });

    test('aceita código próprio na tabela 90', () {
      final ResultadoConsultaTuss? resultado = classificador.classificar(
        codigo: '00000000',
        tabela: '90',
      );

      expect(resultado, isA<TussSemReferencia>());
    });
  });
}
