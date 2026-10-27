import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/tuss/src/ingestao_tuss.dart';

void main() {
  group('repararDuplaCodificacao', () {
    test('repara texto em dupla codificação', () {
      expect(repararDuplaCodificacao('ExÃ©rese'), 'Exérese');
      expect(repararDuplaCodificacao('CÃ\u0082NULA'), 'CÂNULA');
    });

    test('mantém texto já correto', () {
      expect(repararDuplaCodificacao('Exérese'), isNull);
      expect(repararDuplaCodificacao('AMILASE'), isNull);
      expect(repararDuplaCodificacao(''), isNull);
    });

    test('mantém texto que não é sequência UTF-8 válida', () {
      expect(repararDuplaCodificacao('AÇÃO'), isNull);
      expect(repararDuplaCodificacao('ç'), isNull);
      expect(repararDuplaCodificacao('CÃ‚NULA'), isNull);
    });
  });

  group('IngestaoTuss', () {
    late Directory raiz;

    setUp(() async {
      raiz = await Directory.systemTemp.createTemp('tuss_ingestao_');
    });

    tearDown(() async {
      await raiz.delete(recursive: true);
    });

    test('gera dataset compacto e manifesto com reparo e fim ausente',
        () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [
          _item(
            id: '30101492',
            nome: 'ExÃ©rese e sutura',
            extras: {
              'inicio_vigencia': '2009-02-13',
              'fim_vigencia': '-',
              'fim_implantacao': '2010-10-15',
            },
          ),
          _item(
            id: '30101493',
            nome: 'Consulta',
            extras: {'inicio_vigencia': '2009-02-13'},
          ),
        ],
      );

      final RelatorioIngestao relatorio = await _ingerir(
        raiz: raiz,
        entrada: entrada,
        contagens: {'22': 2},
        datasets: {'22'},
      );

      expect(relatorio.tabelas.single.totalItens, 2);
      expect(relatorio.tabelas.single.reparosDisplayName, 1);
      expect(relatorio.tabelas.single.registrosReparados, 1);
      expect(relatorio.tabelas.single.semFimVigencia, 1);
      expect(relatorio.erros, isEmpty);

      final Map<String, dynamic> dataset = jsonDecode(
        File('${raiz.path}/saida/tuss-22.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final List<dynamic> itens = dataset['itens'] as List<dynamic>;
      expect(dataset['snapshot'], '20260101');
      expect(itens, hasLength(2));
      expect(itens.first['nome'], 'Exérese e sutura');
      expect(itens.first['fimVigencia'], isNull);
      expect(itens.last['fimVigencia'], isNull);

      final Map<String, dynamic> manifesto = jsonDecode(
        File('${raiz.path}/saida/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final Map<String, dynamic> tabela = (manifesto['tabelas']
          as Map<String, dynamic>)['22'] as Map<String, dynamic>;
      expect(tabela['dataset'], 'tuss-22.json');
      expect((tabela['sha256'] as String).length, 64);
      expect(tabela['snapshot'], '20260101');
    });

    test('não gera dataset da tabela 19', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-1920260526(1).json',
        [
          _item(
            id: '73755281',
            nome: 'CÂNULA',
            source: 'tuss-19',
            extras: {'inicio_vigencia': '2020-01-01', 'fim_vigencia': '-'},
          ),
        ],
      );

      final RelatorioIngestao relatorio = await _ingerir(
        raiz: raiz,
        entrada: entrada,
        contagens: {'19': 1},
        datasets: const {},
      );

      expect(relatorio.tabelas.single.totalItens, 1);
      expect(File('${raiz.path}/saida/tuss-19.json').existsSync(), isFalse);

      final Map<String, dynamic> manifesto = jsonDecode(
        File('${raiz.path}/saida/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final Map<String, dynamic> tabela = (manifesto['tabelas']
          as Map<String, dynamic>)['19'] as Map<String, dynamic>;
      expect(tabela['dataset'], isNull);
      expect(tabela['sha256'], isNull);
    });

    test('falha e grava relatório quando há id duplicado', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [
          _item(id: '30101492'),
          _item(id: '30101492'),
        ],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 2},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );

      expect(File('${raiz.path}/saida/tuss-22.json').existsSync(), isFalse);
      final String relatorio =
          File('${raiz.path}/relatorios/tuss.md').readAsStringSync();
      expect(relatorio, contains('id duplicado'));
      expect(relatorio, contains('Invariantes que falharam'));
    });

    test('falha quando a contagem não corresponde ao esperado', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [_item(id: '30101492')],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 2},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );
    });

    test('falha com id vazio, não numérico ou com tamanho inválido', () async {
      for (final String id in ['', 'ABCDEFGH', '123', '1234567890']) {
        final Directory entrada = Directory('${raiz.path}/entrada_$id')
          ..createSync();
        _escreverArquivo(
          entrada,
          'tuss-22_20260101.json',
          [_item(id: id)],
        );

        await expectLater(
          _ingerir(
            raiz: raiz,
            entrada: entrada,
            contagens: {'22': 1},
            datasets: {'22'},
          ),
          throwsA(isA<IngestaoException>()),
          reason: 'id "$id" deveria falhar',
        );
      }
    });

    test('falha quando source não corresponde à tabela', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [_item(id: '30101492', source: 'tuss-20')],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 1},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );
    });

    test('falha com data de vigência inválida', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [
          _item(
            id: '30101492',
            extras: {'inicio_vigencia': '2026-02-30', 'fim_vigencia': '-'},
          ),
        ],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 1},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );
    });

    test('falha quando os arquivos da mesma tabela têm snapshots diferentes',
        () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-1920260526(1).json',
        [_item(id: '73755281', source: 'tuss-19')],
      );
      _escreverArquivo(
        entrada,
        'tuss-1920260527(2).json',
        [_item(id: '73755282', source: 'tuss-19')],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'19': 2},
          datasets: const {},
        ),
        throwsA(isA<IngestaoException>()),
      );
    });

    test('falha com nome de arquivo TUSS não reconhecido', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(entrada, 'tuss-22.json', [_item(id: '30101492')]);

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 1},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );
    });

    test('conta fim de vigência no passado e bloco de extras incompleto',
        () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [
          _item(
            id: '30101492',
            extras: {
              'inicio_vigencia': '2020-01-01',
              'fim_vigencia': '2020-12-31',
            },
          ),
          _item(id: '30101493', extras: {}),
          _item(id: '30101494', extras: null),
        ],
      );

      final RelatorioIngestao relatorio = await _ingerir(
        raiz: raiz,
        entrada: entrada,
        contagens: {'22': 3},
        datasets: {'22'},
        hoje: DateTime.utc(2026, 1, 1),
      );

      expect(relatorio.tabelas.single.fimVigenciaPassado, 1);
      expect(relatorio.tabelas.single.semExtras, 2);
      expect(relatorio.tabelas.single.blocoExtrasIncompleto, 2);
    });

    test('limpa datasets antigos só depois de validar', () async {
      final Directory entrada = Directory('${raiz.path}/entrada')..createSync();
      final Directory saida = Directory('${raiz.path}/saida')..createSync();
      File('${saida.path}/tuss-22.json').writeAsStringSync('antigo');
      _escreverArquivo(
        entrada,
        'tuss-22_20260101.json',
        [_item(id: '30101492')],
      );

      await expectLater(
        _ingerir(
          raiz: raiz,
          entrada: entrada,
          contagens: {'22': 2},
          datasets: {'22'},
        ),
        throwsA(isA<IngestaoException>()),
      );

      expect(File('${saida.path}/tuss-22.json').readAsStringSync(), 'antigo');
    });
  });
}

Future<RelatorioIngestao> _ingerir({
  required Directory raiz,
  required Directory entrada,
  required Map<String, int> contagens,
  required Set<String> datasets,
  DateTime? hoje,
}) {
  return IngestaoTuss(
    entrada: entrada.path,
    saida: '${raiz.path}/saida',
    relatorio: '${raiz.path}/relatorios/tuss.md',
    hoje: hoje ?? DateTime.utc(2026, 1, 1),
    contagensEsperadas: contagens,
    tabelasComDataset: datasets,
    totalApiMedido: const {},
  ).executar();
}

void _escreverArquivo(
  Directory diretorio,
  String nome,
  List<Map<String, dynamic>> itens,
) {
  File('${diretorio.path}/$nome')
      .writeAsStringSync(jsonEncode(itens), encoding: utf8);
}

Map<String, dynamic> _item({
  required String id,
  String nome = 'PRODUTO',
  String source = 'tuss-22',
  Map<String, dynamic>? extras = const {
    'inicio_vigencia': '2009-02-13',
    'fim_vigencia': '-',
  },
}) {
  return {
    'id': id,
    'source': source,
    'display_name': nome,
    'extras': extras,
  };
}
