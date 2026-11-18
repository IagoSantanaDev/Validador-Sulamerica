import 'package:flutter_test/flutter_test.dart';
import 'package:validador_xml_sulamerica/globals/network/sse_client.dart';

void main() {
  group('SseParser', () {
    test('despacha id, event e data de um evento completo', () {
      final SseParser parser = SseParser();

      final List<EventoSse> eventos = parser.adicionar(
        'id: 12\nevent: progresso\ndata: {"concluidas": 120}\n\n',
      );

      expect(eventos, hasLength(1));
      expect(eventos.single.id, '12');
      expect(eventos.single.evento, 'progresso');
      expect(eventos.single.dados, '{"concluidas": 120}');
      expect(parser.ultimoId, '12');
    });

    test('reconstroi evento cortado no meio de uma linha', () {
      final SseParser parser = SseParser();

      expect(parser.adicionar('id: 7\nevent: progr'), isEmpty);
      expect(parser.adicionar('esso\ndata: {"conclui'), isEmpty);
      final List<EventoSse> eventos = parser.adicionar('das": 3}\n\n');

      expect(eventos, hasLength(1));
      expect(eventos.single.id, '7');
      expect(eventos.single.evento, 'progresso');
      expect(eventos.single.dados, '{"concluidas": 3}');
    });

    test('reconstroi evento cortado entre campos e no separador', () {
      final SseParser parser = SseParser();

      expect(parser.adicionar('data: primeir'), isEmpty);
      expect(parser.adicionar('a linha\ndata: segunda linha\n'), isEmpty);
      final List<EventoSse> eventos = parser.adicionar('\n');

      expect(eventos.single.dados, 'primeira linha\nsegunda linha');
    });

    test('ignora comentários de heartbeat sem descartar o evento seguinte', () {
      final SseParser parser = SseParser();

      expect(parser.adicionar(': ping\n\n'), isEmpty);
      final List<EventoSse> eventos = parser.adicionar(': ping\ndata: ok\n\n');

      expect(eventos, hasLength(1));
      expect(eventos.single.dados, 'ok');
      expect(parser.ultimoId, isNull);
    });

    test('aceita CRLF e mantém o id entre eventos', () {
      final SseParser parser = SseParser();

      final List<EventoSse> eventos = parser.adicionar(
        'id: 1\r\ndata: a\r\n\r\n'
        'data: b\r\n\r\n',
      );

      expect(eventos.map((EventoSse e) => e.dados), ['a', 'b']);
      expect(eventos.first.id, '1');
      expect(eventos.last.id, isNull);
      expect(parser.ultimoId, '1');
    });

    test('expõe retry sem gerar evento', () {
      Duration? retry;
      final SseParser parser = SseParser(
        aoRetry: (Duration valor) {
          retry = valor;
        },
      );

      expect(parser.adicionar('retry: 3000\n\n'), isEmpty);
      expect(retry, const Duration(seconds: 3));
    });
  });

  group('abrirEventosSse fora do web', () {
    test('falha com erro explícito em vez de abrir stream', () {
      expect(
        () => abrirEventosSse(
          url: Uri.parse('http://localhost/api/lotes/1/eventos'),
          token: 'segredo',
        ),
        throwsUnsupportedError,
      );
    });
  });
}
