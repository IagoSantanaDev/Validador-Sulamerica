import 'dart:async';

/// Evento despachado por um stream `text/event-stream`.
class EventoSse {
  const EventoSse({this.id, this.evento = 'message', required this.dados});

  final String? id;
  final String evento;
  final String dados;
}

/// Resposta HTTP não-200 recebida antes de o corpo SSE começar.
class ErroHttpSse implements Exception {
  const ErroHttpSse(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'A conexão de eventos falhou (status $statusCode).';
}

/// O stream ficou sem nenhum byte além do prazo de heartbeat.
class HeartbeatSseExpiradoException implements Exception {
  const HeartbeatSseExpiradoException(this.espera);

  final Duration espera;

  @override
  String toString() =>
      'Nenhum dado recebido em ${espera.inSeconds} s; conexão considerada morta.';
}

/// Stream de eventos somado ao cancelamento da conexão que o alimenta.
class ConexaoSse {
  ConexaoSse(this.eventos, this._cancelar);

  final Stream<EventoSse> eventos;
  final void Function() _cancelar;

  void cancelar() => _cancelar();
}

/// Parser incremental de `text/event-stream`.
///
/// Mantém o resto de linha entre chamadas, então aceita chunks cortados em
/// qualquer ponto: no meio de um campo, de uma linha ou de um evento.
class SseParser {
  SseParser({this.aoRetry});

  final void Function(Duration retry)? aoRetry;
  final StringBuffer _resto = StringBuffer();
  final List<String> _dados = [];
  String _evento = '';
  String? _id;
  String? _ultimoId;

  /// Último `id` recebido, usado para reconectar com `desde`.
  String? get ultimoId => _ultimoId;

  List<EventoSse> adicionar(String trecho) {
    if (trecho.isEmpty) return const [];
    _resto.write(trecho);
    final String texto = _resto.toString();
    final List<EventoSse> eventos = [];
    int inicio = 0;
    while (true) {
      final int fim = texto.indexOf('\n', inicio);
      if (fim < 0) break;
      String linha = texto.substring(inicio, fim);
      inicio = fim + 1;
      if (linha.endsWith('\r')) {
        linha = linha.substring(0, linha.length - 1);
      }
      _processarLinha(linha, eventos);
    }
    _resto
      ..clear()
      ..write(texto.substring(inicio));
    return eventos;
  }

  void _processarLinha(String linha, List<EventoSse> eventos) {
    if (linha.isEmpty) {
      _despachar(eventos);
      return;
    }
    if (linha.startsWith(':')) return;

    final int separador = linha.indexOf(':');
    final String campo = separador < 0 ? linha : linha.substring(0, separador);
    String valor = separador < 0 ? '' : linha.substring(separador + 1);
    if (valor.startsWith(' ')) valor = valor.substring(1);

    if (campo == 'id') {
      _id = valor;
    } else if (campo == 'event') {
      _evento = valor;
    } else if (campo == 'data') {
      _dados.add(valor);
    } else if (campo == 'retry') {
      final int? milissegundos = int.tryParse(valor);
      if (milissegundos != null) {
        aoRetry?.call(Duration(milliseconds: milissegundos));
      }
    }
  }

  void _despachar(List<EventoSse> eventos) {
    if (_dados.isNotEmpty) {
      _ultimoId = _id ?? _ultimoId;
      eventos.add(
        EventoSse(
          id: _id,
          evento: _evento.isEmpty ? 'message' : _evento,
          dados: _dados.join('\n'),
        ),
      );
    }
    _dados.clear();
    _evento = '';
    _id = null;
  }
}

/// Fora do web não há `fetch` nem stream HTTP incremental: falha explícita.
ConexaoSse abrirEventosSse({
  required Uri url,
  required String token,
  String? ultimoId,
  Duration timeoutHeartbeat = const Duration(seconds: 45),
}) {
  throw UnsupportedError(
    'Eventos SSE estão disponíveis apenas na versão web do Validador.',
  );
}
