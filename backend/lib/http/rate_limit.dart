import 'dart:collection';
import 'dart:math';

/// Origem do bloqueio devolvido por [RateLimit].
enum OrigemRateLimit { chave, global }

/// Resultado tipado de uma tentativa de consumo.
class ResultadoRateLimit {
  const ResultadoRateLimit.permitido()
      : permitido = true,
        retryAfterSegundos = 0,
        origem = null;

  const ResultadoRateLimit.bloqueado({
    required this.retryAfterSegundos,
    required this.origem,
  }) : permitido = false;

  final bool permitido;

  /// Segundos ate liberar espaco na janela; sempre >= 1 quando bloqueado.
  final int retryAfterSegundos;

  final OrigemRateLimit? origem;
}

/// Janela deslizante por chave, com backstop global e relogio injetavel.
///
/// O limiter nao conhece rotas: quem consome decide quando aplicar,
/// chamando [consumirToken], [consumirPrestador] ou [consumir]. Rotas isentas
/// simplesmente nao chamam nenhum desses metodos.
///
/// A identidade vem do token ou do identificador do prestador, nunca de IP
/// ou de `X-Forwarded-For`.
class RateLimit {
  RateLimit({
    this.limitePorChave = 20,
    this.limiteGlobal = 120,
    this.janela = const Duration(minutes: 1),
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now;

  final int limitePorChave;
  final int limiteGlobal;
  final Duration janela;
  final DateTime Function() _relogio;

  final ListQueue<DateTime> _marcasGlobais = ListQueue<DateTime>();
  final Map<String, ListQueue<DateTime>> _buckets =
      <String, ListQueue<DateTime>>{};
  DateTime? _ultimaLimpeza;

  /// Quantidade de chaves com bucket em memoria, sem contar o backstop global.
  int get bucketsAtivos => _buckets.length;

  ResultadoRateLimit consumirToken(String token) => consumir('token:$token');

  ResultadoRateLimit consumirPrestador(String identificador) =>
      consumir('prestador:$identificador');

  /// Consome uma unidade da chave e do backstop global.
  ///
  /// Um bloqueio nao registra marca em nenhum dos dois, para que tentativas
  /// recusadas nao prolonguem a espera de quem esta dentro do limite.
  ResultadoRateLimit consumir(String chave) {
    final DateTime agora = _relogio();
    _limparJanelasExpiradas(agora);

    final ResultadoRateLimit? bloqueioGlobal = _avaliar(
      _marcasGlobais,
      limiteGlobal,
      agora,
      OrigemRateLimit.global,
    );
    if (bloqueioGlobal != null) return bloqueioGlobal;

    final ListQueue<DateTime>? marcas = _buckets[chave];
    if (marcas != null) {
      final ResultadoRateLimit? bloqueioChave = _avaliar(
        marcas,
        limitePorChave,
        agora,
        OrigemRateLimit.chave,
      );
      if (bloqueioChave != null) return bloqueioChave;
    }

    _marcasGlobais.add(agora);
    (_buckets[chave] ??= ListQueue<DateTime>()).add(agora);
    return const ResultadoRateLimit.permitido();
  }

  ResultadoRateLimit? _avaliar(
    ListQueue<DateTime> marcas,
    int limite,
    DateTime agora,
    OrigemRateLimit origem,
  ) {
    _podar(marcas, agora);
    if (marcas.length < limite) return null;
    return ResultadoRateLimit.bloqueado(
      retryAfterSegundos: _segundosAteLiberar(marcas.first, agora),
      origem: origem,
    );
  }

  void _podar(ListQueue<DateTime> marcas, DateTime agora) {
    final DateTime limite = agora.subtract(janela);
    while (marcas.isNotEmpty && !marcas.first.isAfter(limite)) {
      marcas.removeFirst();
    }
  }

  int _segundosAteLiberar(DateTime marca, DateTime agora) {
    final Duration restante = marca.add(janela).difference(agora);
    final int segundos =
        (restante.inMicroseconds / Duration.microsecondsPerSecond).ceil();
    return max(1, segundos);
  }

  /// Varredura preguicosa: roda no maximo uma vez por janela, na propria
  /// chamada, evitando timers e crescimento sem limite de [_buckets].
  void _limparJanelasExpiradas(DateTime agora) {
    final DateTime? ultima = _ultimaLimpeza;
    if (ultima != null && agora.difference(ultima) < janela) return;
    _ultimaLimpeza = agora;
    _buckets.removeWhere((_, marcas) {
      _podar(marcas, agora);
      return marcas.isEmpty;
    });
  }
}
