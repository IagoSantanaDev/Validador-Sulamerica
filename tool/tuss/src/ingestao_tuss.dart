import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const Map<String, int> _contagensEsperadasPadrao = {
  '18': 3595,
  '19': 1389786,
  '20': 43376,
  '22': 5969,
};

const Map<int, int> _totalApiMedidoPadrao = {
  18: 3595,
  19: 1389786,
  20: 43376,
  22: 5964,
};

const Set<String> _tabelasComDatasetPadrao = {'18', '20', '22'};

class IngestaoException implements Exception {
  const IngestaoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class ArquivoTabela {
  const ArquivoTabela({
    required this.tabela,
    required this.snapshot,
    required this.parte,
    required this.arquivo,
  });

  final String tabela;
  final String snapshot;
  final int parte;
  final File arquivo;
}

class ItemTuss {
  const ItemTuss({
    required this.id,
    required this.nome,
    required this.inicioVigencia,
    required this.fimVigencia,
  });

  final String id;
  final String nome;
  final String? inicioVigencia;
  final String? fimVigencia;

  Map<String, Object?> paraJson() => {
        'id': id,
        'nome': nome,
        'inicioVigencia': inicioVigencia,
        'fimVigencia': fimVigencia,
      };
}

class EstatisticasTabela {
  EstatisticasTabela({
    required this.tabela,
    required this.snapshot,
    required this.arquivos,
  });

  final String tabela;
  final String snapshot;
  final List<String> arquivos;

  int totalItens = 0;
  int duplicatas = 0;
  int semExtras = 0;
  int blocoExtrasIncompleto = 0;
  int semInicioVigencia = 0;
  int semFimVigencia = 0;
  int fimVigenciaHifen = 0;
  int fimVigenciaPassado = 0;
  int reparosDisplayName = 0;
  int reparosExtras = 0;
  int registrosReparados = 0;
  int nomesVazios = 0;
  final Set<String> ids = {};
  final List<String> erros = [];
  final List<String> exemplosReparo = [];

  Map<String, Object?> paraManifesto({String? dataset, String? hash}) => {
        'tabela': tabela,
        'snapshot': snapshot,
        'arquivos': arquivos,
        'totalItens': totalItens,
        'dataset': dataset,
        'sha256': hash,
      };
}

class RelatorioIngestao {
  const RelatorioIngestao({
    required this.geradoEm,
    required this.hoje,
    required this.entrada,
    required this.saida,
    required this.tabelas,
    required this.avisos,
    required this.erros,
  });

  final DateTime geradoEm;
  final String hoje;
  final String entrada;
  final String saida;
  final List<EstatisticasTabela> tabelas;
  final List<String> avisos;
  final List<String> erros;
}

class IngestaoTuss {
  factory IngestaoTuss({
    required String entrada,
    required String saida,
    required String relatorio,
    required DateTime hoje,
    Map<String, int> contagensEsperadas = _contagensEsperadasPadrao,
    Set<String> tabelasComDataset = _tabelasComDatasetPadrao,
    Map<int, int> totalApiMedido = _totalApiMedidoPadrao,
  }) =>
      IngestaoTuss._(
        entrada,
        saida,
        relatorio,
        DateTime.utc(hoje.year, hoje.month, hoje.day),
        contagensEsperadas,
        tabelasComDataset,
        totalApiMedido,
      );

  IngestaoTuss._(
    this.entrada,
    this.saida,
    this.relatorio,
    this._hoje,
    this._contagensEsperadas,
    this._tabelasComDataset,
    this._totalApiMedido,
  );

  final String entrada;
  final String saida;
  final String relatorio;
  final DateTime _hoje;
  final Map<String, int> _contagensEsperadas;
  final Set<String> _tabelasComDataset;
  final Map<int, int> _totalApiMedido;

