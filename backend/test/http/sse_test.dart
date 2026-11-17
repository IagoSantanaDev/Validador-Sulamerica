import 'dart:convert';

import 'package:test/test.dart';
import 'package:validador_backend/http/sse.dart';

void main() {
  group('codificarEventoSse', () {
    test('formato exato de id, event e data', () {
      final List<int> bytes = codificarEventoSse(
        id: 12,
        evento: 'progresso',
        dados: <String, dynamic>{'concluidas': 120, 'total': 300},
      );
      expect(
        utf8.decode(bytes),
        'id: 12\n'
        'event: progresso\n'
        'data: {"concluidas":120,"total":300}\n'
        '\n',
      );
    });

    test('data multilinha vira uma linha data: por linha e perde o \\r', () {
      final List<int> bytes = codificarEventoSse(
        id: 3,
        evento: 'resultado',
        dados: 'primeira\r\nsegunda\nterceira',
      );
      expect(
        utf8.decode(bytes),
        'id: 3\n'
        'event: resultado\n'
        'data: primeira\n'
        'data: segunda\n'
        'data: terceira\n'
        '\n',
      );
    });

    test('evento sem id omite a linha id', () {
      expect(
        utf8.decode(
          codificarEventoSse(evento: 'erro', dados: {'mensagem': 'x'}),
        ),
        'event: erro\n'
        'data: {"mensagem":"x"}\n'
        '\n',
      );
    });
  });

  test('retry usa milissegundos e termina o bloco', () {
    expect(
      utf8.decode(codificarRetrySse(const Duration(seconds: 3))),
      'retry: 3000\n\n',
    );
  });

  test('heartbeat é um comentário SSE', () {
    expect(utf8.decode(codificarComentarioSse('ping')), ': ping\n\n');
    expect(
      utf8.decode(codificarComentarioSse('pi\nng')),
      ': pi ng\n\n',
    );
  });

  test('headers do stream seguem o contrato', () {
    final Map<String, String> headers = cabecalhosSse();
    expect(headers, hasLength(4));
    expect(
      headers['Content-Type'],
      'text/event-stream; charset=utf-8',
    );
    expect(headers['Cache-Control'], 'no-cache');
    expect(headers['X-Accel-Buffering'], 'no');
    expect(headers['Connection'], 'keep-alive');
  });
}
