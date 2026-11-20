import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/disjuntor_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

typedef ExecutarConsultaLote = Future<ResultadoConsultaAgendada> Function(
  SessaoPortal sessao,
  Map<String, dynamic> consulta,
  CancelToken cancelToken,
);

typedef ValidarConsultaLote = Map<String, dynamic>? Function(
  Map<String, dynamic> consulta,
);
typedef MapearFalhaSessaoLote = ResultadoConsultaAgendada Function(
  Map<String, dynamic> consulta,
  ResultadoLogin login,
);

class ResultadoConsultaAgendada {
  const ResultadoConsultaAgendada({
    required this.dados,
    this.retryable = false,
    this.falhaElegivelCircuito = false,
  });

  final Map<String, dynamic> dados;
  final bool retryable;
  final bool falhaElegivelCircuito;
}

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
    this.mapearFalhaSessao,
    this.validarConsulta,
    this.disjuntor,
    this.limiteExecucoes = 24,
    this.limiteGlobal = 16,
    this.limiteTempoLote = const Duration(minutes: 5),
    DateTime Function()? agora,
    Future<void> Function(Duration)? aguardar,
    Random? aleatorio,
  }) : _pool = pool,
       _executarConsulta = executarConsulta,
       _agora = agora ?? DateTime.now,
       _aguardar = aguardar ?? Future<void>.delayed,
       _aleatorio = aleatorio ?? Random.secure();

  final PoolSessoesPortal _pool;
  final ExecutarConsultaLote _executarConsulta;
  final MapearFalhaSessaoLote? mapearFalhaSessao;
  final ValidarConsultaLote? validarConsulta;
  final DisjuntorPortal? disjuntor;
  final int limiteExecucoes;
  final int limiteGlobal;
  final Duration limiteTempoLote;
  final DateTime Function() _agora;
  final Future<void> Function(Duration) _aguardar;
  final Random _aleatorio;
  final Map<String, List<_LoteAgendado>> _porIdentificador =
      <String, List<_LoteAgendado>>{};
  final Map<String, int> _cursorLotes = <String, int>{};
  final List<String> _identificadores = <String>[];
  final Map<String, _LoteAgendado> _execucoes = <String, _LoteAgendado>{};

  int _cursorIdentificador = 0;
  int _requisicoesAtivas = 0;
  int _concluidos = 0;
  int _parciais = 0;
  int _retriesIniciados = 0;
  int _retriesResolvidos = 0;
  int _retriesEsgotados = 0;
  bool _despachando = false;
  bool _despachoProgramado = false;
  Timer? _timerRetentativaCircuito;

  int get ativas => _execucoes.length;

  int get naFila => _execucoes.values
      .where((lote) => lote.execucao.estado == EstadoExecucaoLote.naFila)
      .length;

  int get concluidos => _concluidos;

  int get parciais => _parciais;

  Map<String, int> get diagnosticoRetries => <String, int>{
    'iniciados': _retriesIniciados,
    'resolvidos': _retriesResolvidos,
    'esgotados': _retriesEsgotados,
  };

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
      enfileiradoEm: _agora(),
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
    lote.timerPrazo = Timer(limiteTempoLote, () {
      if (!lote.execucao.ativo) return;
      lote.prazoEsgotado = true;
      if (lote.ativas == 0) {
        _concluir(lote);
        _finalizar(lote);
      }
      _programarDespacho();
    });
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
        if (disjuntor?.pausaNovosItens ?? false) {
          _agendarRetentativaCircuito();
          break;
        }
        final int indice = lote.proximoItem++;
        lote.ativas++;
        _requisicoesAtivas++;
        unawaited(_executarItem(lote, indice));
      }
    } finally {
      _despachando = false;
    }
  }

  void _agendarRetentativaCircuito() {
    if (_timerRetentativaCircuito != null) return;
    final int segundos = disjuntor?.retryAfterSegundos ?? 1;
    _timerRetentativaCircuito = Timer(Duration(seconds: segundos), () {
      _timerRetentativaCircuito = null;
      _programarDespacho();
    });
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
        if (!lote.prazoEsgotado &&
            !_agora().isBefore(lote.enfileiradoEm.add(limiteTempoLote))) {
          lote.prazoEsgotado = true;
        }
        if (!lote.execucao.ativo || lote.proximoItem >= lote.consultas.length) {
          continue;
        }
        if (lote.prazoEsgotado) continue;
        _cursorLotes[identificador] = (indiceLote + 1) % lotes.length;
        _cursorIdentificador =
            (indiceIdentificador + 1) % _identificadores.length;
        return lote;
      }
    }
    return null;
  }

  Future<void> _executarItem(_LoteAgendado lote, int indice) async {
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
      final int maxTentativas = min(4, SessaoPortal.retriesTransitorios + 1);
      for (int tentativa = 1; tentativa <= maxTentativas; tentativa++) {
        EmprestimoSessaoPortal? emprestimo;
        PermissaoDisjuntorPortal? permissao;
        ResultadoConsultaAgendada? resultado;
        try {
          permissao = await _aguardarPermissao(lote);
          if (!lote.execucao.ativo) return;
          if (tentativa > 1) _retriesIniciados++;
          emprestimo = await _pool.adquirir(
            identificador: lote.identificadorPrestador,
            credenciais: lote.credenciais,
            tipo: tipo,
            cancelToken: lote.cancelToken,
          );
          if (!lote.execucao.ativo) {
            permissao?.concluir(ResultadoDisjuntorPortal.neutra);
            return;
          }
          if (lote.execucao.estado == EstadoExecucaoLote.naFila) {
            lote.execucao.iniciar();
          }
          resultado = await _executarConsulta(
            emprestimo.sessao,
            consulta,
            lote.cancelToken,
          );
          permissao?.concluir(_classificarResultado(resultado));
        } on FalhaPoolSessoesException catch (erro) {
          permissao?.concluir(
            erro.resultado.falhaElegivelCircuito
                ? ResultadoDisjuntorPortal.falhaElegivel
                : ResultadoDisjuntorPortal.neutra,
          );
          resultado =
              mapearFalhaSessao?.call(consulta, erro.resultado) ??
              ResultadoConsultaAgendada(
                dados: <String, dynamic>{
                  ...consulta,
                  'sucesso': false,
                  'erro': 'Falha ao autenticar no portal SulAmerica.',
                },
                falhaElegivelCircuito: erro.resultado.falhaElegivelCircuito,
                retryable: erro.resultado.falhaElegivelCircuito,
              );
        } finally {
          emprestimo?.liberar();
        }

        if (!lote.execucao.ativo) return;
        final ResultadoConsultaAgendada conclusao = resultado;
        if (conclusao.retryable && tentativa < maxTentativas) {
          await _aguardarCancelavel(
            lote,
            SessaoPortal.esperaRetryTransitorio(tentativa),
          );
          continue;
        }
        if (conclusao.retryable) {
          _retriesEsgotados++;
          lote.motivosPendentes[indice] = 'tentativas_esgotadas';
        } else if (tentativa > 1 && conclusao.dados['sucesso'] == true) {
          _retriesResolvidos++;
        }
        lote.resultados[indice] = conclusao.dados;
        lote.execucao.registrarConclusao();
        return;
      }
    } on OperacaoPortalCanceladaException {
      return;
    } on Object {
      if (lote.execucao.ativo) {
        lote.execucao.falhar('Falha interna ao processar o lote.');
      }
    } finally {
      lote.ativas--;
      _requisicoesAtivas--;
      if (lote.execucao.ativo && lote.ativas == 0) {
        if (lote.prazoEsgotado || lote.proximoItem == lote.consultas.length) {
          _concluir(lote);
        }
      }
      if (!lote.execucao.ativo && lote.ativas == 0) _finalizar(lote);
      _programarDespacho();
    }
  }

  Future<PermissaoDisjuntorPortal?> _aguardarPermissao(
    _LoteAgendado lote,
  ) async {
    final DisjuntorPortal? disjuntor = this.disjuntor;
    if (disjuntor == null) return null;
    while (lote.execucao.ativo) {
      if (lote.cancelToken.isCancelled) {
        throw const OperacaoPortalCanceladaException();
      }
      final PermissaoDisjuntorPortal? permissao = await disjuntor
          .tentarAdquirir();
      if (permissao != null) return permissao;
      await _aguardarCancelavel(
        lote,
        Duration(seconds: disjuntor.retryAfterSegundos),
      );
    }
    throw const OperacaoPortalCanceladaException();
  }

  Future<void> _aguardarCancelavel(_LoteAgendado lote, Duration duracao) async {
    if (lote.cancelToken.isCancelled) {
      throw const OperacaoPortalCanceladaException();
    }
    await Future.any<void>(<Future<void>>[
      _aguardar(duracao),
      lote.cancelToken.whenCancel.then<void>(
        (_) => throw const OperacaoPortalCanceladaException(),
      ),
    ]);
  }

  ResultadoDisjuntorPortal _classificarResultado(
    ResultadoConsultaAgendada resultado,
  ) {
    if (resultado.dados['sucesso'] == true) {
      return ResultadoDisjuntorPortal.sucesso;
    }
    return resultado.falhaElegivelCircuito
        ? ResultadoDisjuntorPortal.falhaElegivel
        : ResultadoDisjuntorPortal.neutra;
  }

  void _concluir(_LoteAgendado lote) {
    if (!lote.execucao.ativo || lote.ativas != 0) return;
    final List<Map<String, dynamic>> resultados = lote.resultados
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final List<Map<String, String>> pendentes = <Map<String, String>>[
      for (int indice = 0; indice < lote.resultados.length; indice++)
        if (lote.resultados[indice] == null ||
            lote.motivosPendentes.containsKey(indice))
          <String, String>{
            'tipo': lote.consultas[indice]['tipo'] as String,
            'chave': lote.consultas[indice]['chave'] as String,
            'motivo': lote.motivosPendentes[indice] ?? 'prazo_5_minutos',
          },
    ];
    if (pendentes.isEmpty) {
      lote.execucao.concluir(resultados: resultados);
    } else {
      lote.execucao.concluirParcial(
        resultados: resultados,
        pendentes: pendentes,
      );
    }
  }

  void _finalizar(_LoteAgendado lote) {
    if (!_execucoes.containsKey(lote.id)) return;
    _execucoes.remove(lote.id);
    lote.timerPrazo?.cancel();
    if (lote.execucao.estado == EstadoExecucaoLote.concluido) _concluidos++;
    if (lote.execucao.estado == EstadoExecucaoLote.parcial) _parciais++;
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
    if (!_haItensAguardandoDespacho()) {
      _timerRetentativaCircuito?.cancel();
      _timerRetentativaCircuito = null;
    }
    lote.execucao.descartar();
    lote.aoFinalizar();
  }

  bool _haItensAguardandoDespacho() {
    final DateTime agora = _agora();
    for (final _LoteAgendado lote in _execucoes.values) {
      if (!lote.execucao.ativo || lote.proximoItem >= lote.consultas.length) {
        continue;
      }
      if (!agora.isBefore(lote.enfileiradoEm.add(limiteTempoLote))) {
        lote.prazoEsgotado = true;
        continue;
      }
      return true;
    }
    return false;
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
    required this.enfileiradoEm,
  }) : resultados = List<Map<String, dynamic>?>.filled(consultas.length, null);

  final String id;
  final String identificadorPrestador;
  final String tokenDono;
  final CredenciaisPortal credenciais;
  final List<Map<String, dynamic>> consultas;
  final ExecucaoLote execucao;
  final CancelToken cancelToken;
  final void Function() aoFinalizar;
  final DateTime enfileiradoEm;
  final List<Map<String, dynamic>?> resultados;
  final Map<int, String> motivosPendentes = <int, String>{};
  int proximoItem = 0;
  int ativas = 0;
  bool prazoEsgotado = false;
  Timer? timerPrazo;
}
