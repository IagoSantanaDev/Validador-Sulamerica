import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:validador_backend/validador_api.dart';

Future<void> main() async {
  final Logger logger = Logger(
    printer: _JsonLogPrinter(),
    level: Level.info,
  );

  final String host = Platform.environment['HOST'] ?? '0.0.0.0';
  final int porta = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final int limiteSessoesPorIdentificador = _lerLimiteSessoesPorIdentificador();
  final int limiteItensPorSessao = _lerLimiteItensPorSessao();

  final ValidadorApi api = ValidadorApi(
    logger: logger,
    limiteSessoesPorIdentificador: limiteSessoesPorIdentificador,
    limiteItensPorSessao: limiteItensPorSessao,
  );

  final server = await io.serve(api.handler, host, porta);
  logger.i('API intermediaria SulAmerica em '
      'http://${server.address.host}:${server.port}');
  logger.i(
    'Rotas: POST /api/sessoes | POST /api/lotes | '
    'GET /api/lotes/{id}/eventos | GET /api/status',
  );
}

int _lerLimiteSessoesPorIdentificador() {
  final String? configurado =
      Platform.environment['PORTAL_MAX_SESSIONS_PER_IDENTIFIER'];
  if (configurado == null || configurado.trim().isEmpty) return 4;

  final int? limite = int.tryParse(configurado);
  if (limite == null || limite < 1 || limite > 8) {
    throw const FormatException(
      'PORTAL_MAX_SESSIONS_PER_IDENTIFIER deve estar entre 1 e 8.',
    );
  }
  return limite;
}

int _lerLimiteItensPorSessao() {
  const String nome = 'PORTAL_MAX_ITEMS_PER_SESSION';
  final String? configurado = Platform.environment[nome];
  if (configurado == null || configurado.trim().isEmpty) return 2;

  final int? limite = int.tryParse(configurado);
  if (limite == null || limite < 1 || limite > 5) {
    throw const FormatException(
      'PORTAL_MAX_ITEMS_PER_SESSION deve estar entre 1 e 5.',
    );
  }
  return limite;
}

class _JsonLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) => <String>[
        jsonEncode(<String, Object?>{
          'timestamp': event.time.toIso8601String(),
          'level': event.level.name,
          'message': event.message.toString(),
        }),
      ];
}
