import 'dart:async';
import 'dart:math';

import 'package:validador_backend/modules/sulamerica/data/motivo_bloqueio_portal.dart';

enum EstadoDisjuntorPortal { fechado, aberto, meioAberto }

enum ResultadoDisjuntorPortal { sucesso, falhaElegivel, neutra }

class ResultadoSondaDisjuntor {
  const ResultadoSondaDisjuntor({
    required this.status,
    this.falhaTransporte = false,
    this.rejeicaoF5 = false,
    this.retryAfter,
    this.respostaInesperada = false,
  });

  final int? status;
  final bool falhaTransporte;
  final bool rejeicaoF5;
  final Duration? retryAfter;
  final bool respostaInesperada;
}

class PermissaoDisjuntorPortal {
  PermissaoDisjuntorPortal._(this._disjuntor, this._geracao);

  final DisjuntorPortal _disjuntor;
  final int _geracao;
  bool _concluida = false;

  void concluir(
    ResultadoDisjuntorPortal resultado, {
    MotivoBloqueioPortal? motivo,
    Duration? retryAfter,
  }) {
    if (_concluida) return;
    _concluida = true;
    _disjuntor._registrar(
      resultado,
      _geracao,
      motivo: motivo,
      retryAfter: retryAfter,
    );
  }
}

class DisjuntorPortal {
  DisjuntorPortal({
    required Future<ResultadoSondaDisjuntor> Function() sondarPortal,
    DateTime Function()? agora,
    this.aoAbrir,
    this.limiteFalhas = 1,
    this.janelaFalhas = const Duration(seconds: 60),
    this.duracaoAberto = const Duration(minutes: 1),
  }) : _sondarPortal = sondarPortal,
       _agora = agora ?? DateTime.now;

