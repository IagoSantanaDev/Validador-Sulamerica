import 'dart:async';
import 'dart:math';

import 'package:validador_backend/http/sse.dart';

enum EstadoExecucaoLote {
  naFila,
  processando,
  concluido,
  falhou,
  cancelado,
}

/// Evento já numerado do histórico de uma execução.
class EventoExecucao {
  const EventoExecucao({
    required this.id,
    required this.evento,
    required this.dados,
  });

  final int id;
  final String evento;
  final Map<String, dynamic> dados;

  List<int> codificar() =>
      codificarEventoSse(id: id, evento: evento, dados: dados);
}

/// Estado em memória de uma execução: progresso, eventos, resultado e
/// assinantes SSE.
///
/// Tudo roda no event loop de uma instância: os métodos de mutação são
/// síncronos de propósito. Nenhum `await` intercala duas chamadas, então não
/// existe corrida entre elas nem necessidade de trava.
class ExecucaoLote {
  ExecucaoLote({
    required this.total,
    this.intervaloProgresso = const Duration(milliseconds: 500),
    this.intervaloHeartbeat = const Duration(seconds: 15),
    this.carenciaSemAssinantes = const Duration(seconds: 30),
    this.aoCancelar,
  }) : assert(total >= 0) {
    _agendarCarencia();
  }

  final int total;
  final Duration intervaloProgresso;
  final Duration intervaloHeartbeat;
  final Duration carenciaSemAssinantes;

  /// Executado uma única vez quando a execução é cancelada, inclusive por
  /// ausência de assinantes. É aqui que a fila libera os itens pendentes.
  final void Function()? aoCancelar;

  final List<EventoExecucao> _eventos = <EventoExecucao>[];
  final List<_Assinante> _assinantes = <_Assinante>[];
  final List<Map<String, dynamic>> _resultados = <Map<String, dynamic>>[];

  EstadoExecucaoLote _estado = EstadoExecucaoLote.naFila;
  int _concluidas = 0;
  int _proximoId = 1;
  int? _ultimoProgressoEmitido;
  bool _progressoPendente = false;
  bool _descartado = false;
  bool _cancelamentoExecutado = false;
  Timer? _timerProgresso;
  Timer? _timerCarencia;

  EstadoExecucaoLote get estado => _estado;

  bool get ativo =>
      _estado == EstadoExecucaoLote.naFila ||
      _estado == EstadoExecucaoLote.processando;

  bool get descartado => _descartado;

  int get concluidas => _concluidas;

  int get assinantes => _assinantes.length;

  int get ultimoId => _proximoId - 1;

  List<EventoExecucao> get eventos =>
      List<EventoExecucao>.unmodifiable(_eventos);

  List<Map<String, dynamic>> get resultados =>
      List<Map<String, dynamic>>.unmodifiable(_resultados);

  void iniciar() {
    if (_estado != EstadoExecucaoLote.naFila) return;
    _estado = EstadoExecucaoLote.processando;
  }

  /// Registra [quantidade] itens concluídos.
  ///
  /// O evento de progresso sai no máximo uma vez por [intervaloProgresso]; o
  /// excedente é agregado no próximo disparo para não inundar o buffer.
  void registrarConclusao([int quantidade = 1]) {
    if (!ativo || quantidade <= 0) return;
    _concluidas = min(_concluidas + quantidade, total);
    if (_timerProgresso == null) {
      _emitirProgresso();
      _timerProgresso = Timer(intervaloProgresso, _fimIntervaloProgresso);
    } else {
      _progressoPendente = true;
    }
  }

  /// Entrega o resultado final, uma única vez. Execuções já finalizadas
  /// ignoram a chamada.
  void concluir({required List<Map<String, dynamic>> resultados}) {
    if (!ativo) return;
    _finalizar();
    _resultados
      ..clear()
      ..addAll(resultados);
    _estado = EstadoExecucaoLote.concluido;
    _emitir('resultado', <String, dynamic>{
      'status': 'ok',
      'resultados': resultados,
    });
    _encerrarAssinantes();
  }

  void falhar(String mensagem) {
    if (!ativo) return;
    _finalizar();
    _estado = EstadoExecucaoLote.falhou;
    _emitir('erro', <String, dynamic>{'mensagem': mensagem});
    _encerrarAssinantes();
  }

  /// Cancelamento explícito, também usado quando a carência sem assinantes
  /// expira. O callback roda no máximo uma vez por execução.
  void cancelar() {
    if (!ativo) return;
    _finalizar();
    _estado = EstadoExecucaoLote.cancelado;
    _emitir('erro', <String, dynamic>{'mensagem': 'Lote cancelado.'});
    _executarCancelamento();
    _encerrarAssinantes();
  }

