import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';

/// Assinante de teste que guarda cada chunk já decodificado, preservando os
/// limites enviados pelo servidor para que o formato seja conferido.
class _AssinanteTeste {
  _AssinanteTeste(ExecucaoLote execucao, {int? desde}) {
    _assinatura = execucao.assinar(desde: desde).listen(
      (List<int> parte) => partes.add(utf8.decode(parte)),
      onDone: () {
        if (!concluido.isCompleted) concluido.complete();
      },
    );
  }

  final List<String> partes = <String>[];
  final Completer<void> concluido = Completer<void>();
  late final StreamSubscription<List<int>> _assinatura;

  String get texto => partes.join();

  List<String> get progressos => partes
      .where((String parte) => parte.contains('event: progresso'))
      .toList();

  List<String> get resultados => partes
      .where((String parte) => parte.contains('event: resultado'))
      .toList();

  Future<void> fechar() => _assinatura.cancel();
}

void main() {
  test('formato exato de retry, id, event e data e ordem dos eventos',
      () async {
    final ExecucaoLote execucao = ExecucaoLote(total: 2);
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);

    execucao
      ..iniciar()
      ..registrarConclusao(2)
      ..concluir(
        resultados: <Map<String, dynamic>>[
          <String, dynamic>{
            'tipo': 'elegibilidade',
            'chave': '123',
            'sucesso': true,
          },
        ],
      );
    await cliente.concluido.future;

    expect(cliente.partes.first, 'retry: 3000\n\n');
    expect(
      cliente.texto,
      'retry: 3000\n\n'
      'id: 1\n'
      'event: progresso\n'
      'data: {"concluidas":2,"total":2}\n'
      '\n'
      'id: 2\n'
      'event: resultado\n'
      'data: {"status":"ok","resultados":[{"tipo":"elegibilidade",'
      '"chave":"123","sucesso":true}]}\n'
      '\n',
    );
    expect(execucao.estado, EstadoExecucaoLote.concluido);
    expect(execucao.resultados.single['chave'], '123');
  });

  test('heartbeat : ping sai a cada intervalo configurado', () async {
    final ExecucaoLote execucao = ExecucaoLote(
      total: 1,
      intervaloHeartbeat: const Duration(milliseconds: 30),
    );
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(
      cliente.partes.where((String parte) => parte == ': ping\n\n').length,
      greaterThanOrEqualTo(2),
    );
    await cliente.fechar();
  });

  test('progresso agregado respeita o intervalo e não perde o evento final',
      () async {
    final ExecucaoLote execucao = ExecucaoLote(
      total: 10,
      intervaloProgresso: const Duration(milliseconds: 40),
    );
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);
    execucao.iniciar();
    for (int i = 0; i < 10; i++) {
      execucao.registrarConclusao();
    }

    await Future<void>.delayed(Duration.zero);
    expect(cliente.partes, hasLength(2));
    expect(cliente.progressos.single, contains('"concluidas":1'));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cliente.progressos, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(cliente.progressos, hasLength(2));
    expect(cliente.progressos.last, contains('"concluidas":10'));

    execucao.concluir(resultados: const <Map<String, dynamic>>[]);
    await cliente.concluido.future;
    expect(cliente.progressos, hasLength(2));
    expect(cliente.resultados, hasLength(1));
  });

  test('replay a partir de desde e somente enquanto ativa', () async {
    final ExecucaoLote execucao = ExecucaoLote(
      total: 5,
      intervaloProgresso: const Duration(seconds: 1),
    );
    addTearDown(execucao.descartar);
    execucao.iniciar();
    execucao.registrarConclusao();

    final _AssinanteTeste cliente = _AssinanteTeste(execucao, desde: 0);
    await Future<void>.delayed(Duration.zero);
    expect(cliente.partes, <String>[
      'retry: 3000\n\n',
      'id: 1\nevent: progresso\ndata: {"concluidas":1,"total":5}\n\n',
    ]);

    final _AssinanteTeste semReplay = _AssinanteTeste(execucao, desde: 1);
    await Future<void>.delayed(Duration.zero);
    expect(semReplay.partes, <String>['retry: 3000\n\n']);

    execucao.concluir(resultados: const <Map<String, dynamic>>[]);
    await cliente.concluido.future;
    await semReplay.concluido.future;
    expect(cliente.resultados, hasLength(1));
    expect(semReplay.resultados, hasLength(1));

    final _AssinanteTeste tardio = _AssinanteTeste(execucao, desde: 0);
    await tardio.concluido.future;
    expect(tardio.texto, 'retry: 3000\n\n');
  });

  test('ids são sequenciais e monotônicos', () async {
    final ExecucaoLote execucao = ExecucaoLote(
      total: 4,
      intervaloProgresso: Duration.zero,
    );
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);

    execucao.iniciar();
    execucao
      ..registrarConclusao()
      ..registrarConclusao()
      ..registrarConclusao()
      ..falhar('portal indisponível');
    await cliente.concluido.future;

    final List<int> ids =
        execucao.eventos.map((EventoExecucao evento) => evento.id).toList();
    expect(ids, List<int>.generate(ids.length, (int i) => i + 1));
    expect(ids.length, greaterThanOrEqualTo(2));
    expect(execucao.ultimoId, ids.last);
    expect(execucao.estado, EstadoExecucaoLote.falhou);
    expect(cliente.partes.last, contains('event: erro'));
    expect(cliente.partes.last, contains('"mensagem":"portal indisponível"'));
  });

  test('resultado final é entregue uma única vez', () async {
    final ExecucaoLote execucao = ExecucaoLote(total: 0);
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);

    execucao
      ..iniciar()
      ..concluir(resultados: const <Map<String, dynamic>>[])
      ..concluir(
        resultados: <Map<String, dynamic>>[
          <String, dynamic>{'chave': 'duplicada'},
        ],
      );
    await cliente.concluido.future;

    expect(cliente.resultados, hasLength(1));
    expect(execucao.eventos, hasLength(1));
  });

  test('cancelamento dispara só depois da carência sem assinantes', () async {
    int cancelamentos = 0;
    final ExecucaoLote execucao = ExecucaoLote(
      total: 3,
      carenciaSemAssinantes: const Duration(milliseconds: 40),
      aoCancelar: () => cancelamentos++,
    );
    addTearDown(execucao.descartar);
    execucao.iniciar();
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(execucao.assinantes, 1);

    await cliente.fechar();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(execucao.estado, EstadoExecucaoLote.processando);
    expect(cancelamentos, 0);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(execucao.estado, EstadoExecucaoLote.cancelado);
    expect(cancelamentos, 1);
  });

  test('assinante que volta antes da carência evita o cancelamento', () async {
    int cancelamentos = 0;
    final ExecucaoLote execucao = ExecucaoLote(
      total: 3,
      carenciaSemAssinantes: const Duration(milliseconds: 40),
      aoCancelar: () => cancelamentos++,
    );
    addTearDown(execucao.descartar);
    execucao.iniciar();
    final _AssinanteTeste primeiro = _AssinanteTeste(execucao);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await primeiro.fechar();

    await Future<void>.delayed(const Duration(milliseconds: 15));
    final _AssinanteTeste segundo = _AssinanteTeste(execucao);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(execucao.estado, EstadoExecucaoLote.processando);
    expect(execucao.assinantes, 1);
    expect(cancelamentos, 0);
    await segundo.fechar();
  });

  test('descartar limpa buffer, resultados, assinantes e timers', () async {
    int cancelamentos = 0;
    final ExecucaoLote execucao = ExecucaoLote(
      total: 10,
      intervaloProgresso: const Duration(milliseconds: 20),
      intervaloHeartbeat: const Duration(milliseconds: 20),
      carenciaSemAssinantes: const Duration(milliseconds: 20),
      aoCancelar: () => cancelamentos++,
    );
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);
    execucao
      ..iniciar()
      ..registrarConclusao();

    execucao.descartar();
    execucao.descartar();

    expect(execucao.descartado, isTrue);
    expect(execucao.eventos, isEmpty);
    expect(execucao.resultados, isEmpty);
    expect(execucao.assinantes, 0);
    await cliente.concluido.future.timeout(const Duration(seconds: 1));

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(execucao.eventos, isEmpty);
    expect(cancelamentos, 0);
    expect(execucao.estado, EstadoExecucaoLote.processando);
  });

  test('descartar limpa os resultados retidos após o fim', () async {
    final ExecucaoLote execucao = ExecucaoLote(total: 1);
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);
    execucao
      ..iniciar()
      ..concluir(
        resultados: <Map<String, dynamic>>[
          <String, dynamic>{'chave': '1'},
        ],
      );
    await cliente.concluido.future;
    expect(execucao.resultados, hasLength(1));

    execucao.descartar();
    expect(execucao.resultados, isEmpty);
    expect(execucao.eventos, isEmpty);
  });

  test('cancelamento manual encerra assinantes e roda o callback uma vez',
      () async {
    int cancelamentos = 0;
    final ExecucaoLote execucao = ExecucaoLote(
      total: 5,
      aoCancelar: () => cancelamentos++,
    );
    addTearDown(execucao.descartar);
    final _AssinanteTeste cliente = _AssinanteTeste(execucao);
    execucao.iniciar();

    execucao
      ..cancelar()
      ..cancelar();
    await cliente.concluido.future;

    expect(execucao.estado, EstadoExecucaoLote.cancelado);
    expect(cancelamentos, 1);
    expect(cliente.partes.last, contains('event: erro'));
    expect(execucao.assinantes, 0);
  });
}
