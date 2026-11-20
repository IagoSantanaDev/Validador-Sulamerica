import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'matriz_dados.dart';

const String _baseUrlPadrao = 'https://validador-api-rw0a.onrender.com';
const String _headerOrigem502 = 'x-validador-api-error-origin';

Future<void> main(List<String> args) async {
  _ClienteMatriz? cliente;
  try {
    final Map<String, String> opcoes = _opcoes(args);
    if (opcoes.containsKey('help')) {
      stdout.writeln(_ajuda);
      return;
    }
    final String xmlPath = _obrigatorio(opcoes, 'xml');
    final String conteudo = _decodificarXml(await File(xmlPath).readAsBytes());
    final List<ConsultaMatriz> consultas = extrairConsultasXml(conteudo);
    if (consultas.isEmpty) {
      throw const FormatException('XML sem consultas validas.');
    }

    final _ConfigMatriz config = _ConfigMatriz(
      baseUrl: opcoes['base-url'] ?? _baseUrlPadrao,
      identificador:
          opcoes['identificador'] ?? extrairIdentificadorPrestadorXml(conteudo),
      cenario: opcoes['cenario'] ?? 'matriz',
      modo: opcoes['modo'] ?? 'lote',
      usuarios: _inteiro(opcoes, 'usuarios', 6, 1, 20),
      itens: _inteiro(opcoes, 'itens', 200, 1, 300),
      ritmoSessao: opcoes['ritmo-sessao'] ?? 'rajada',
      intervaloItemMs: _inteiro(opcoes, 'intervalo-item-ms', 3000, 0, 60000),
      intervaloGlobalMs: _inteiro(opcoes, 'intervalo-global-ms', 500, 0, 60000),
    );
    _validar(config);
    final Uri base = Uri.parse(config.baseUrl);
    if (!base.hasScheme || !<String>{'http', 'https'}.contains(base.scheme)) {
      throw const FormatException('--base-url deve usar http ou https.');
    }

    cliente = _ClienteMatriz(config.baseUrl);
    final Stopwatch duracao = Stopwatch()..start();
    final List<ResultadoMatriz> resultados = switch (config.cenario) {
      'e2' => await _executarE2(cliente, config, consultas.first),
      'e3' => await _executarE3(cliente, config),
      _ => await _executarMatriz(cliente, config, consultas),
    };
    duracao.stop();

    final String csvPath = opcoes['csv'] ?? _caminhoCsv();
    await File(csvPath).writeAsString(codificarCsv(resultados));
    _imprimirResumo(config, consultas, resultados, duracao.elapsed, csvPath);
  } on Object catch (erro) {
    stderr.writeln('Erro: ${erro.runtimeType}.');
    stderr.writeln(_ajuda);
    exitCode = 2;
  } finally {
    await cliente?.fechar();
  }
}

class _ConfigMatriz {
  const _ConfigMatriz({
    required this.baseUrl,
    required this.identificador,
    required this.cenario,
    required this.modo,
    required this.usuarios,
    required this.itens,
    required this.ritmoSessao,
    required this.intervaloItemMs,
    required this.intervaloGlobalMs,
  });

  final String baseUrl;
  final String identificador;
  final String cenario;
  final String modo;
  final int usuarios;
  final int itens;
  final String ritmoSessao;
  final int intervaloItemMs;
  final int intervaloGlobalMs;
}

class _SessaoApi {
  const _SessaoApi({required this.token, required this.usuario});

  final String token;
  final int usuario;
}

