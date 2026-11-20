import 'dart:async';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/disjuntor_portal.dart';

void main() {
  test('abre após cinco falhas elegíveis consecutivas na janela', () async {
    final DateTime agora = DateTime.utc(2026);
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      agora: () => agora,
    );

    for (int i = 0; i < 4; i++) {
      (await disjuntor.tentarAdquirir())!.concluir(
        ResultadoDisjuntorPortal.falhaElegivel,
      );
    }
    expect(disjuntor.estado, EstadoDisjuntorPortal.fechado);
    (await disjuntor.tentarAdquirir())!.concluir(
      ResultadoDisjuntorPortal.falhaElegivel,
    );
    expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 5);
    expect(await disjuntor.tentarAdquirir(), isNull);
  });

  test(
    'resultado tardio de uma geração antiga não fecha o disjuntor',
    () async {
      final DisjuntorPortal disjuntor = DisjuntorPortal(
        sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
      );
      final List<PermissaoDisjuntorPortal> permissoes =
          <PermissaoDisjuntorPortal>[
            for (int i = 0; i < 6; i++) (await disjuntor.tentarAdquirir())!,
          ];

      for (final PermissaoDisjuntorPortal permissao
          in permissoes.skip(1).take(5)) {
        permissao.concluir(ResultadoDisjuntorPortal.falhaElegivel);
      }
      expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);

      permissoes.first.concluir(ResultadoDisjuntorPortal.sucesso);
      expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
      expect(disjuntor.diagnostico['falhasConsecutivas'], 5);
    },
  );

  test(
    'sucesso elegível limpa sequência e falha fora da janela inicia outra',
    () async {
      DateTime agora = DateTime.utc(2026);
      final DisjuntorPortal disjuntor = DisjuntorPortal(
        sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
        agora: () => agora,
      );

      for (int i = 0; i < 4; i++) {
        final PermissaoDisjuntorPortal permissao = (await disjuntor
            .tentarAdquirir())!;
        permissao.concluir(ResultadoDisjuntorPortal.falhaElegivel);
      }
      (await disjuntor.tentarAdquirir())!.concluir(
        ResultadoDisjuntorPortal.sucesso,
      );
      expect(disjuntor.diagnostico['falhasConsecutivas'], 0);

      for (int i = 0; i < 4; i++) {
        (await disjuntor.tentarAdquirir())!.concluir(
          ResultadoDisjuntorPortal.falhaElegivel,
        );
      }
      agora = agora.add(const Duration(seconds: 61));
      (await disjuntor.tentarAdquirir())!.concluir(
        ResultadoDisjuntorPortal.falhaElegivel,
      );
      expect(disjuntor.estado, EstadoDisjuntorPortal.fechado);
      expect(disjuntor.diagnostico['falhasConsecutivas'], 1);
    },
  );

  test(
    'cooldown exige sonda, e sonda malsucedida reabre por mais 60s',
    () async {
      DateTime agora = DateTime.utc(2026);
      int statusSonda = 503;
      final DisjuntorPortal disjuntor = DisjuntorPortal(
        sondarPortal: () async => ResultadoSondaDisjuntor(status: statusSonda),
        agora: () => agora,
      );

      for (int i = 0; i < 5; i++) {
        (await disjuntor.tentarAdquirir())!.concluir(
          ResultadoDisjuntorPortal.falhaElegivel,
        );
      }
      expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);

      agora = agora.add(const Duration(seconds: 60));
      expect(disjuntor.estado, EstadoDisjuntorPortal.meioAberto);
      expect(await disjuntor.tentarAdquirir(), isNull);
      expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
      expect(disjuntor.retryAfterSegundos, 60);

      agora = agora.add(const Duration(seconds: 60));
      statusSonda = 200;
      final PermissaoDisjuntorPortal? permissao = await disjuntor
          .tentarAdquirir();
      expect(permissao, isNotNull);
      expect(disjuntor.estado, EstadoDisjuntorPortal.fechado);
      permissao!.concluir(ResultadoDisjuntorPortal.neutra);
    },
  );

  test('429 e respostas não elegíveis não acumulam falhas', () async {
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async => const ResultadoSondaDisjuntor(status: 200),
    );

    for (int i = 0; i < 8; i++) {
      (await disjuntor.tentarAdquirir())!.concluir(
        ResultadoDisjuntorPortal.neutra,
      );
    }
    expect(disjuntor.estado, EstadoDisjuntorPortal.fechado);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 0);
  });

  test('F5 em resposta da sonda não é contado como falha elegível', () async {
    DateTime agora = DateTime.utc(2026);
    final DisjuntorPortal disjuntor = DisjuntorPortal(
      sondarPortal: () async =>
          const ResultadoSondaDisjuntor(status: 503, rejeicaoF5: true),
      agora: () => agora,
    );
    for (int i = 0; i < 5; i++) {
      (await disjuntor.tentarAdquirir())!.concluir(
        ResultadoDisjuntorPortal.falhaElegivel,
      );
    }

    agora = agora.add(const Duration(seconds: 60));
    expect(await disjuntor.tentarAdquirir(), isNull);
    expect(disjuntor.diagnostico['falhasConsecutivas'], 5);
    expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
  });

  test(
    'sonda half-open é exclusiva e falha de sonda reabre após cancelamento',
    () async {
      DateTime agora = DateTime.utc(2026);
      final Completer<ResultadoSondaDisjuntor> sonda =
          Completer<ResultadoSondaDisjuntor>();
      final DisjuntorPortal disjuntor = DisjuntorPortal(
        sondarPortal: () => sonda.future,
        agora: () => agora,
      );
      for (int i = 0; i < 5; i++) {
        (await disjuntor.tentarAdquirir())!.concluir(
          ResultadoDisjuntorPortal.falhaElegivel,
        );
      }

      agora = agora.add(const Duration(seconds: 60));
      final Future<PermissaoDisjuntorPortal?> primeira = disjuntor
          .tentarAdquirir();
      await Future<void>.delayed(Duration.zero);
      expect(disjuntor.diagnostico['sondaEmAndamento'], isTrue);
      expect(await disjuntor.tentarAdquirir(), isNull);
      sonda.completeError(Exception('sonda cancelada'));
      expect(await primeira, isNull);
      expect(disjuntor.estado, EstadoDisjuntorPortal.aberto);
      expect(disjuntor.retryAfterSegundos, 60);
    },
  );
}