  final Future<ResultadoSondaDisjuntor> Function() _sondarPortal;
  final DateTime Function() _agora;
  void Function(Map<String, Object?> bloqueio)? aoAbrir;
  final int limiteFalhas;
  final Duration janelaFalhas;
  final Duration duracaoAberto;
  static const List<Duration> _duracoesBloqueio = <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 10),
    Duration(minutes: 15),
  ];
  static const Duration _limiteResetNivel = Duration(minutes: 15);

  DateTime? _abertoAte;
  DateTime? _ultimoBloqueioEm;
  DateTime? _desbloqueadoEm;
  MotivoBloqueioPortal? _motivo;
  int? _statusUltimaSonda;
  int _nivelCooldown = 0;
  int _falhasConsecutivas = 0;
  int _geracao = 0;
  bool _sondaEmAndamento = false;

  EstadoDisjuntorPortal get estado {
    if (_abertoAte == null) return EstadoDisjuntorPortal.fechado;
    final DateTime abertoAte = _abertoAte!;
    if (_agora().isBefore(abertoAte)) return EstadoDisjuntorPortal.aberto;
    return EstadoDisjuntorPortal.meioAberto;
  }

  bool get estaBloqueado => _abertoAte != null;

  int get retryAfterSegundos {
    final DateTime? abertoAte = _abertoAte;
    if (abertoAte == null) return 0;
    final Duration restante = abertoAte.difference(_agora());
    if (restante <= Duration.zero || _sondaEmAndamento) return 0;
    return max(1, (restante.inMilliseconds + 999) ~/ 1000);
  }

  bool get pausaNovosItens =>
      estaBloqueado || _sondaEmAndamento;

  int? get statusUltimaSonda => _statusUltimaSonda;

  Map<String, Object?> get bloqueio => <String, Object?>{
    'ativo': estaBloqueado,
    if (estaBloqueado) ...<String, Object?>{
      'motivo': _motivo!.chave,
      'codigo': _motivo!.codigo,
      'mensagem': _motivo!.mensagem,
      'retryAfterSegundos': retryAfterSegundos,
    },
  };

  Map<String, Object> get diagnostico => <String, Object>{
    'estado': estado.name,
    'falhasConsecutivas': _falhasConsecutivas,
    'limiteFalhas': limiteFalhas,
    'janelaMs': janelaFalhas.inMilliseconds,
    'cooldownMs': _duracaoAtual.inMilliseconds,
    'retryAfterSegundos': retryAfterSegundos,
    'sondaEmAndamento': _sondaEmAndamento,
    'motivo': _motivo?.chave ?? '',
    'nivelCooldown': _nivelCooldown + 1,
  };

  Future<PermissaoDisjuntorPortal?> tentarAdquirir() async {
    if (_abertoAte == null) {
      return PermissaoDisjuntorPortal._(this, _geracao);
    }
    if (estado == EstadoDisjuntorPortal.aberto || _sondaEmAndamento) {
      return null;
    }

    _sondaEmAndamento = true;
    final int geracao = _geracao;
    try {
      final ResultadoSondaDisjuntor sonda = await _sondarPortal();
      _statusUltimaSonda = sonda.status;
      final ResultadoDisjuntorPortal resultado = _resultadoSonda(sonda);
      _registrarSonda(
        resultado,
        geracao,
        motivo: _motivoDaSonda(sonda),
        retryAfter: sonda.retryAfter,
      );
      return resultado == ResultadoDisjuntorPortal.sucesso
          ? PermissaoDisjuntorPortal._(this, _geracao)
          : null;
    } on Exception {
      _registrarSonda(
        ResultadoDisjuntorPortal.falhaElegivel,
        geracao,
        motivo: MotivoBloqueioPortal.falhaRede,
      );
      return null;
    }
  }

  Future<void> verificarRecuperacao() async {
    if (!estaBloqueado || estado != EstadoDisjuntorPortal.meioAberto) return;
    final PermissaoDisjuntorPortal? permissao = await tentarAdquirir();
    permissao?.concluir(ResultadoDisjuntorPortal.neutra);
  }

  void registrar(
    ResultadoDisjuntorPortal resultado, {
    MotivoBloqueioPortal? motivo,
    Duration? retryAfter,
  }) {
    _registrar(
      resultado,
      _geracao,
      motivo: motivo,
      retryAfter: retryAfter,
    );
  }

  void _registrar(
    ResultadoDisjuntorPortal resultado,
    int geracao, {
    MotivoBloqueioPortal? motivo,
    Duration? retryAfter,
  }) {
    if (geracao != _geracao) return;
    if (resultado == ResultadoDisjuntorPortal.sucesso) {
      _limpar();
      return;
    }
    if (resultado != ResultadoDisjuntorPortal.falhaElegivel) return;

    final DateTime agora = _agora();
    if (_abertoAte != null) return;
    final bool escalonar = _ultimoBloqueioEm != null &&
        (_desbloqueadoEm == null ||
            agora.difference(_desbloqueadoEm!) < _limiteResetNivel);
    if (!escalonar) _nivelCooldown = 0;
    _falhasConsecutivas++;
    if (_falhasConsecutivas >= limiteFalhas) {
      _abrir(
        agora,
        motivo ?? MotivoBloqueioPortal.portalIndisponivel,
        retryAfter: retryAfter,
        escalonar: escalonar,
      );
    }
  }

  void _registrarSonda(
    ResultadoDisjuntorPortal resultado,
    int geracao, {
    required MotivoBloqueioPortal motivo,
    Duration? retryAfter,
  }) {
    if (geracao != _geracao) return;
    _sondaEmAndamento = false;
    if (resultado == ResultadoDisjuntorPortal.sucesso) {
      _abertoAte = null;
      _motivo = null;
      _desbloqueadoEm = _agora();
      _sondaEmAndamento = false;
      _geracao++;
      return;
    }
    final DateTime agora = _agora();
    final bool escalonar = _ultimoBloqueioEm != null &&
        (_desbloqueadoEm == null ||
            agora.difference(_desbloqueadoEm!) < _limiteResetNivel);
    if (!escalonar) _nivelCooldown = 0;
    _abrir(
      agora,
      motivo,
      retryAfter: retryAfter,
      escalonar: escalonar,
    );
  }

  Duration get _duracaoAtual => _nivelCooldown == 0
      ? duracaoAberto
      : _duracoesBloqueio[_nivelCooldown];

  void _abrir(
    DateTime agora,
    MotivoBloqueioPortal motivo, {
    Duration? retryAfter,
    required bool escalonar,
  }) {
    if (escalonar) _nivelCooldown = min(_nivelCooldown + 1, _duracoesBloqueio.length - 1);
    final Duration cooldown = _duracaoAtual;
    final Duration efetivo = retryAfter != null && retryAfter > cooldown
        ? retryAfter
        : cooldown;
    _abertoAte = agora.add(efetivo);
    _ultimoBloqueioEm = agora;
    _desbloqueadoEm = null;
    _motivo = motivo;
    _sondaEmAndamento = false;
    _geracao++;
    aoAbrir?.call(bloqueio);
  }

  void _limpar() {
    _falhasConsecutivas = 0;
    _abertoAte = null;
    _ultimoBloqueioEm = null;
    _desbloqueadoEm = null;
    _motivo = null;
    _nivelCooldown = 0;
    _sondaEmAndamento = false;
    _geracao++;
  }

  MotivoBloqueioPortal _motivoDaSonda(ResultadoSondaDisjuntor sonda) {
    if (sonda.rejeicaoF5) return MotivoBloqueioPortal.rejeicaoF5;
    if (sonda.status == 429) return MotivoBloqueioPortal.limitePortal;
    if (sonda.falhaTransporte) return MotivoBloqueioPortal.falhaRede;
    if (sonda.respostaInesperada) {
      return MotivoBloqueioPortal.respostaInesperada;
    }
    return MotivoBloqueioPortal.portalIndisponivel;
  }

  ResultadoDisjuntorPortal _resultadoSonda(ResultadoSondaDisjuntor sonda) {
    final int? status = sonda.status;
    if (sonda.rejeicaoF5 ||
        status == 429 ||
        sonda.respostaInesperada ||
        sonda.falhaTransporte ||
        status == null ||
        status == 408 ||
        status >= 500) {
      return ResultadoDisjuntorPortal.falhaElegivel;
    }
    return ResultadoDisjuntorPortal.sucesso;
  }
}