class _ClienteMatriz {
  _ClienteMatriz(String baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(minutes: 3),
            sendTimeout: const Duration(seconds: 30),
            validateStatus: (int? status) => status != null,
          ),
        );

  final Dio _dio;

  Future<void> fechar() async => _dio.close(force: true);

  Future<Response<dynamic>> criarSessao(String identificador) => _dio.post(
        '/api/sessoes',
        data: <String, String>{'identificadorPrestador': identificador},
      );

  Future<Response<dynamic>> criarLote(
    _SessaoApi sessao,
    List<ConsultaMatriz> consultas,
  ) =>
      _dio.post(
        '/api/lotes',
        data: <String, Object>{
          'consultas':
              consultas.map((ConsultaMatriz item) => item.toJson()).toList(),
        },
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer ${sessao.token}',
            'idempotency-key': _novaChaveIdempotencia(),
          },
        ),
      );

  Future<List<Map<String, dynamic>>> eventos(
    _SessaoApi sessao,
    String location,
  ) async {
    final Uri uri = Uri.parse(location);
    final String url =
        uri.hasScheme ? location : '${_dio.options.baseUrl}$location';
    final Response<ResponseBody> resposta = await _dio.get<ResponseBody>(
      url,
      options: Options(
        headers: <String, String>{'authorization': 'Bearer ${sessao.token}'},
        responseType: ResponseType.stream,
      ),
    );
    if (resposta.statusCode != 200 || resposta.data == null) {
      return <Map<String, dynamic>>[];
    }
    final String corpo = await resposta.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(minutes: 10));
    return extrairEventosSse(corpo);
  }

  static String _novaChaveIdempotencia() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sequencia++}';

  static int _sequencia = 0;
}

Future<List<ResultadoMatriz>> _executarMatriz(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
  List<ConsultaMatriz> consultas,
) async {
  final List<ResultadoMatriz> resultados = <ResultadoMatriz>[];
  final List<_SessaoApi?> sessoes =
      List<_SessaoApi?>.filled(config.usuarios, null);
  final _Pacing pacing = _Pacing(
    porToken: Duration(milliseconds: config.intervaloItemMs),
    global: Duration(milliseconds: config.intervaloGlobalMs),
  );
  await Future.wait<void>(
    List<Future<void>>.generate(config.usuarios, (int i) async {
      final Stopwatch relogio = Stopwatch()..start();
      try {
        final Response<dynamic> resposta =
            await cliente.criarSessao(config.identificador);
        final String? token = _mapa(resposta.data)?['token'] as String?;
        if (resposta.statusCode == 201 && token != null) {
          sessoes[i] = _SessaoApi(token: token, usuario: i + 1);
          resultados.add(
            ResultadoMatriz(
              usuario: i + 1,
              indice: 0,
              tipo: 'sessao',
              sucesso: true,
              latenciaMs: relogio.elapsedMilliseconds,
              statusHttp: resposta.statusCode,
              erro: null,
              origem502: null,
            ),
          );
        } else {
          resultados.add(
            _falha(
              i + 1,
              'sessao',
              resposta.statusCode,
              resposta.headers.value(_headerOrigem502),
            ),
          );
        }
      } on DioException catch (erro) {
        resultados.add(
          _falha(
            i + 1,
            'sessao',
            erro.response?.statusCode,
            erro.response?.headers.value(_headerOrigem502),
          ),
        );
      } finally {
        relogio.stop();
      }
    }),
  );

  await Future.wait<void>(<Future<void>>[
    for (final _SessaoApi? sessao in sessoes)
      if (sessao != null)
        config.modo == 'item'
            ? _executarItens(
                cliente,
                config,
                consultas,
                sessao,
                resultados,
                pacing,
              )
            : _executarLote(cliente, config, consultas, sessao, resultados),
  ]);
  return resultados;
}

