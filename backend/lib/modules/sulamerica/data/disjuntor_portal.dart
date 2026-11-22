import 'dart:async';
import 'dart:math';

enum EstadoDisjuntorPortal { fechado, aberto, meioAberto }

enum ResultadoDisjuntorPortal { sucesso, falhaElegivel, neutra }

class ResultadoSondaDisjuntor {
  const ResultadoSondaDisjuntor({
    required this.status,
    this.falhaTransporte = false,
    this.rejeicaoF5 = false,
  });

  final int? status;
  final bool falhaTransporte;
  final bool rejeicaoF5;
}

class PermissaoDisjuntorPortal {
  PermissaoDisjuntorPortal._(this._disjuntor, this._geracao);

  final DisjuntorPortal _disjuntor;
  final int _geracao;
  bool _concluida = false;

  void concluir(ResultadoDisjuntorPortal resultado) {
    if (_concluida) return;
    _concluida = true;
    _disjuntor._registrar(resultado, _geracao);
  }
}

class DisjuntorPortal {
  DisjuntorPortal({
    required Future<ResultadoSondaDisjuntor> Function() sondarPortal,
    DateTime Function()? agora,
    this.limiteFalhas = 5,
    this.janelaFalhas = const Duration(seconds: 60),
    this.duracaoAberto = const Duration(seconds: 60),
  }) : _sondarPortal = sondarPortal,
       _agora = agora ?? DateTime.now;

  final Future<ResultadoSondaDisjuntor> Function() _sondarPortal;
  final DateTime Function() _agora;
  final int limiteFalhas;
  final Duration janelaFalhas;
  final Duration duracaoAberto;

  DateTime? _primeiraFalha;
  DateTime? _abertoAte;
  int _falhasConsecutivas = 0;
  int _geracao = 0;
  bool _sondaEmAndamento = false;

  EstadoDisjuntorPortal get estado {
    final DateTime? abertoAte = _abertoAte;
    if (abertoAte == null) return EstadoDisjuntorPortal.fechado;
    if (_agora().isBefore(abertoAte)) return EstadoDisjuntorPortal.aberto;
    return EstadoDisjuntorPortal.meioAberto;
  }

  int get retryAfterSegundos {
    final DateTime? abertoAte = _abertoAte;
    if (abertoAte == null) return 0;
    final Duration restante = abertoAte.difference(_agora());
    if (restante <= Duration.zero || _sondaEmAndamento) return 1;
    return max(1, (restante.inMilliseconds + 999) ~/ 1000);
  }

  bool get pausaNovosItens =>
      estado == EstadoDisjuntorPortal.aberto || _sondaEmAndamento;

  Map<String, Object> get diagnostico => <String, Object>{
    'estado': estado.name,
    'falhasConsecutivas': _falhasConsecutivas,
    'limiteFalhas': limiteFalhas,
    'janelaMs': janelaFalhas.inMilliseconds,
    'cooldownMs': duracaoAberto.inMilliseconds,
    'retryAfterSegundos': retryAfterSegundos,
    'sondaEmAndamento': _sondaEmAndamento,
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
      final ResultadoDisjuntorPortal resultado = _resultadoSonda(sonda);
      _registrarSonda(resultado, geracao);
      return resultado == ResultadoDisjuntorPortal.sucesso
          ? PermissaoDisjuntorPortal._(this, _geracao)
          : null;
    } on Exception {
      _registrarSonda(ResultadoDisjuntorPortal.falhaElegivel, geracao);
      return null;
    }
  }

  void registrar(ResultadoDisjuntorPortal resultado) {
    _registrar(resultado, _geracao);
  }

  void _registrar(ResultadoDisjuntorPortal resultado, int geracao) {
    if (geracao != _geracao) return;
    if (resultado == ResultadoDisjuntorPortal.sucesso) {
      _falhasConsecutivas = 0;
      _primeiraFalha = null;
      _abertoAte = null;
      _sondaEmAndamento = false;
      _geracao++;
      return;
    }
    if (resultado != ResultadoDisjuntorPortal.falhaElegivel) return;

    final DateTime agora = _agora();
    final DateTime? primeiraFalha = _primeiraFalha;
    if (primeiraFalha == null ||
        agora.difference(primeiraFalha) > janelaFalhas) {
      _primeiraFalha = agora;
      _falhasConsecutivas = 0;
    }
    _falhasConsecutivas++;
    if (_falhasConsecutivas >= limiteFalhas) _abrir(agora);
  }

  void _registrarSonda(ResultadoDisjuntorPortal resultado, int geracao) {
    if (geracao != _geracao) return;
    _sondaEmAndamento = false;
    if (resultado == ResultadoDisjuntorPortal.sucesso) {
      _falhasConsecutivas = 0;
      _primeiraFalha = null;
      _abertoAte = null;
      _geracao++;
      return;
    }
    _abrir(_agora());
  }

  void _abrir(DateTime agora) {
    _abertoAte = agora.add(duracaoAberto);
    _sondaEmAndamento = false;
    _geracao++;
  }

  ResultadoDisjuntorPortal _resultadoSonda(ResultadoSondaDisjuntor sonda) {
    final int? status = sonda.status;
    if (sonda.rejeicaoF5 || status == 429) {
      return ResultadoDisjuntorPortal.neutra;
    }
    if ((status == null && sonda.falhaTransporte) ||
        status == 502 ||
        status == 503 ||
        status == 504) {
      return ResultadoDisjuntorPortal.falhaElegivel;
    }
    if (status == null || status >= 500) {
      return ResultadoDisjuntorPortal.neutra;
    }
    return ResultadoDisjuntorPortal.sucesso;
  }
}
