import 'dart:io';

import 'tuss/src/ingestao_tuss.dart';

Future<void> main(List<String> argumentos) async {
  try {
    final _Opcoes opcoes = _Opcoes.parse(argumentos);
    if (opcoes.ajuda) {
      stdout.writeln(_uso);
      return;
    }

    final RelatorioIngestao relatorio = await IngestaoTuss(
      entrada: opcoes.entrada!,
      saida: opcoes.saida,
      relatorio: opcoes.relatorio,
      hoje: opcoes.hoje ?? DateTime.now(),
    ).executar();

    stdout.writeln('Ingestão concluída.');
    stdout.writeln('Data de referência: ${relatorio.hoje}');
    for (final EstatisticasTabela tabela in relatorio.tabelas) {
      final String destino =
          tabela.tabela == '19' ? 'somente relatório' : 'dataset gerado';
      stdout.writeln(
        'tuss-${tabela.tabela}: ${tabela.totalItens} itens, '
        'snapshot ${tabela.snapshot}, $destino',
      );
    }
    stdout.writeln('Relatório: ${File(opcoes.relatorio).absolute.path}');
  } on IngestaoException catch (erro) {
    stderr.writeln('Ingestão falhou.');
    stderr.writeln(erro.mensagem);
    exitCode = 1;
  } on FileSystemException catch (erro) {
    stderr.writeln('Ingestão falhou: ${erro.message} (${erro.path})');
    exitCode = 1;
  }
}

const String _uso = 'Uso: dart run tool/tuss_ingestao.dart --entrada <pasta> '
    '[--saida assets/tuss] [--relatorio tool/relatorios/tuss-ingestao.md] '
    '[--hoje AAAA-MM-DD]';

class _Opcoes {
  const _Opcoes({
    required this.entrada,
    required this.saida,
    required this.relatorio,
    required this.hoje,
    required this.ajuda,
  });

  final String? entrada;
  final String saida;
  final String relatorio;
  final DateTime? hoje;
  final bool ajuda;

  factory _Opcoes.parse(List<String> argumentos) {
    final Map<String, String> valores = {};
    for (var indice = 0; indice < argumentos.length; indice++) {
      final String argumento = argumentos[indice];
      if (argumento == '--ajuda' || argumento == '-h') {
        return const _Opcoes(
          entrada: null,
          saida: 'assets/tuss',
          relatorio: 'tool/relatorios/tuss-ingestao.md',
          hoje: null,
          ajuda: true,
        );
      }
      if (!argumento.startsWith('--')) {
        throw IngestaoException('Argumento não reconhecido: $argumento\n$_uso');
      }
      final int separador = argumento.indexOf('=');
      if (separador != -1) {
        valores[argumento.substring(2, separador)] =
            argumento.substring(separador + 1);
        continue;
      }
      if (indice + 1 >= argumentos.length) {
        throw IngestaoException(
          'Faltou valor para ${argumento.substring(2)}.\n$_uso',
        );
      }
      valores[argumento.substring(2)] = argumentos[++indice];
    }

    const Set<String> permitidos = {
      'entrada',
      'saida',
      'relatorio',
      'hoje',
    };
    for (final String chave in valores.keys) {
      if (!permitidos.contains(chave)) {
        throw IngestaoException('Opção desconhecida: --$chave\n$_uso');
      }
    }

    final String? entrada = valores['entrada'];
    if (entrada == null || entrada.isEmpty) {
      throw const IngestaoException('Informe --entrada.\n$_uso');
    }

    final String? hojeTexto = valores['hoje'];
    DateTime? hoje;
    if (hojeTexto != null) {
      hoje = DateTime.tryParse(hojeTexto);
      if (hoje == null) {
        throw IngestaoException('Data inválida em --hoje: $hojeTexto');
      }
    }

    return _Opcoes(
      entrada: entrada,
      saida: valores['saida'] ?? 'assets/tuss',
      relatorio: valores['relatorio'] ?? 'tool/relatorios/tuss-ingestao.md',
      hoje: hoje,
      ajuda: false,
    );
  }
}