Future<void> _executarLote(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
  List<ConsultaMatriz> consultas,
  _SessaoApi sessao,
  List<ResultadoMatriz> resultados,
) async {
  final List<ConsultaMatriz> itens = List<ConsultaMatriz>.generate(
    config.itens,
    (int index) => consultas[index % consultas.length],
    growable: false,
  );
  final Stopwatch relogio = Stopwatch()..start();
  try {
    final Response<dynamic> resposta = await cliente.criarLote(sessao, itens);
    if (resposta.statusCode != 202) {
      resultados.add(
        _falha(
          sessao.usuario,
          'lote',
          resposta.statusCode,
          resposta.headers.value(_headerOrigem502),
        ),
      );
      return;
    }
    final String? location = resposta.headers.value('location');
    if (location == null) {
      resultados.add(_falha(sessao.usuario, 'lote_sem_location', 202, null));
      return;
    }
    final List<Map<String, dynamic>> eventos =
        await cliente.eventos(sessao, location);
    final Map<String, dynamic>? fim = eventos.reversed
        .where((Map<String, dynamic> item) => item['event'] == 'resultado')
        .map(
          (Map<String, dynamic> item) => item['data'] as Map<String, dynamic>,
        )
        .firstOrNull;
    final Object? itensResultado = fim?['resultados'];
    relogio.stop();
    if (itensResultado is! List) {
      resultados.add(_falha(sessao.usuario, 'lote_sem_resultado', 202, null));
      return;
    }
    for (int indice = 0; indice < itensResultado.length; indice++) {
      final Map<String, dynamic>? item = _mapa(itensResultado[indice]);
      resultados.add(
        ResultadoMatriz(
          usuario: sessao.usuario,
          indice: indice + 1,
          tipo: itens[indice].tipo,
          sucesso: item?['sucesso'] as bool?,
          latenciaMs: null,
          statusHttp: 202,
          erro: extrairErroResultadoConsulta(item),
          origem502: null,
        ),
      );
    }
    resultados.add(
      ResultadoMatriz(
        usuario: sessao.usuario,
        indice: 0,
        tipo: 'lote_resumo',
        sucesso: true,
        latenciaMs: relogio.elapsedMilliseconds,
        statusHttp: 202,
        erro: null,
        origem502: null,
      ),
    );
  } on DioException catch (erro) {
    relogio.stop();
    resultados.add(
      _falha(
        sessao.usuario,
        'lote',
        erro.response?.statusCode,
        erro.response?.headers.value(_headerOrigem502),
      ),
    );
  } on TimeoutException {
    relogio.stop();
    resultados.add(_falha(sessao.usuario, 'lote_timeout', null, null));
  }
}

Future<void> _executarItens(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
  List<ConsultaMatriz> consultas,
  _SessaoApi sessao,
  List<ResultadoMatriz> resultados,
  _Pacing pacing,
) async {
  for (int indice = 0; indice < config.itens; indice++) {
    final ConsultaMatriz consulta = consultas[indice % consultas.length];
    await pacing.aguardar(sessao.token);
    await _executarConsultaItem(
      cliente,
      sessao,
      consulta,
      indice + 1,
      'consulta',
      resultados,
    );
  }
}

Future<void> _executarConsultaItem(
  _ClienteMatriz cliente,
  _SessaoApi sessao,
  ConsultaMatriz consulta,
  int indice,
  String tipoResultado,
  List<ResultadoMatriz> resultados,
) async {
  final Stopwatch relogio = Stopwatch()..start();
  try {
    final Response<dynamic> resposta =
        await cliente.criarLote(sessao, <ConsultaMatriz>[consulta]);
    final String? location = resposta.headers.value('location');
    final List<Map<String, dynamic>> eventos =
        resposta.statusCode == 202 && location != null
            ? await cliente.eventos(sessao, location)
            : <Map<String, dynamic>>[];
    final Map<String, dynamic>? fim = eventos.reversed
        .where((Map<String, dynamic> item) => item['event'] == 'resultado')
        .map(
          (Map<String, dynamic> item) => item['data'] as Map<String, dynamic>,
        )
        .firstOrNull;
    final Object? itens = fim?['resultados'];
    final bool? sucesso = itens is List && itens.isNotEmpty
        ? (_mapa(itens.first)?['sucesso'] as bool?)
        : null;
    relogio.stop();
    resultados.add(
      ResultadoMatriz(
        usuario: sessao.usuario,
        indice: indice,
        tipo: tipoResultado,
        sucesso: sucesso,
        latenciaMs: relogio.elapsedMilliseconds,
        statusHttp: resposta.statusCode,
        erro: sucesso == null
            ? (resposta.statusCode == 202
                ? 'resultado_sse_ausente'
                : 'http_${resposta.statusCode}')
            : extrairErroResultadoConsulta(
                itens is List && itens.isNotEmpty ? _mapa(itens.first) : null,
              ),
        origem502: resposta.statusCode == 502
            ? resposta.headers.value(_headerOrigem502) ?? 'indeterminada'
            : null,
      ),
    );
  } on DioException catch (erro) {
    relogio.stop();
    resultados.add(
      _falha(
        sessao.usuario,
        tipoResultado,
        erro.response?.statusCode,
        erro.response?.headers.value(_headerOrigem502),
      ),
    );
  } on TimeoutException {
    relogio.stop();
    resultados.add(
      _falha(sessao.usuario, '${tipoResultado}_timeout', null, null),
    );
  }
}

