import 'dart:async';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/semaforo_requisicoes.dart';

void main() {
  test('limita operações simultâneas e registra pico e espera', () async {
    final SemaforoRequisicoes semaforo = SemaforoRequisicoes(2);
    final Completer<void> liberar = Completer<void>();
    int ativas = 0;
    int pico = 0;

    Future<void> operacao() => semaforo.executar<void>(() async {
      ativas++;
      if (ativas > pico) pico = ativas;
      await liberar.future;
      ativas--;
    });

    final List<Future<void>> execucoes = List<Future<void>>.generate(
      5,
      (_) => operacao(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(ativas, 2);
    expect(semaforo.diagnostico['ativasAgora'], 2);
    expect(semaforo.diagnostico['aguardandoAgora'], 3);
    expect(semaforo.diagnostico['picoAguardando'], 3);

    liberar.complete();
    await Future.wait(execucoes);

    expect(pico, 2);
    expect(semaforo.diagnostico['picoAtivas'], 2);
    expect(semaforo.diagnostico['ativasAgora'], 0);
    expect(semaforo.diagnostico['totalAguardas'], 3);
  });

  test('fila é justa: quem espera não é ultrapassado', () async {
    final SemaforoRequisicoes semaforo = SemaforoRequisicoes(1);
    final Completer<void> liberar = Completer<void>();
    final List<int> ordem = <int>[];

    Future<void> operacao(int indice) => semaforo.executar<void>(() async {
      await liberar.future;
      ordem.add(indice);
    });

    final List<Future<void>> execucoes = <Future<void>>[
      operacao(1),
      operacao(2),
      operacao(3),
    ];
    await Future<void>.delayed(Duration.zero);
    liberar.complete();
    await Future.wait(execucoes);

    expect(ordem, <int>[1, 2, 3]);
  });

  test('exceção na operação devolve a vaga', () async {
    final SemaforoRequisicoes semaforo = SemaforoRequisicoes(1);

    await expectLater(
      semaforo.executar<void>(() async => throw StateError('falhou')),
      throwsStateError,
    );

    expect(await semaforo.executar<int>(() async => 7), 7);
    expect(semaforo.diagnostico['ativasAgora'], 0);
  });

  test('cancelamento na fila não perde a vaga liberada', () async {
    final SemaforoRequisicoes semaforo = SemaforoRequisicoes(1);
    final Completer<void> liberar = Completer<void>();
    final Future<void> primeira = semaforo.executar<void>(() => liberar.future);
    final CancelToken cancelToken = CancelToken();
    final Future<void> cancelada = semaforo.executar<void>(
      () async {},
      cancelToken: cancelToken,
    );
    await Future<void>.delayed(Duration.zero);

    cancelToken.cancel('cancelada');
    liberar.complete();

    await expectLater(cancelada, throwsA(isA<DioException>()));
    await primeira;
    expect(await semaforo.executar<int>(() async => 9), 9);
    expect(semaforo.diagnostico['ativasAgora'], 0);
  });
}