  Future<RelatorioIngestao> executar() async {
    final Directory diretorioEntrada = Directory(entrada);
    if (!await diretorioEntrada.exists()) {
      throw IngestaoException('Pasta de entrada não encontrada: $entrada');
    }

    final List<ArquivoTabela> arquivos =
        await descobrirArquivos(diretorioEntrada);
    final Map<String, List<ArquivoTabela>> porTabela = {};
    for (final ArquivoTabela arquivo in arquivos) {
      porTabela.putIfAbsent(arquivo.tabela, () => []).add(arquivo);
    }

    final Directory diretorioSaida = Directory(saida);
    final List<String> erros = [];
    for (final String tabela in _contagensEsperadas.keys) {
      if (!porTabela.containsKey(tabela)) {
        erros.add('Tabela $tabela não encontrada na entrada.');
      }
    }
    final DateTime geradoEm = DateTime.now().toUtc();
    final String hoje = _formatarData(_hoje);
    final List<EstatisticasTabela> estatisticas = [];
    final Map<String, List<ItemTuss>> itensPorTabela = {};
    final List<String> avisos = [];

    final List<String> tabelas = porTabela.keys.toList()
      ..sort((String a, String b) => int.parse(a).compareTo(int.parse(b)));

    for (final String tabela in tabelas) {
      final List<ArquivoTabela> arquivosTabela = porTabela[tabela]!
        ..sort(
          (ArquivoTabela a, ArquivoTabela b) => a.parte.compareTo(b.parte),
        );
      final EstatisticasTabela estatistica = await _processarTabela(
        tabela,
        arquivosTabela,
      );
      estatisticas.add(estatistica);
      erros.addAll(estatistica.erros);

      final int esperado =
          _contagensEsperadas[tabela] ?? estatistica.totalItens;
      if (estatistica.totalItens != esperado) {
        erros.add(
          'Tabela $tabela: $esperado itens esperados, '
          '${estatistica.totalItens} encontrados.',
        );
      }

      if (_tabelasComDataset.contains(tabela)) {
        itensPorTabela[tabela] = await _carregarItens(arquivosTabela);
      }

      final int? totalApi = _totalApiMedido[int.parse(tabela)];
      if (totalApi != null && totalApi != estatistica.totalItens) {
        avisos.add(
          'Tabela $tabela: ${estatistica.totalItens} itens no snapshot e '
          '$totalApi medidos na API; ${estatistica.totalItens - totalApi} '
          'sem reconciliação registrada.',
        );
      }
    }

    final RelatorioIngestao resultado = RelatorioIngestao(
      geradoEm: geradoEm,
      hoje: hoje,
      entrada: _nomePasta(entrada),
      saida: saida,
      tabelas: estatisticas,
      avisos: avisos,
      erros: erros,
    );

    if (erros.isNotEmpty) {
      await _escreverRelatorio(resultado);
      throw IngestaoException(erros.join('\n'));
    }

    await diretorioSaida.create(recursive: true);
    await _limparDatasetsAntigos(diretorioSaida);

    final Map<String, Object?> manifestoTabelas = {};
    for (final String tabela in tabelas) {
      final EstatisticasTabela estatistica = estatisticas.firstWhere(
        (EstatisticasTabela item) => item.tabela == tabela,
      );
      String? dataset;
      String? hash;
      final List<ItemTuss>? itens = itensPorTabela[tabela];
      if (itens != null) {
        final String conteudo = jsonEncode({
          'formato': 1,
          'tabela': tabela,
          'snapshot': estatistica.snapshot,
          'totalItens': itens.length,
          'itens': itens.map((ItemTuss item) => item.paraJson()).toList(),
        });
        dataset = 'tuss-$tabela.json';
        hash = sha256.convert(utf8.encode(conteudo)).toString();
        await File('${diretorioSaida.path}/$dataset')
            .writeAsString(conteudo, encoding: utf8, flush: true);
      }
      manifestoTabelas[tabela] = estatistica.paraManifesto(
        dataset: dataset,
        hash: hash,
      );
    }

    final Map<String, Object?> manifesto = {
      'formato': 1,
      'geradoEm': geradoEm.toIso8601String(),
      'referenciaVigencia': hoje,
      'tabelas': manifestoTabelas,
    };
    await File('${diretorioSaida.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifesto),
      encoding: utf8,
      flush: true,
    );

    await _escreverRelatorio(resultado);
    return resultado;
  }