Future<List<ResultadoMatriz>> _executarE2(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
  ConsultaMatriz consulta,
) async {
  final List<ResultadoMatriz> resultados = <ResultadoMatriz>[];
  int usuario = 0;
  for (final int quantidade in <int>[2, 4]) {
    final _SessaoApi? primeira = await _criarSessaoTeste(
      cliente,
      config,
      ++usuario,
      'sessao_e2_$quantidade',
      resultados,
    );
    if (primeira == null) continue;
    final _Pacing pacing = _Pacing(
      porToken: Duration(milliseconds: config.intervaloItemMs),
      global: Duration(milliseconds: config.intervaloGlobalMs),
    );
    await pacing.aguardar(primeira.token);
    await _executarConsultaItem(
      cliente,
      primeira,
      consulta,
      quantidade,
      'e2_antes_${quantidade}_sessoes',
      resultados,
    );
    for (int i = 1; i < quantidade; i++) {
      await _criarSessaoTeste(
        cliente,
        config,
        ++usuario,
        'sessao_e2_$quantidade',
        resultados,
      );
    }
    await pacing.aguardar(primeira.token);
    await _executarConsultaItem(
      cliente,
      primeira,
      consulta,
      quantidade,
      'e2_depois_${quantidade}_sessoes',
      resultados,
    );
  }
  return resultados;
}