  /// Stream SSE completo: `retry`, replay a partir de [desde] (exclusivo,
  /// como no `Last-Event-ID`) e heartbeat.
  ///
  /// O replay só acontece enquanto a execução está ativa; depois do fim não há
  /// retenção de resultado.
  Stream<List<int>> assinar({int? desde}) {
    if (_descartado) return const Stream<List<int>>.empty();
    final StreamController<List<int>> controlador =
        StreamController<List<int>>();
    final _Assinante assinante = _Assinante(controlador);
    controlador.onListen = () => _aoAssinar(assinante, desde);
    controlador.onCancel = () => _aoCancelarAssinante(assinante);
    return controlador.stream;
  }

  /// Libera resultados, buffer, assinantes e timers. Chame uma vez ao remover
  /// a execução da fila.
  void descartar() {
    if (_descartado) return;
    _descartado = true;
    _cancelarTimerProgresso();
    _timerCarencia?.cancel();
    _timerCarencia = null;
    _encerrarAssinantes();
    _eventos.clear();
    _resultados.clear();
  }

  void _aoAssinar(_Assinante assinante, int? desde) {
    _enviar(assinante, codificarRetrySse(const Duration(seconds: 3)));
    if (ativo) {
      for (final EventoExecucao evento in _eventos) {
        if (desde == null || evento.id > desde) {
          _enviar(assinante, evento.codificar());
        }
      }
    }
    if (!ativo) {
      _fecharAssinante(assinante);
      return;
    }
    _assinantes.add(assinante);
    _timerCarencia?.cancel();
    _timerCarencia = null;
    assinante.heartbeat = Timer.periodic(intervaloHeartbeat, (_) {
      _enviar(assinante, codificarComentarioSse('ping'));
    });
  }

  void _aoCancelarAssinante(_Assinante assinante) {
    assinante
      ..fechado = true
      ..heartbeat?.cancel();
    _assinantes.remove(assinante);
    _agendarCarencia();
  }

  void _agendarCarencia() {
    if (_descartado || !ativo || _assinantes.isNotEmpty) return;
    _timerCarencia?.cancel();
    _timerCarencia = Timer(carenciaSemAssinantes, () {
      _timerCarencia = null;
      if (_descartado || !ativo || _assinantes.isNotEmpty) return;
      cancelar();
    });
  }

  void _fimIntervaloProgresso() {
    _timerProgresso = null;
    if (!ativo || !_progressoPendente) return;
    _progressoPendente = false;
    _emitirProgresso();
    _timerProgresso = Timer(intervaloProgresso, _fimIntervaloProgresso);
  }

  void _emitirProgresso() {
    _ultimoProgressoEmitido = _concluidas;
    _emitir('progresso', <String, dynamic>{
      'concluidas': _concluidas,
      'total': total,
    });
  }

  void _finalizar() {
    _cancelarTimerProgresso();
    if (_concluidas > 0 && _ultimoProgressoEmitido != _concluidas) {
      _emitirProgresso();
    }
  }

  void _cancelarTimerProgresso() {
    _timerProgresso?.cancel();
    _timerProgresso = null;
    _progressoPendente = false;
  }

  void _emitir(String evento, Map<String, dynamic> dados) {
    if (_descartado) return;
    final EventoExecucao registro = EventoExecucao(
      id: _proximoId++,
      evento: evento,
      dados: dados,
    );
    _eventos.add(registro);
    final List<int> bytes = registro.codificar();
    for (final _Assinante assinante in _assinantes) {
      _enviar(assinante, bytes);
    }
  }

  void _enviar(_Assinante assinante, List<int> bytes) {
    if (assinante.fechado || _descartado) return;
    assinante.controlador.add(bytes);
  }

  void _fecharAssinante(_Assinante assinante) {
    if (assinante.fechado) return;
    assinante
      ..fechado = true
      ..heartbeat?.cancel();
    unawaited(assinante.controlador.close());
  }

  void _encerrarAssinantes() {
    final List<_Assinante> pendentes = List<_Assinante>.of(_assinantes);
    _assinantes.clear();
    for (final _Assinante assinante in pendentes) {
      _fecharAssinante(assinante);
    }
  }

  void _executarCancelamento() {
    if (_cancelamentoExecutado) return;
    _cancelamentoExecutado = true;
    aoCancelar?.call();
  }
}

class _Assinante {
  _Assinante(this.controlador);

  final StreamController<List<int>> controlador;
  Timer? heartbeat;
  bool fechado = false;
}
