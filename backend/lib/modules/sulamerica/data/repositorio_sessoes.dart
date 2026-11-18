import 'dart:math';

import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';

enum EstadoIdempotencia { nova, repetida, conflito }

class ConsultaIdempotencia {
  const ConsultaIdempotencia.nova()
      : estado = EstadoIdempotencia.nova,
        id = null,
        execucao = null;

  const ConsultaIdempotencia.repetida(this.id, this.execucao)
      : estado = EstadoIdempotencia.repetida;

  const ConsultaIdempotencia.conflito()
      : estado = EstadoIdempotencia.conflito,
        id = null,
        execucao = null;

  final EstadoIdempotencia estado;
  final String? id;
  final ExecucaoLote? execucao;
}

class RepositorioSessoesCheioException implements Exception {
  const RepositorioSessoesCheioException();
}

class RepositorioSessoes {
  RepositorioSessoes({
    this.limite = 200,
    this.ttl = const Duration(hours: 12),
    DateTime Function()? relogio,
  })  : _relogio = relogio ?? DateTime.now,
        _aleatorio = Random.secure();

  final int limite;
  final Duration ttl;
  final DateTime Function() _relogio;
  final Random _aleatorio;
  final Map<String, SessaoLogica> _sessoes = <String, SessaoLogica>{};

  int get quantidade => _sessoes.length;

  SessaoLogica criar(String identificadorPrestador) {
    _expurgarExpiradas();
    if (_sessoes.length >= limite) throw const RepositorioSessoesCheioException();
    final String token = _novoToken();
    final SessaoLogica sessao = SessaoLogica._(
      token: token,
      identificadorPrestador: identificadorPrestador,
      ultimaAtividade: _relogio(),
    );
    _sessoes[token] = sessao;
    return sessao;
  }

  void remover(String token) {
    final SessaoLogica? sessao = _sessoes[token];
    if (sessao != null && sessao.vinculosAtivos == 0) _sessoes.remove(token);
  }

  SessaoLogica? obter(String token) {
    _expurgarExpiradas();
    final SessaoLogica? sessao = _sessoes[token];
    if (sessao == null) return null;
    if (sessao.vinculosAtivos == 0) sessao.ultimaAtividade = _relogio();
    return sessao;
  }

  bool vincular(String token) {
    final SessaoLogica? sessao = obter(token);
    if (sessao == null) return false;
    sessao.vinculosAtivos++;
    return true;
  }

  void desvincular(String token) {
    final SessaoLogica? sessao = _sessoes[token];
    if (sessao == null || sessao.vinculosAtivos == 0) return;
    sessao.vinculosAtivos--;
    if (sessao.vinculosAtivos == 0) sessao.ultimaAtividade = _relogio();
  }

  ConsultaIdempotencia consultarIdempotencia(
    SessaoLogica sessao,
    String chave,
    List<Map<String, dynamic>> consultas,
  ) {
    final _RegistroIdempotencia? registro = sessao._idempotencias[chave];
    if (registro == null) return const ConsultaIdempotencia.nova();
    if (!_mesmoPayload(registro.consultas, consultas)) {
      return const ConsultaIdempotencia.conflito();
    }
    return ConsultaIdempotencia.repetida(registro.id, registro.execucao);
  }

  void registrarIdempotencia(
    SessaoLogica sessao,
    String chave,
    List<Map<String, dynamic>> consultas,
    String id,
    ExecucaoLote execucao,
  ) {
    sessao._idempotencias[chave] = _RegistroIdempotencia(
      List<Map<String, dynamic>>.unmodifiable(
        consultas.map(
          (Map<String, dynamic> item) =>
              Map<String, dynamic>.unmodifiable(item),
        ),
      ),
      id,
      execucao,
    );
  }

  void removerIdempotencia(
    String token,
    String chave,
    ExecucaoLote execucao,
  ) {
    final SessaoLogica? sessao = _sessoes[token];
    if (identical(sessao?._idempotencias[chave]?.execucao, execucao)) {
      sessao!._idempotencias.remove(chave);
    }
  }

  void _expurgarExpiradas() {
    final DateTime agora = _relogio();
    _sessoes.removeWhere((_, SessaoLogica sessao) {
      if (sessao.vinculosAtivos > 0) return false;
      if (agora.difference(sessao.ultimaAtividade) < ttl) return false;
      return true;
    });
  }

  String _novoToken() {
    String token;
    do {
      token = List<int>.generate(16, (_) => _aleatorio.nextInt(256))
          .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
    } while (_sessoes.containsKey(token));
    return token;
  }

  bool _mesmoPayload(
    List<Map<String, dynamic>> primeiro,
    List<Map<String, dynamic>> segundo,
  ) {
    if (primeiro.length != segundo.length) return false;
    for (int i = 0; i < primeiro.length; i++) {
      if (primeiro[i]['tipo'] != segundo[i]['tipo'] ||
          primeiro[i]['chave'] != segundo[i]['chave']) {
        return false;
      }
    }
    return true;
  }
}

class SessaoLogica {
  SessaoLogica._({
    required this.token,
    required this.identificadorPrestador,
    required this.ultimaAtividade,
  });

  final String token;
  final String identificadorPrestador;
  DateTime ultimaAtividade;
  int vinculosAtivos = 0;
  final Map<String, _RegistroIdempotencia> _idempotencias =
      <String, _RegistroIdempotencia>{};
}

class _RegistroIdempotencia {
  const _RegistroIdempotencia(this.consultas, this.id, this.execucao);

  final List<Map<String, dynamic>> consultas;
  final String id;
  final ExecucaoLote execucao;
}
