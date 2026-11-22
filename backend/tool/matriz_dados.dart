import 'dart:convert';

import 'package:xml/xml.dart';

class ConsultaMatriz {
  const ConsultaMatriz({required this.tipo, required this.chave});

  final String tipo;
  final String chave;

  Map<String, String> toJson() => <String, String>{
        'tipo': tipo,
        'chave': chave,
      };
}

class ResultadoMatriz {
  const ResultadoMatriz({
    this.usuario = 0,
    required this.indice,
    required this.tipo,
    required this.sucesso,
    required this.latenciaMs,
    required this.statusHttp,
    required this.erro,
    required this.origem502,
    this.dominioDeterminado,
    this.tempoFilaMs,
    this.tempoSessaoMs,
    this.tempoPortalMs,
    this.tempoRetryMs,
    this.tempoExecucaoMs,
  });

  final int usuario;
  final int indice;
  final String tipo;
  final bool? sucesso;
  final int? latenciaMs;
  final int? statusHttp;
  final String? erro;
  final String? origem502;
  final bool? dominioDeterminado;
  final int? tempoFilaMs;
  final int? tempoSessaoMs;
  final int? tempoPortalMs;
  final int? tempoRetryMs;
  final int? tempoExecucaoMs;

  Map<String, Object?> toCsvRow() => <String, Object?>{
        'usuario': usuario,
        'indice': indice,
        'tipo': tipo,
        'sucesso': sucesso ?? '',
        'latencia_ms': latenciaMs ?? '',
        'status_http': statusHttp ?? '',
        'erro': erro ?? '',
        'origem_502': origem502 ?? '',
        'dominio_determinado': dominioDeterminado ?? '',
        'tempo_fila_ms': tempoFilaMs ?? '',
        'tempo_sessao_ms': tempoSessaoMs ?? '',
        'tempo_portal_ms': tempoPortalMs ?? '',
        'tempo_retry_ms': tempoRetryMs ?? '',
        'tempo_execucao_ms': tempoExecucaoMs ?? '',
      };
}

List<ConsultaMatriz> extrairConsultasXml(String conteudoXml) {
  final XmlDocument documento = XmlDocument.parse(conteudoXml);
  final Set<String> carteiras = <String>{};
  final Set<String> senhas = <String>{};
  for (final XmlElement guia in documento.findAllElements(
    'guiaSP-SADT',
    namespaceUri: '*',
  )) {
    for (final XmlElement item in guia.findAllElements(
      'numeroCarteira',
      namespaceUri: '*',
    )) {
      final String chave = item.innerText.trim();
      if (RegExp(r'^\d{20}$').hasMatch(chave)) carteiras.add(chave);
    }
    for (final XmlElement item in guia.findAllElements(
      'senha',
      namespaceUri: '*',
    )) {
      final String chave = item.innerText.trim();
      if (RegExp(r'^5\d{9}$').hasMatch(chave)) senhas.add(chave);
    }
  }
  return <ConsultaMatriz>[
    for (final String chave in carteiras)
      ConsultaMatriz(tipo: 'elegibilidade', chave: chave),
    for (final String chave in senhas)
      ConsultaMatriz(tipo: 'senha', chave: chave),
  ];
}

String extrairIdentificadorPrestadorXml(String conteudoXml) {
  final XmlDocument documento = XmlDocument.parse(conteudoXml);
  for (final XmlElement prestador in documento.findAllElements(
    'identificacaoPrestador',
    namespaceUri: '*',
  )) {
    for (final XmlElement cnpj in prestador.findAllElements(
      'CNPJ',
      namespaceUri: '*',
    )) {
      final String valor = cnpj.innerText.trim();
      if (RegExp(r'^\d{14}$').hasMatch(valor)) return valor;
    }
  }
  throw const FormatException('XML nao contem CNPJ do prestador valido.');
}

List<Map<String, dynamic>> extrairEventosSse(String stream) {
  final List<Map<String, dynamic>> eventos = <Map<String, dynamic>>[];
  for (final String bloco in stream.split(RegExp(r'\r?\n\r?\n'))) {
    String? tipo;
    final List<String> dados = <String>[];
    for (final String linha in bloco.split(RegExp(r'\r?\n'))) {
      if (linha.startsWith('event:')) tipo = linha.substring(6).trim();
      if (linha.startsWith('data:')) dados.add(linha.substring(5).trimLeft());
    }
    if (tipo == null || dados.isEmpty) continue;
    final Object? valor = jsonDecode(dados.join('\n'));
    if (valor is Map<String, dynamic>) {
      eventos.add(<String, dynamic>{'event': tipo, 'data': valor});
    }
  }
  return eventos;
}

String? extrairErroResultadoConsulta(Map<String, dynamic>? resultado) {
  if (resultado?['sucesso'] != false) return null;
  final Object? erro = resultado?['erro'];
  return erro is String && erro.isNotEmpty ? erro : 'consulta_falhou';
}

bool respostaDominioDeterminada(String tipo, Map<String, dynamic>? resultado) {
  if (resultado?['sucesso'] != true) return false;
  if (tipo == 'elegibilidade') return resultado?['elegivel'] is bool;
  if (tipo == 'senha') {
    final Object? status = resultado?['statusSenha'];
    return status is String && status.trim().isNotEmpty;
  }
  return false;
}

String codificarCsv(List<ResultadoMatriz> resultados) {
  const List<String> colunas = <String>[
    'usuario',
    'indice',
    'tipo',
    'sucesso',
    'latencia_ms',
    'status_http',
    'erro',
    'origem_502',
    'dominio_determinado',
    'tempo_fila_ms',
    'tempo_sessao_ms',
    'tempo_portal_ms',
    'tempo_retry_ms',
    'tempo_execucao_ms',
  ];
  final StringBuffer csv = StringBuffer('${colunas.join(',')}\r\n');
  for (final ResultadoMatriz resultado in resultados) {
    final Map<String, Object?> linha = resultado.toCsvRow();
    csv.writeln(colunas.map((String coluna) => _csv(linha[coluna])).join(','));
  }
  return csv.toString();
}

Map<String, int>? resumirLatencias(Iterable<int> valores) {
  final List<int> ordenados = valores.toList()..sort();
  if (ordenados.isEmpty) return null;
  return <String, int>{
    'min': ordenados.first,
    'p50': ordenados[ordenados.length ~/ 2],
    'max': ordenados.last,
  };
}

String _csv(Object? valor) => '"${'$valor'.replaceAll('"', '""')}"';