  Future<List<ArquivoTabela>> descobrirArquivos(Directory diretorio) async {
    final RegExp comSeparador =
        RegExp(r'^tuss-(\d{2})_(\d{8})(?:\((\d+)\))?\.json$');
    final RegExp semSeparador =
        RegExp(r'^tuss-(\d{2})(\d{8})(?:\((\d+)\))?\.json$');
    final List<ArquivoTabela> resultado = [];

    await for (final FileSystemEntity entidade in diretorio.list()) {
      if (entidade is! File) continue;
      final String nome = entidade.uri.pathSegments.last;
      if (!nome.startsWith('tuss-') || !nome.endsWith('.json')) continue;

      final RegExpMatch? match =
          comSeparador.firstMatch(nome) ?? semSeparador.firstMatch(nome);
      if (match == null) {
        throw IngestaoException(
          'Nome de arquivo TUSS não reconhecido: $nome',
        );
      }
      resultado.add(
        ArquivoTabela(
          tabela: match.group(1)!,
          snapshot: match.group(2)!,
          parte: int.tryParse(match.group(3) ?? '1') ?? 1,
          arquivo: entidade,
        ),
      );
    }

    if (resultado.isEmpty) {
      throw IngestaoException(
        'Nenhum arquivo tuss-<n>*.json encontrado em ${diretorio.path}',
      );
    }
    resultado.sort((ArquivoTabela a, ArquivoTabela b) {
      final int porTabela = a.tabela.compareTo(b.tabela);
      return porTabela != 0 ? porTabela : a.parte.compareTo(b.parte);
    });
    return resultado;
  }

  Future<EstatisticasTabela> _processarTabela(
    String tabela,
    List<ArquivoTabela> arquivos,
  ) async {
    final Set<String> snapshots =
        arquivos.map((ArquivoTabela a) => a.snapshot).toSet();
    if (snapshots.length != 1) {
      throw IngestaoException(
        'Tabela $tabela tem snapshots diferentes: ${snapshots.join(', ')}',
      );
    }

    final EstatisticasTabela estatistica = EstatisticasTabela(
      tabela: tabela,
      snapshot: snapshots.single,
      arquivos: arquivos
          .map((ArquivoTabela a) => a.arquivo.uri.pathSegments.last)
          .toList(),
    );

    for (final ArquivoTabela arquivo in arquivos) {
      final Object? decodificado = jsonDecode(
        await arquivo.arquivo.readAsString(encoding: utf8),
      );
      if (decodificado is! List) {
        throw IngestaoException(
          '${arquivo.arquivo.path}: raiz do JSON não é uma lista.',
        );
      }

      for (final Object? elemento in decodificado) {
        if (elemento is! Map<String, dynamic>) {
          throw IngestaoException(
            '${arquivo.arquivo.path}: item não é um objeto JSON.',
          );
        }
        _validarItem(tabela, elemento, estatistica);
      }
    }
    return estatistica;
  }