Future<List<ResultadoMatriz>> _executarE3(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
) async {
  final List<ResultadoMatriz> resultados = <ResultadoMatriz>[];
  final List<Future<_SessaoApi?>> tarefas = <Future<_SessaoApi?>>[];
  for (int indice = 0; indice < config.usuarios; indice++) {
    if (config.ritmoSessao == 'escalonada' && indice > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    tarefas.add(
      _criarSessaoTeste(
        cliente,
        config,
        indice + 1,
        'sessao_e3_${config.ritmoSessao}',
        resultados,
      ),
    );
  }
  await Future.wait<_SessaoApi?>(tarefas);
  return resultados;
}

Future<_SessaoApi?> _criarSessaoTeste(
  _ClienteMatriz cliente,
  _ConfigMatriz config,
  int usuario,
  String tipo,
  List<ResultadoMatriz> resultados,
) async {
  final Stopwatch relogio = Stopwatch()..start();
  try {
    final Response<dynamic> resposta =
        await cliente.criarSessao(config.identificador);
    final String? token = _mapa(resposta.data)?['token'] as String?;
    final bool ok = resposta.statusCode == 201 && token != null;
    relogio.stop();
    resultados.add(
      ResultadoMatriz(
        usuario: usuario,
        indice: usuario,
        tipo: tipo,
        sucesso: ok,
        latenciaMs: relogio.elapsedMilliseconds,
        statusHttp: resposta.statusCode,
        erro: ok ? null : 'http_${resposta.statusCode}',
        origem502: resposta.statusCode == 502
            ? resposta.headers.value(_headerOrigem502) ?? 'indeterminada'
            : null,
      ),
    );
    return ok ? _SessaoApi(token: token, usuario: usuario) : null;
  } on DioException catch (erro) {
    relogio.stop();
    resultados.add(
      _falha(
        usuario,
        tipo,
        erro.response?.statusCode,
        erro.response?.headers.value(_headerOrigem502),
      ),
    );
    return null;
  }
}

class _Pacing {
  _Pacing({required this.porToken, required this.global});

  final Duration porToken;
  final Duration global;
  DateTime? _proximaGlobal;
  final Map<String, DateTime> _proximoToken = <String, DateTime>{};

  Future<void> aguardar(String token) async {
    final DateTime agora = DateTime.now();
    DateTime inicio = agora;
    final DateTime? global = _proximaGlobal;
    final DateTime? individual = _proximoToken[token];
    if (global != null && global.isAfter(inicio)) inicio = global;
    if (individual != null && individual.isAfter(inicio)) inicio = individual;
    _proximaGlobal = inicio.add(this.global);
    _proximoToken[token] = inicio.add(porToken);
    final Duration espera = inicio.difference(DateTime.now());
    if (espera > Duration.zero) await Future<void>.delayed(espera);
  }
}

ResultadoMatriz _falha(
  int usuario,
  String tipo,
  int? status,
  String? origem502,
) =>
    ResultadoMatriz(
      usuario: usuario,
      indice: 0,
      tipo: tipo,
      sucesso: false,
      latenciaMs: null,
      statusHttp: status,
      erro: switch (status) {
        401 => 'nao_autorizado',
        413 => 'limite_excedido',
        429 => 'rate_limit_api',
        502 => 'bad_gateway',
        503 => 'servico_indisponivel',
        null => 'falha_transporte',
        _ => 'http_$status',
      },
      origem502: status == 502 ? origem502 ?? 'indeterminada' : null,
    );

Map<String, dynamic>? _mapa(Object? valor) =>
    valor is Map<String, dynamic> ? valor : null;

List<ResultadoMatriz> filtrarMetricasResumo(
  String cenario,
  List<ResultadoMatriz> resultados,
) =>
    resultados
        .where(
          (ResultadoMatriz item) =>
              item.tipo != 'lote_resumo' &&
              (cenario == 'e3' || !item.tipo.startsWith('sessao')),
        )
        .toList();

String nomeCampoLatenciaResumo(String cenario, String modo) =>
    switch (cenario) {
      'e2' => 'latenciaConsultaMs',
      'e3' => 'latenciaSessaoMs',
      _ => modo == 'item' ? 'latenciaConsultaMs' : 'latenciaLoteMs',
    };

void _imprimirResumo(
  _ConfigMatriz config,
  List<ConsultaMatriz> consultas,
  List<ResultadoMatriz> resultados,
  Duration duracao,
  String csvPath,
) {
  final List<ResultadoMatriz> metricas =
      filtrarMetricasResumo(config.cenario, resultados);
  final List<int> latencias = metricas
      .map((ResultadoMatriz item) => item.latenciaMs)
      .whereType<int>()
      .toList()
    ..sort();
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'cenario': config.cenario,
      'baseUrl': config.baseUrl,
      'modo': config.modo,
      'usuarios': config.usuarios,
      'itensPorUsuario': config.itens,
      'ritmoSessao': config.ritmoSessao,
      'itensXmlUnicos': consultas.length,
      'elegibilidadeXml': consultas
          .where((ConsultaMatriz item) => item.tipo == 'elegibilidade')
          .length,
      'senhaXml':
          consultas.where((ConsultaMatriz item) => item.tipo == 'senha').length,
      'sucessos':
          metricas.where((ResultadoMatriz item) => item.sucesso == true).length,
      'falhas': metricas
          .where((ResultadoMatriz item) => item.sucesso == false)
          .length,
      'http429': metricas
          .where((ResultadoMatriz item) => item.statusHttp == 429)
          .length,
      'http502': metricas
          .where((ResultadoMatriz item) => item.statusHttp == 502)
          .length,
      'duracaoMs': duracao.inMilliseconds,
      nomeCampoLatenciaResumo(config.cenario, config.modo): latencias.isEmpty
          ? null
          : <String, int>{
              'min': latencias.first,
              'p50': latencias[latencias.length ~/ 2],
              'max': latencias.last,
            },
      'csv': csvPath,
      if (config.cenario == 'e2')
        'limitacao':
            'tokens da API compartilham pool por CNPJ; E2 nao prova logins independentes.',
      if (config.cenario == 'e3')
        'limitacao':
            'E3 mede POST /api/sessoes; pool pode reutilizar ou coalescer login.',
      if (config.cenario == 'e1')
        'limitacao':
            'comparar CSVs com mesmos parametros, alterando somente --base-url.',
      if (config.modo == 'lote' && config.cenario == 'matriz')
        'limitacao':
            'latencia por item indisponivel no contrato de lote; use --modo item.',
    }),
  );
}

