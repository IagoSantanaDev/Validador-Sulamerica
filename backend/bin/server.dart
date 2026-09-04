import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:validador_backend/validador_api.dart';

Future<void> main() async {
  final Logger logger = Logger();

  final String host = Platform.environment['HOST'] ?? '0.0.0.0';
  final int porta =
      int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  final ValidadorApi api = ValidadorApi(logger: logger);

  final server = await io.serve(api.handler, host, porta);
  logger.i('API intermediaria SulAmerica em '
      'http://${server.address.host}:${server.port}');
  logger.i('Rotas: POST /api/login | POST /api/beneficiario | '
      'GET /api/autorizacao?numeroVpp= | POST /api/consultas | '
      'GET /api/status');
}