  void _validarItem(
    String tabela,
    Map<String, dynamic> item,
    EstatisticasTabela estatistica,
  ) {
    estatistica.totalItens++;

    final Object? idBruto = item['id'];
    if (idBruto is! String || idBruto.isEmpty) {
      estatistica.erros.add(
        'Tabela $tabela: item ${estatistica.totalItens} com id ausente ou vazio.',
      );
    } else {
      if (!RegExp(r'^\d+$').hasMatch(idBruto)) {
        estatistica.erros.add(
          'Tabela $tabela: id não numérico "$idBruto".',
        );
      }
      if (idBruto.length != 8 && idBruto.length != 9) {
        estatistica.erros.add(
          'Tabela $tabela: id com ${idBruto.length} dígitos "$idBruto".',
        );
      }
      if (!estatistica.ids.add(idBruto)) {
        estatistica.duplicatas++;
        estatistica.erros.add(
          'Tabela $tabela: id duplicado "$idBruto".',
        );
      }
    }

    final Object? source = item['source'];
    if (source != 'tuss-$tabela') {
      estatistica.erros.add(
        'Tabela $tabela: source "${source ?? ''}" não corresponde à tabela.',
      );
    }

    final Object? nomeBruto = item['display_name'];
    var reparou = false;
    if (nomeBruto is! String || nomeBruto.isEmpty) {
      estatistica.nomesVazios++;
    } else if (repararDuplaCodificacao(nomeBruto) != null) {
      estatistica.reparosDisplayName++;
      reparou = true;
    }

    final Object? extrasBruto = item['extras'];
    if (extrasBruto == null ||
        (extrasBruto is Map<String, dynamic> && extrasBruto.isEmpty)) {
      estatistica.semExtras++;
      estatistica.blocoExtrasIncompleto++;
      estatistica.semInicioVigencia++;
      estatistica.semFimVigencia++;
      if (reparou) estatistica.registrosReparados++;
      return;
    }
    if (extrasBruto is! Map<String, dynamic>) {
      estatistica.erros.add(
        'Tabela $tabela: extras não é um objeto JSON.',
      );
      if (reparou) estatistica.registrosReparados++;
      return;
    }

    final Object? inicioBruto = extrasBruto['inicio_vigencia'];
    final Object? fimBruto = extrasBruto['fim_vigencia'];

    if (inicioBruto is! String || inicioBruto.isEmpty || inicioBruto == '-') {
      estatistica.semInicioVigencia++;
    } else {
      _validarData(tabela, 'inicio_vigencia', inicioBruto, estatistica);
    }

    if (!extrasBruto.containsKey('fim_vigencia') ||
        fimBruto == null ||
        (fimBruto is String && fimBruto.isEmpty)) {
      estatistica.semFimVigencia++;
    } else if (fimBruto == '-') {
      estatistica.fimVigenciaHifen++;
    } else if (fimBruto is! String) {
      estatistica.erros.add(
        'Tabela $tabela: fim_vigencia não é texto.',
      );
    } else {
      final DateTime? fim = _validarData(
        tabela,
        'fim_vigencia',
        fimBruto,
        estatistica,
      );
      if (fim != null && fim.isBefore(_hoje)) {
        estatistica.fimVigenciaPassado++;
      }
    }

    if (!extrasBruto.containsKey('inicio_vigencia') ||
        !extrasBruto.containsKey('fim_vigencia')) {
      estatistica.blocoExtrasIncompleto++;
    }

    for (final MapEntry<String, Object?> campo in extrasBruto.entries) {
      final Object? valor = campo.value;
      if (valor is! String) continue;
      final String? reparado = repararDuplaCodificacao(valor);
      if (reparado == null) continue;
      estatistica.reparosExtras++;
      reparou = true;
      if (estatistica.exemplosReparo.length < 3) {
        estatistica.exemplosReparo.add('${campo.key}: $valor -> $reparado');
      }
    }

    if (reparou) estatistica.registrosReparados++;
  }

  DateTime? _validarData(
    String tabela,
    String campo,
    String valor,
    EstatisticasTabela estatistica,
  ) {
    final DateTime? data = DateTime.tryParse(valor);
    if (data == null || _formatarData(data) != valor) {
      estatistica.erros.add(
        'Tabela $tabela: $campo com valor inválido "$valor".',
      );
      return null;
    }
    return DateTime.utc(data.year, data.month, data.day);
  }

  Future<List<ItemTuss>> _carregarItens(
    List<ArquivoTabela> arquivos,
  ) async {
    final List<ItemTuss> itens = [];
    for (final ArquivoTabela arquivo in arquivos) {
      final List<dynamic> lista =
          jsonDecode(await arquivo.arquivo.readAsString(encoding: utf8))
              as List<dynamic>;
      for (final dynamic elemento in lista) {
        final Map<String, dynamic> item = elemento as Map<String, dynamic>;
        final Map<String, dynamic> extras =
            (item['extras'] as Map<String, dynamic>?) ?? {};
        itens.add(
          ItemTuss(
            id: item['id'] as String,
            nome: _repararOuManter(item['display_name'] as String? ?? ''),
            inicioVigencia: _dataOuNulo(extras['inicio_vigencia']),
            fimVigencia: _dataOuNulo(extras['fim_vigencia']),
          ),
        );
      }
    }
    return itens;
  }

  String? _dataOuNulo(Object? valor) {
    if (valor is! String || valor.isEmpty || valor == '-') return null;
    return DateTime.tryParse(valor) == null ? null : valor;
  }

  String _repararOuManter(String? valor) {
    if (valor == null) return '';
    return repararDuplaCodificacao(valor) ?? valor;
  }

  Future<void> _limparDatasetsAntigos(Directory diretorio) async {
    final RegExp dataset = RegExp(r'^tuss-\d+\.json$');
    await for (final FileSystemEntity entidade in diretorio.list()) {
      if (entidade is! File) continue;
      final String nome = entidade.uri.pathSegments.last;
      if (dataset.hasMatch(nome) || nome == 'manifest.json') {
        await entidade.delete();
      }
    }
  }

