import 'package:test/test.dart';
import 'package:validador_backend/http/rate_limit.dart';

class _RelogioFake {
  DateTime agora = DateTime.utc(2026, 1, 1, 12);

  void avancar(Duration duracao) => agora = agora.add(duracao);
}

RateLimit _limiter(
  _RelogioFake relogio, {
  int limitePorChave = 20,
  int limiteGlobal = 120,
  Duration janela = const Duration(minutes: 1),
}) {
  return RateLimit(
    limitePorChave: limitePorChave,
    limiteGlobal: limiteGlobal,
    janela: janela,
    relogio: () => relogio.agora,
  );
}

void main() {
  group('RateLimit - configuracao padrao', () {
    test('usa os limites do PRD', () {
      final limiter = RateLimit();
      expect(limiter.limitePorChave, 20);
      expect(limiter.limiteGlobal, 120);
      expect(limiter.janela, const Duration(minutes: 1));
    });
  });

  group('RateLimit - buckets independentes', () {
    test('estouro de um token nao bloqueia outro token', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 3);

      for (int i = 0; i < 3; i++) {
        expect(limiter.consumirToken('aaa').permitido, isTrue, reason: '$i');
      }

      final bloqueado = limiter.consumirToken('aaa');
      expect(bloqueado.permitido, isFalse);
      expect(bloqueado.origem, OrigemRateLimit.chave);

      for (int i = 0; i < 3; i++) {
        expect(limiter.consumirToken('bbb').permitido, isTrue, reason: '$i');
      }
    });

    test('chaves de token e de prestador nao se misturam', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 2);

      expect(limiter.consumirToken('mesmo-valor').permitido, isTrue);
      expect(limiter.consumirToken('mesmo-valor').permitido, isTrue);
      expect(limiter.consumirToken('mesmo-valor').permitido, isFalse);

      expect(limiter.consumirPrestador('mesmo-valor').permitido, isTrue);
      expect(limiter.consumirPrestador('mesmo-valor').permitido, isTrue);
      expect(limiter.consumirPrestador('mesmo-valor').permitido, isFalse);
    });
  });

  group('RateLimit - janela deslizante', () {
    test('janela expira e libera a chave', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 2);

      expect(limiter.consumirToken('aaa').permitido, isTrue);
      expect(limiter.consumirToken('aaa').permitido, isTrue);
      expect(limiter.consumirToken('aaa').permitido, isFalse);

      relogio.avancar(const Duration(minutes: 1, milliseconds: 1));
      expect(limiter.consumirToken('aaa').permitido, isTrue);
    });

    test('janela expira e libera o backstop global', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(
        relogio,
        limitePorChave: 10,
        limiteGlobal: 2,
      );

      expect(limiter.consumirToken('a').permitido, isTrue);
      expect(limiter.consumirToken('b').permitido, isTrue);
      final bloqueado = limiter.consumirToken('c');
      expect(bloqueado.permitido, isFalse);
      expect(bloqueado.origem, OrigemRateLimit.global);

      relogio.avancar(const Duration(minutes: 1, milliseconds: 1));
      expect(limiter.consumirToken('c').permitido, isTrue);
    });

    test('tentativa bloqueada nao consome a janela', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 1);

      expect(limiter.consumirToken('aaa').permitido, isTrue);
      relogio.avancar(const Duration(seconds: 30));
      expect(limiter.consumirToken('aaa').permitido, isFalse);

      relogio.avancar(const Duration(seconds: 30, milliseconds: 1));
      expect(limiter.consumirToken('aaa').permitido, isTrue);
    });
  });

  group('RateLimit - backstop global', () {
    test('bloqueia mesmo com buckets locais livres', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(
        relogio,
        limitePorChave: 5,
        limiteGlobal: 4,
      );

      for (int i = 0; i < 4; i++) {
        expect(limiter.consumirToken('token-$i').permitido, isTrue, reason: '$i');
      }

      final bloqueado = limiter.consumirToken('token-novo');
      expect(bloqueado.permitido, isFalse);
      expect(bloqueado.origem, OrigemRateLimit.global);
      expect(limiter.bucketsAtivos, 4);
    });

    test('conta tokens e prestadores no mesmo backstop', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(
        relogio,
        limitePorChave: 5,
        limiteGlobal: 3,
      );

      expect(limiter.consumirToken('a').permitido, isTrue);
      expect(limiter.consumirPrestador('b').permitido, isTrue);
      expect(limiter.consumirToken('c').permitido, isTrue);
      expect(limiter.consumirPrestador('d').permitido, isFalse);
    });
  });

  group('RateLimit - Retry-After', () {
    test('e numerico e no minimo 1 segundo', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 1);

      expect(limiter.consumirToken('aaa').permitido, isTrue);
      relogio.avancar(const Duration(milliseconds: 59900));

      final bloqueado = limiter.consumirToken('aaa');
      expect(bloqueado.permitido, isFalse);
      expect(bloqueado.retryAfterSegundos, isA<int>());
      expect(bloqueado.retryAfterSegundos, greaterThanOrEqualTo(1));
      expect(bloqueado.retryAfterSegundos, 1);
    });

    test('arredonda para cima os segundos restantes', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(relogio, limitePorChave: 1);

      limiter.consumirToken('aaa');
      relogio.avancar(const Duration(seconds: 30, milliseconds: 500));

      expect(limiter.consumirToken('aaa').retryAfterSegundos, 30);
    });
  });

  group('RateLimit - limpeza de buckets', () {
    test('remove buckets expirados na varredura periodica', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(
        relogio,
        limitePorChave: 1000,
        limiteGlobal: 100000,
      );

      for (int i = 0; i < 300; i++) {
        expect(limiter.consumirToken('token-$i').permitido, isTrue, reason: '$i');
      }
      expect(limiter.bucketsAtivos, 300);

      relogio.avancar(const Duration(seconds: 30));
      expect(limiter.consumirToken('token-novo').permitido, isTrue);
      expect(limiter.bucketsAtivos, 301);

      relogio.avancar(const Duration(seconds: 31));
      expect(limiter.consumirToken('token-final').permitido, isTrue);
      expect(limiter.bucketsAtivos, 2);
      expect(limiter.consumirToken('token-0').permitido, isTrue);
    });

    test('mapa fica limitado com muitas chaves e relogio avancando', () {
      final relogio = _RelogioFake();
      final limiter = _limiter(
        relogio,
        limitePorChave: 1000,
        limiteGlobal: 100000,
      );

      for (int i = 0; i < 1000; i++) {
        expect(limiter.consumir('chave-$i').permitido, isTrue, reason: '$i');
        relogio.avancar(const Duration(seconds: 1));
      }

      // A varredura roda no maximo uma vez por janela, entao o mapa fica
      // limitado a cerca de duas janelas de chaves distintas.
      expect(limiter.bucketsAtivos, lessThanOrEqualTo(121));
    });
  });
}
