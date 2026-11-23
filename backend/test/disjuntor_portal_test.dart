import 'dart:async';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/disjuntor_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/motivo_bloqueio_portal.dart';

void main() {
  test('primeira falha elegível abre bloqueio global com sua causa', () async {
    final DateTime agora = DateTime.utc(2026);
    Map<String, Object?>? aberto;
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      agora: () => agora,
      aoAbrir: (Map<String, Object?> bloqueio) => aberto = bloqueio,
    );

    final PermissaoDisjuntorPortal permissao =
        (await disjuntor.tentarAdquirir())!;
    permissao.concluir(
      ResultadoDisjuntorPortal.falhaElegivel,
      motivo: MotivoBloqueioPortal.limitePortal,
    );

    expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 1);
    expect(disjuntor.retryAfterSegundos, 60);
    expect(disjuntor.bloqueio, containsPair('motivo', 'limite_portal'));
    expect(aberto, disjuntor.bloqueio);
    expect(await disjuntor.tentarAdquirir(), isNull);
  });

  test('falhas simultâneas abrem uma vez e resultados antigos não fecham', () async {
    int aberturas = 0;
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      aoAbrir: (_) => aberturas++,
    );
    final List<PermissaoDisjuntorPortal> permissoes = <PermissaoDisjuntorPortal>[
      for (int i = 0; i < 3; i++) (await disjuntor.tentarAdquirir())!,
    ];

    permissoes[1].concluir(ResultadoDisjuntorPortal.falhaElegivel);
    permissoes[2].concluir(ResultadoDisjuntorPortal.falhaElegivel);
    permissoes.first.concluir(ResultadoDisjuntorPortal.sucesso);

    expect(aberturas, 1);
    expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 1);
  });

  test('sonda exclusiva escalona cooldown e respeita Retry-After maior', () async {
    DateTime agora = DateTime.utc(2026);
    int sondas = 0;
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async {
        sondas++;
        return sondas == 1
            ? const ResultadoSondaDisjuntor(
                status: 429,
                retryAfter: Duration(minutes: 4),
              )
            : const ResultadoSondaDisjuntor(status: 503);
      },
      agora: () => agora,
    );
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);

    agora = agora.add(const Duration(minutes: 1));
    await disjuntor.verificarRecuperacao();
    expect(sondas, 1);
    expect(disjuntor.retryAfterSegundos, 240);
    expect(disjuntor.bloqueio['motivo'], 'limite_portal');

    agora = agora.add(const Duration(minutes: 4));
    await disjuntor.verificarRecuperacao();
    expect(sondas, 2);
    expect(disjuntor.retryAfterSegundos, 600);
    expect(disjuntor.diagnostico['nivelCooldown'], 3);
  });

  test('sonda de recuperação bem-sucedida libera e sucesso real reseta nível', () async {
    DateTime agora = DateTime.utc(2026);
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      agora: () => agora,
    );
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    agora = agora.add(const Duration(minutes: 1));
    await disjuntor.verificarRecuperacao();

    expect(disjuntor.estaBloqueado, isFalse);
    final PermissaoDisjuntorPortal permissao =
        (await disjuntor.tentarAdquirir())!;
    permissao.concluir(ResultadoDisjuntorPortal.sucesso);
    expect(disjuntor.diagnostico['nivelCooldown'], 1);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 0);

    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    expect(disjuntor.retryAfterSegundos, 60);
  });

  test('nível volta ao primeiro cooldown após 15 minutos sem bloqueio', () async {
    DateTime agora = DateTime.utc(2026);
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      agora: () => agora,
    );
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    agora = agora.add(const Duration(minutes: 1));
    await disjuntor.verificarRecuperacao();
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    expect(disjuntor.retryAfterSegundos, 180);

    agora = agora.add(const Duration(minutes: 3));
    await disjuntor.verificarRecuperacao();
    agora = agora.add(const Duration(minutes: 15));
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    expect(disjuntor.retryAfterSegundos, 60);
  });

  test('429, rejeição F5, transporte e resposta inesperada da sonda bloqueiam', () async {
    final List<ResultadoSondaDisjuntor> respostas = <ResultadoSondaDisjuntor>[
      const ResultadoSondaDisjuntor(status: 429),
      const ResultadoSondaDisjuntor(status: 503, rejeicaoF5: true),
      const ResultadoSondaDisjuntor(status: null, falhaTransporte: true),
      const ResultadoSondaDisjuntor(status: 200, respostaInesperada: true),
    ];
    for (final ResultadoSondaDisjuntor resposta in respostas) {
      final DisjuntorPortal disjuntor = DisjuntorPortal(
        sondarPortal: () async => resposta,
      );
      disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
      await disjuntor.verificarRecuperacao();
      expect(disjuntor.estaBloqueado, isTrue);
    }
  });

  test('sonda meio-aberta permite somente uma recuperação simultânea', () async {
    DateTime agora = DateTime.utc(2026);
    final Completer<ResultadoSondaDisjuntor> sonda =
        Completer<ResultadoSondaDisjuntor>();
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () => sonda.future,
      agora: () => agora,
    );
    disjuntor.registrar(ResultadoDisjuntorPortal.falhaElegivel);
    agora = agora.add(const Duration(minutes: 1));

    final Future<void> primeira = disjuntor.verificarRecuperacao();
    await Future<void>.delayed(Duration.zero);
    await disjuntor.verificarRecuperacao();
    expect(disjuntor.diagnostico['sondaEmAndamento'], isTrue);
    sonda.completeError(Exception('sonda interrompida'));
    await primeira;

    expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
    expect(disjuntor.retryAfterSegundos, 180);
  });
}