  Future<void> _escreverRelatorio(RelatorioIngestao dados) async {
    final StringBuffer buffer = StringBuffer()
      ..writeln('# Relatório de ingestão TUSS')
      ..writeln()
      ..writeln('- Gerado em: ${dados.geradoEm.toIso8601String()}')
      ..writeln('- Data de referência para vigência: ${dados.hoje}')
      ..writeln('- Entrada: `${dados.entrada}`')
      ..writeln('- Saída: `${dados.saida}`')
      ..writeln()
      ..writeln('## Resumo')
      ..writeln()
      ..writeln(
        '| Tabela | Snapshot | Arquivos | Itens | Duplicatas | Erros | '
        'Nomes vazios | Reparos nome | Reparos extras | Registros reparados | '
        'Sem extras | Bloco incompleto | Sem início | Sem fim (ausente) | '
        'Fim "-" | Fim no passado |',
      )
      ..writeln(
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
      );

    for (final EstatisticasTabela tabela in dados.tabelas) {
      buffer.writeln(
        '| ${tabela.tabela} | ${tabela.snapshot} | ${tabela.arquivos.length} '
        '| ${tabela.totalItens} | ${tabela.duplicatas} | ${tabela.erros.length} '
        '| ${tabela.nomesVazios} | ${tabela.reparosDisplayName} '
        '| ${tabela.reparosExtras} | ${tabela.registrosReparados} '
        '| ${tabela.semExtras} '
        '| ${tabela.blocoExtrasIncompleto} | ${tabela.semInicioVigencia} '
        '| ${tabela.semFimVigencia} | ${tabela.fimVigenciaHifen} '
        '| ${tabela.fimVigenciaPassado} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Arquivos por tabela')
      ..writeln();
    for (final EstatisticasTabela tabela in dados.tabelas) {
      buffer.writeln('- ${tabela.tabela}: ${tabela.arquivos.join(', ')}');
    }

    final List<EstatisticasTabela> comReparo = dados.tabelas
        .where((EstatisticasTabela t) => t.exemplosReparo.isNotEmpty)
        .toList();
    if (comReparo.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Exemplos de reparo de dupla codificação')
        ..writeln();
      for (final EstatisticasTabela tabela in comReparo) {
        for (final String exemplo in tabela.exemplosReparo) {
          buffer.writeln('- ${tabela.tabela}: $exemplo');
        }
      }
      buffer
        ..writeln()
        ..writeln(
          'Resíduos como `ÿ` (U+00FF) no texto reparado vêm de uma corrupção '
          'anterior, não da dupla codificação: o reparo desfaz apenas a camada '
          'comprovadamente reversível e mantém o restante como está.',
        );
    }

    if (dados.avisos.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Divergências conhecidas')
        ..writeln();
      for (final String aviso in dados.avisos) {
        buffer.writeln('- $aviso');
      }
    }

    if (dados.erros.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Erros de invariante')
        ..writeln();
      for (final String erro in dados.erros) {
        buffer.writeln('- $erro');
      }
    }

    buffer
      ..writeln()
      ..writeln(
        dados.erros.isEmpty
            ? '## Invariantes verificados'
            : '## Invariantes que falharam',
      )
      ..writeln()
      ..writeln('- Contagem esperada por tabela.')
      ..writeln('- `id` presente, numérico, com 8 ou 9 dígitos e único.')
      ..writeln('- `source` igual a `tuss-<tabela>`.')
      ..writeln('- Datas de vigência em `AAAA-MM-DD` quando presentes.')
      ..writeln('- Snapshot único por tabela.')
      ..writeln('- Todos os arquivos da tabela com o mesmo snapshot.');

    final File arquivo = File(relatorio);
    await arquivo.parent.create(recursive: true);
    await arquivo.writeAsString(buffer.toString(), encoding: utf8, flush: true);
  }

  String _formatarData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  String _nomePasta(String caminho) {
    final List<String> partes = Directory(caminho)
        .uri
        .pathSegments
        .where((String parte) => parte.isNotEmpty)
        .toList();
    return partes.isEmpty ? caminho : partes.last;
  }
}

String? repararDuplaCodificacao(String texto) {
  if (texto.isEmpty) return null;
  try {
    final List<int> bytes = latin1.encode(texto);
    final String reparado = utf8.decode(bytes);
    return reparado == texto ? null : reparado;
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}
