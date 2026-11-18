import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

typedef ExecutarConsultaLote =
    Future<Map<String, dynamic>> Function(
      SessaoPortal sessao,
      Map<String, dynamic> consulta,
      CancelToken cancelToken,
    );

typedef ValidarConsultaLote =
    Map<String, dynamic>? Function(Map<String, dynamic> consulta);

class FilaCheiaException implements Exception {
  const FilaCheiaException();
}

class ExecucaoAgendada {
  const ExecucaoAgendada({required this.id, required this.execucao});

  final String id;
  final ExecucaoLote execucao;
}

class AgendadorLotes {
  AgendadorLotes({
    required PoolSessoesPortal pool,
    required ExecutarConsultaLote executarConsulta,
    this.validarConsulta,
    this.limiteExecucoes = 24,
    this.limiteGlobal = 16,
    Random? aleatorio,
  }) : _pool = pool,
       _executarConsulta = executarConsulta,
       _aleatorio = aleatorio ?? Random.secure();

  final PoolSessoesPortal _pool;
  final ExecutarConsultaLote _executarConsulta;
  final ValidarConsultaLote? validarConsulta;
  final int limiteExecucoes;
  final int limiteGlobal;
  final Random _aleatorio;
  final Map<String, List<_LoteAgendado>> _porIdentificador =
      <String, List<_LoteAgendado>>{};
  final Map<String, int> _cursorLotes = <String, int>{};
  final List<String> _identificadores = <String>[];
  final Map<String, _LoteAgendado> _execucoes = <String, _LoteAgendado>{};

  int _cursorIdentificador = 0;
  int _requisicoesAtivas = 0;
  int _concluidos = 0;
  bool _despachando = false;
  bool _despachoProgramado = false;

  int get ativas => _execucoes.length;

  int get naFila => _execucoes.values
      .where((lote) => lote.execucao.estado == EstadoExecucaoLote.naFila)
      .length;

  int get concluidos => _concluidos;

  ExecucaoLote? obterExecucao(String id, String tokenDono) {
    final _LoteAgendado? lote = _execucoes[id];
    if (lote == null || lote.tokenDono != tokenDono) return null;
    return lote.execucao;
  }

  ExecucaoAgendada agendar({
    required String identificadorPrestador,
    required String tokenDono,
    required CredenciaisPortal credenciais,
    required List<Map<String, dynamic>> consultas,
    required void Function() aoFinalizar,
  }) {
    if (_execucoes.length >= limiteExecucoes) {
      throw const FilaCheiaException();
    }

    late final _LoteAgendado lote;
    final CancelToken cancelToken = CancelToken();
    final ExecucaoLote execucao = ExecucaoLote(
      total: consultas.length,
      aoCancelar: () {
        cancelToken.cancel('Execução cancelada.');
        lote.proximoItem = consultas.length;
        if (lote.ativas == 0) _finalizar(lote);
        _despachar();
      },
    );
    final String id = _novoId();
    lote = _LoteAgendado(
      id: id,
      identificadorPrestador: identificadorPrestador,
      tokenDono: tokenDono,
      credenciais: credenciais,
      consultas: consultas,
      execucao: execucao,
      cancelToken: cancelToken,
      aoFinalizar: aoFinalizar,
    );
    _execucoes[id] = lote;
    final List<_LoteAgendado> fila = _porIdentificador.putIfAbsent(
      identificadorPrestador,
      () {
        _identificadores.add(identificadorPrestador);
        return <_LoteAgendado>[];
      },
    );
    fila.add(lote);
    _programarDespacho();
    return ExecucaoAgendada(id: id, execucao: execucao);
  }

  void _programarDespacho() {
    if (_despachoProgramado) return;
    _despachoProgramado = true;
    Timer.run(() {
      _despachoProgramado = false;
      _despachar();
    });
  }

  String _novoId() {
    String id;
    do {
      id = List<int>.generate(
        16,
        (_) => _aleatorio.nextInt(256),
      ).map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    } while (_execucoes.containsKey(id));
    return id;
  }

  void _despachar() {
    if (_despachando) return;
    _despachando = true;
    try {
      while (_requisicoesAtivas < limiteGlobal) {
        final _LoteAgendado? lote = _selecionarProximo();
        if (lote == null) break;
        final int indice = lote.proximoItem++;
        lote.ativas++;
        _requisicoesAtivas++;
        unawaited(_executarItem(lote, indice));
      }
    } finally {
      _despachando = false;
    }
  }