void _validar(_ConfigMatriz config) {
  if (!<String>{'matriz', 'e1', 'e2', 'e3'}.contains(config.cenario)) {
    throw const FormatException('--cenario deve ser matriz, e1, e2 ou e3.');
  }
  if (!<String>{'lote', 'item'}.contains(config.modo)) {
    throw const FormatException('--modo deve ser lote ou item.');
  }
  if (!<String>{'rajada', 'escalonada'}.contains(config.ritmoSessao)) {
    throw const FormatException(
      '--ritmo-sessao deve ser rajada ou escalonada.',
    );
  }
}

String _decodificarXml(List<int> bytes) {
  final String cabecalho = latin1.decode(bytes.take(300).toList());
  final RegExpMatch? encoding = RegExp(
    r'''encoding\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(cabecalho);
  final String nome = encoding?.group(1)?.toLowerCase() ?? 'utf-8';
  return <String>{'iso-8859-1', 'latin1', 'windows-1252'}.contains(nome)
      ? latin1.decode(bytes)
      : utf8.decode(bytes);
}

String _caminhoCsv() =>
    '${Directory.systemTemp.path}${Platform.pathSeparator}matriz-carga-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.csv';

Map<String, String> _opcoes(List<String> args) {
  final Map<String, String> resultado = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (!arg.startsWith('--')) throw FormatException('Opcao invalida: $arg');
    final String nome = arg.substring(2);
    if (nome == 'help') {
      resultado['help'] = 'true';
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      resultado[nome] = args[++i];
    } else {
      throw FormatException('Valor ausente para --$nome.');
    }
  }
  return resultado;
}

String _obrigatorio(Map<String, String> opcoes, String nome) {
  final String? valor = opcoes[nome];
  if (valor == null || valor.isEmpty) {
    throw FormatException('--$nome obrigatorio.');
  }
  return valor;
}

int _inteiro(
  Map<String, String> opcoes,
  String nome,
  int padrao,
  int min,
  int max,
) {
  final int? valor = int.tryParse(opcoes[nome] ?? '$padrao');
  if (valor == null || valor < min || valor > max) {
    throw FormatException('--$nome deve estar entre $min e $max.');
  }
  return valor;
}

const String _ajuda = '''
Uso: dart run tool/matriz_carga.dart --xml <arquivo.xml> [opcoes]
  --base-url <url>       API alvo; padrao Render DEV
  --identificador <CNPJ> Sobrescreve CNPJ extraido do XML
  --cenario matriz|e1|e2|e3 matriz padrao
  --modo lote|item       lote padrao; item mede latencia end-to-end
  --usuarios <N>         padrao 6, maximo 20
  --itens <N>            padrao 200, maximo 300
  --ritmo-sessao rajada|escalonada  Para E3; escalonada: 1 sessao/s
  --intervalo-item-ms <N> pacing/token no modo item; padrao 3000
  --intervalo-global-ms <N> pacing global no modo item; padrao 500
  --csv <arquivo.csv>    saida; padrao em diretorio temporario
  --help                 ajuda
CSV e resumo nao incluem carteiras, senhas, tokens ou bodies.
E2/E3 via API nao garantem logins independentes: pool compartilha sessoes por CNPJ.
''';
