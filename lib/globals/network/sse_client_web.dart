import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sse_client_stub.dart';

/// Abre `GET` com `fetch` e entrega os eventos conforme chegam.
///
/// O corpo é lido por `ReadableStream.getReader()` e decodificado em UTF-8
/// incremental, então caracteres e eventos partidos entre chunks são
/// reconstruídos corretamente.
ConexaoSse abrirEventosSse({
  required Uri url,
  required String token,
  String? ultimoId,
  Duration timeoutHeartbeat = const Duration(seconds: 45),
}) {
  final StreamController<EventoSse> controlador = StreamController<EventoSse>();
  final web.AbortController cancelamento = web.AbortController();
  final SseParser parser = SseParser();
  Timer? watchdog;
  bool finalizado = false;

  void pararWatchdog() {
    watchdog?.cancel();
    watchdog = null;
  }

  void encerrar([Object? erro, StackTrace? pilha]) {
    if (finalizado) return;
    finalizado = true;
    pararWatchdog();
    if (erro != null) controlador.addError(erro, pilha);
    controlador.close();
  }

  void reiniciarWatchdog() {
    pararWatchdog();
    watchdog = Timer(
      timeoutHeartbeat,
      () => encerrar(HeartbeatSseExpiradoException(timeoutHeartbeat)),
    );
  }

  void emitir(List<EventoSse> eventos) {
    for (final EventoSse evento in eventos) {
      if (!finalizado) controlador.add(evento);
    }
  }

  Future<void> ler() async {
    try {
      final Map<String, String> cabecalhos = <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (ultimoId != null) 'Last-Event-ID': ultimoId,
      };
      final web.Response resposta = await web.window
          .fetch(
            url.toString().toJS,
            web.RequestInit(
              method: 'GET',
              headers: cabecalhos.jsify()! as web.HeadersInit,
              signal: cancelamento.signal,
            ),
          )
          .toDart;

      if (resposta.status != 200) {
        encerrar(ErroHttpSse(resposta.status));
        return;
      }

      final web.ReadableStream? corpo = resposta.body;
      if (corpo == null) {
        encerrar();
        return;
      }

      final web.ReadableStreamDefaultReader leitor =
          corpo.getReader() as web.ReadableStreamDefaultReader;
      final web.TextDecoder decodificador = web.TextDecoder();
      reiniciarWatchdog();

      while (!finalizado) {
        final web.ReadableStreamReadResult pedaco = await leitor.read().toDart;
        if (pedaco.done) break;

        final JSAny? valor = pedaco.value;
        if (valor == null) continue;

        reiniciarWatchdog();
        emitir(
          parser.adicionar(
            decodificador.decode(
              valor as JSObject,
              web.TextDecodeOptions(stream: true),
            ),
          ),
        );
      }

      if (finalizado) return;
      emitir(parser.adicionar('${decodificador.decode()}\n\n'));
      encerrar();
    } catch (erro, pilha) {
      encerrar(erro, pilha);
    }
  }

  void cancelar() {
    if (finalizado) return;
    finalizado = true;
    pararWatchdog();
    cancelamento.abort();
    unawaited(controlador.close());
  }

  controlador.onCancel = cancelar;
  unawaited(ler());

  return ConexaoSse(controlador.stream, cancelar);
}