  _LoteAgendado? _selecionarProximo() {
    if (_identificadores.isEmpty) return null;
    for (int passo = 0; passo < _identificadores.length; passo++) {
      final int indiceIdentificador =
          (_cursorIdentificador + passo) % _identificadores.length;
      final String identificador = _identificadores[indiceIdentificador];
      final List<_LoteAgendado>? lotes = _porIdentificador[identificador];
      if (lotes == null || lotes.isEmpty) continue;

      final int inicio = _cursorLotes[identificador] ?? 0;
      for (int offset = 0; offset < lotes.length; offset++) {
        final int indiceLote = (inicio + offset) % lotes.length;
        final _LoteAgendado lote = lotes[indiceLote];
        if (!lote.execucao.ativo || lote.proximoItem >= lote.consultas.length) {
          continue;
        }
        _cursorLotes[identificador] = (indiceLote + 1) % lotes.length;
        _cursorIdentificador =
            (indiceIdentificador + 1) % _identificadores.length;
        return lote;
      }
    }
    return null;
  }

  Future<void> _executarItem(_LoteAgendado lote, int indice) async {
    EmprestimoSessaoPortal? emprestimo;
    try {
      final Map<String, dynamic> consulta = lote.consultas[indice];
      final Map<String, dynamic>? falhaFormato = validarConsulta?.call(
        consulta,
      );
      if (falhaFormato != null) {
        if (lote.execucao.estado == EstadoExecucaoLote.naFila) {
          lote.execucao.iniciar();
        }
        lote.resultados[indice] = falhaFormato;
        lote.execucao.registrarConclusao();
        return;
      }

      final TipoConsultaPortal tipo = consulta['tipo'] == 'elegibilidade'
          ? TipoConsultaPortal.elegibilidade
          : TipoConsultaPortal.senha;
      emprestimo = await _pool.adquirir(
        identificador: lote.identificadorPrestador,
        credenciais: lote.credenciais,
        tipo: tipo,
        cancelToken: lote.cancelToken,
      );
      if (!lote.execucao.ativo) return;
      if (lote.execucao.estado == EstadoExecucaoLote.naFila) {
        lote.execucao.iniciar();
      }
      final Map<String, dynamic> resultado = await _executarConsulta(
        emprestimo.sessao,
        consulta,
        lote.cancelToken,
      );
      if (lote.execucao.ativo) {
        lote.resultados[indice] = resultado;
        lote.execucao.registrarConclusao();
      }
    } on Object {
      if (lote.execucao.ativo) {
        lote.execucao.falhar('Falha interna ao processar o lote.');
      }
    } finally {
      emprestimo?.liberar();
      lote.ativas--;
      _requisicoesAtivas--;
      if (lote.execucao.ativo &&
          lote.proximoItem == lote.consultas.length &&
          lote.ativas == 0) {
        lote.execucao.concluir(
          resultados: lote.resultados.whereType<Map<String, dynamic>>().toList(
            growable: false,
          ),
        );
      }
      if (!lote.execucao.ativo && lote.ativas == 0) _finalizar(lote);
      _programarDespacho();
    }
  }

  void _finalizar(_LoteAgendado lote) {
    if (!_execucoes.containsKey(lote.id)) return;
    _execucoes.remove(lote.id);
    if (lote.execucao.estado == EstadoExecucaoLote.concluido) _concluidos++;
    final List<_LoteAgendado>? lotes =
        _porIdentificador[lote.identificadorPrestador];
    lotes?.remove(lote);
    if (lotes != null && lotes.isEmpty) {
      _porIdentificador.remove(lote.identificadorPrestador);
      _identificadores.remove(lote.identificadorPrestador);
      _cursorLotes.remove(lote.identificadorPrestador);
      if (_identificadores.isEmpty) {
        _cursorIdentificador = 0;
      } else {
        _cursorIdentificador %= _identificadores.length;
      }
    } else if (lotes != null) {
      _cursorLotes[lote.identificadorPrestador] =
          (_cursorLotes[lote.identificadorPrestador] ?? 0) % lotes.length;
    }
    lote.execucao.descartar();
    lote.aoFinalizar();
  }
}

class _LoteAgendado {
  _LoteAgendado({
    required this.id,
    required this.identificadorPrestador,
    required this.tokenDono,
    required this.credenciais,
    required this.consultas,
    required this.execucao,
    required this.cancelToken,
    required this.aoFinalizar,
  }) : resultados = List<Map<String, dynamic>?>.filled(consultas.length, null);

  final String id;
  final String identificadorPrestador;
  final String tokenDono;
  final CredenciaisPortal credenciais;
  final List<Map<String, dynamic>> consultas;
  final ExecucaoLote execucao;
  final CancelToken cancelToken;
  final void Function() aoFinalizar;
  final List<Map<String, dynamic>?> resultados;
  int proximoItem = 0;
  int ativas = 0;
}
