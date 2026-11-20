import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'credenciais_portal.dart';
import 'sessao_portal.dart';

enum TipoConsultaPortal { elegibilidade, senha }

class FalhaPoolSessoesException implements Exception {
  const FalhaPoolSessoesException(this.resultado);

  final ResultadoLogin resultado;
}

class OperacaoPortalCanceladaException implements Exception {
  const OperacaoPortalCanceladaException();
}

class PoolSessoesPortal {
  PoolSessoesPortal({
    Logger? logger,
    SessaoPortal Function(Logger logger)? fabricaSessao,
    this.limitePorIdentificador = 4,
    bool repetirFalhasTransitorias = true,
  }) : _logger = logger ?? Logger(),
       _fabricaSessao =
           fabricaSessao ??
           ((Logger logger) => SessaoPortal(
             logger: logger,
             repetirFalhasTransitorias: repetirFalhasTransitorias,
           ));

  final Logger _logger;
  final SessaoPortal Function(Logger logger) _fabricaSessao;
  final int limitePorIdentificador;
  final Map<String, _PoolPrestador> _porIdentificador = {};
  final Map<String, int> _diagnosticoSessoesDescartadas = <String, int>{};
  final List<Map<String, dynamic>> _supportIdsDescartados =
      <Map<String, dynamic>>[];
  static const int _limiteSupportIdsRecentes = 20;
  int _picoRequisicoesAtivas = 0;

  int get sessoesAtivas => _porIdentificador.values.fold<int>(
    0,
    (int total, _PoolPrestador pool) => total + pool.sessoes.length,
  );

  bool possuiSessaoAutenticada(String identificador) =>
      _porIdentificador[identificador]?.sessoes.any(
        (_SessaoGerenciada sessao) => sessao.sessao.autenticada,
      ) ??
      false;

