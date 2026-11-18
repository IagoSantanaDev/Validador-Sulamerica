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

  final ValidadorApi api = ValidadorApi(logger: logger);

  final server = await io.serve(api.handler, host, porta);
  logger.i('API intermediaria SulAmerica em '
      'http://${server.address.host}:${server.port}');
  logger.i(
    'Rotas: POST /api/sessoes | POST /api/lotes | '
    'GET /api/lotes/{id}/eventos | GET /api/status',
  );
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