  Map<String, int> get diagnosticoSessaoPortal {
    final Map<String, int> total = Map<String, int>.of(
      _diagnosticoSessoesDescartadas,
    );
    for (final _PoolPrestador pool in _porIdentificador.values) {
      for (final _SessaoGerenciada sessao in pool.sessoes) {
        for (final MapEntry<String, int> contador
            in sessao.sessao.diagnosticoSessao.entries) {
          total.update(
            contador.key,
            (int valor) => valor + contador.value,
            ifAbsent: () => contador.value,
          );
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> get supportIdsRespostaPortal {
    final List<Map<String, dynamic>> recentes =
        List<Map<String, dynamic>>.of(_supportIdsDescartados);
    for (final _PoolPrestador pool in _porIdentificador.values) {
      for (final _SessaoGerenciada sessao in pool.sessoes) {
        recentes.addAll(sessao.sessao.supportIdsRespostaPortal);
      }
    }
    recentes.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          (a['timestamp'] as String).compareTo(b['timestamp'] as String),
    );
    final int inicio = recentes.length > _limiteSupportIdsRecentes
        ? recentes.length - _limiteSupportIdsRecentes
        : 0;
    return recentes.skip(inicio).map(Map<String, dynamic>.of).toList();
  }

  Map<String, int> get diagnosticoConcorrenciaPortal => <String, int>{
    'picoRequisicoesEmprestadas': _picoRequisicoesAtivas,
    'limiteSessoesPorIdentificador': limitePorIdentificador,
  };

  Future<SessaoPortal> garantirAutenticada(
    String identificador,
    CredenciaisPortal credenciais,
  ) async {
    final _PoolPrestador pool = _porIdentificador.putIfAbsent(
      identificador,
      _PoolPrestador.new,
    );
    if (pool.sessoes.isEmpty) {
      await _adicionarSessao(identificador, credenciais, pool);
    }
    final _SessaoGerenciada sessao = pool.sessoes.first;
    final ResultadoLogin login = await sessao.sessao.garantirAutenticada();
    if (!login.autenticada) throw FalhaPoolSessoesException(login);
    return sessao.sessao;
  }

  Future<EmprestimoSessaoPortal> adquirir({
    required String identificador,
    required CredenciaisPortal credenciais,
    required TipoConsultaPortal tipo,
    CancelToken? cancelToken,
  }) async {
    final _PoolPrestador pool = _porIdentificador.putIfAbsent(
      identificador,
      _PoolPrestador.new,
    );

    while (true) {
      if (cancelToken?.isCancelled ?? false) {
        throw const OperacaoPortalCanceladaException();
      }
      _SessaoGerenciada? escolhida;
      for (final _SessaoGerenciada sessao in pool.sessoes) {
        if (!sessao.disponivel(tipo)) continue;
        if (escolhida == null || sessao.ativas < escolhida.ativas) {
          escolhida = sessao;
        }
      }

      if (escolhida != null) {
        escolhida.reservar(tipo);
        final int ativas = _porIdentificador.values.fold<int>(
          0,
          (int total, _PoolPrestador pool) =>
              total + pool.sessoes.fold<int>(
                0,
                (int subtotal, _SessaoGerenciada sessao) =>
                    subtotal + sessao.ativas,
              ),
        );
        if (ativas > _picoRequisicoesAtivas) _picoRequisicoesAtivas = ativas;
        return EmprestimoSessaoPortal._(escolhida, tipo, pool);
      }

      if (pool.sessoes.length < limitePorIdentificador) {
        await _adicionarSessao(identificador, credenciais, pool);
        continue;
      }

      final Future<void> disponivel = pool.aguardarDisponibilidade();
      if (cancelToken == null) {
        await disponivel;
      } else {
        await Future.any<void>(<Future<void>>[
          disponivel,
          cancelToken.whenCancel.then<void>(
            (_) => throw const OperacaoPortalCanceladaException(),
          ),
        ]);
      }
    }
  }

  Future<void> _adicionarSessao(
    String identificador,
    CredenciaisPortal credenciais,
    _PoolPrestador pool,
  ) async {
    final Future<void>? criando = pool.criacao;
    if (criando != null) {
      await criando;
      return;
    }

    late final Future<void> criacao;
    criacao = () async {
      final SessaoPortal sessao = _fabricaSessao(_logger);
      final _SessaoGerenciada gerenciada = _SessaoGerenciada(sessao);
      pool.sessoes.add(gerenciada);
      bool autenticada = false;
      try {
        final ResultadoLogin login = await sessao.login(
          code: credenciais.code,
          user: credenciais.user,
          senha: credenciais.senha,
        );
        if (!login.autenticada) throw FalhaPoolSessoesException(login);
        autenticada = true;
      } finally {
        if (!autenticada) {
          for (final MapEntry<String, int> contador
              in sessao.diagnosticoSessao.entries) {
            _diagnosticoSessoesDescartadas.update(
              contador.key,
              (int valor) => valor + contador.value,
              ifAbsent: () => contador.value,
            );
          }
          _supportIdsDescartados.addAll(sessao.supportIdsRespostaPortal);
          if (_supportIdsDescartados.length > _limiteSupportIdsRecentes) {
            _supportIdsDescartados.removeRange(
              0,
              _supportIdsDescartados.length - _limiteSupportIdsRecentes,
            );
          }
          pool.sessoes.remove(gerenciada);
          await sessao.encerrar();
        }
      }
    }();
    pool.criacao = criacao;
    try {
      await criacao;
    } finally {
      if (identical(pool.criacao, criacao)) pool.criacao = null;
      pool.notificar();
    }
  }
}

class EmprestimoSessaoPortal {
  EmprestimoSessaoPortal._(this._gerenciada, this.tipo, this._pool);

  final _SessaoGerenciada _gerenciada;
  final TipoConsultaPortal tipo;
  final _PoolPrestador _pool;
  bool _liberado = false;

  SessaoPortal get sessao => _gerenciada.sessao;

  void liberar() {
    if (_liberado) return;
    _liberado = true;
    _gerenciada.liberar(tipo);
    _pool.notificar();
  }
}

class _PoolPrestador {
  final List<_SessaoGerenciada> sessoes = <_SessaoGerenciada>[];
  Future<void>? criacao;
  Completer<void> _mudanca = Completer<void>();

  Future<void> aguardarDisponibilidade() => _mudanca.future;

  void notificar() {
    if (_mudanca.isCompleted) return;
    _mudanca.complete();
    _mudanca = Completer<void>();
  }
}

class _SessaoGerenciada {
  _SessaoGerenciada(this.sessao);

  final SessaoPortal sessao;
  int elegibilidadesAtivas = 0;
  int senhasAtivas = 0;

  int get ativas => elegibilidadesAtivas + senhasAtivas;

  bool disponivel(TipoConsultaPortal tipo) => switch (tipo) {
    TipoConsultaPortal.elegibilidade => elegibilidadesAtivas == 0,
    TipoConsultaPortal.senha => senhasAtivas < 3,
  };

  void reservar(TipoConsultaPortal tipo) {
    switch (tipo) {
      case TipoConsultaPortal.elegibilidade:
        elegibilidadesAtivas++;
      case TipoConsultaPortal.senha:
        senhasAtivas++;
    }
  }

  void liberar(TipoConsultaPortal tipo) {
    switch (tipo) {
      case TipoConsultaPortal.elegibilidade:
        elegibilidadesAtivas--;
      case TipoConsultaPortal.senha:
        senhasAtivas--;
    }
  }
}
