import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/execucao_lote.dart';
import 'package:validador_backend/modules/sulamerica/data/repositorio_sessoes.dart';

class _Relogio {
  DateTime agora = DateTime.utc(2026, 1, 1);

  void avancar(Duration intervalo) => agora = agora.add(intervalo);
}

void main() {
  test('limite rejeita sem eviction e tokens expiram por TTL deslizante', () {
    final _Relogio relogio = _Relogio();
    final RepositorioSessoes repositorio = RepositorioSessoes(
      limite: 1,
      ttl: const Duration(hours: 12),
      relogio: () => relogio.agora,
    );
    final SessaoLogica sessao = repositorio.criar('prestador');

    relogio.avancar(const Duration(hours: 11));
    expect(repositorio.obter(sessao.token), same(sessao));
    relogio.avancar(const Duration(hours: 11));
    expect(
      () => repositorio.criar('outro'),
      throwsA(isA<RepositorioSessoesCheioException>()),
    );
    expect(repositorio.quantidade, 1);

    relogio.avancar(const Duration(hours: 1, seconds: 1));
    final SessaoLogica seguinte = repositorio.criar('outro');
    expect(repositorio.quantidade, 1);
    expect(repositorio.obter(sessao.token), isNull);
    expect(seguinte.token, hasLength(32));
  });

  test('token vinculado não expira e começa TTL ao liberar', () {
    final _Relogio relogio = _Relogio();
    final RepositorioSessoes repositorio = RepositorioSessoes(
      limite: 1,
      ttl: const Duration(hours: 12),
      relogio: () => relogio.agora,
    );
    final SessaoLogica sessao = repositorio.criar('prestador');
    expect(repositorio.vincular(sessao.token), isTrue);

    relogio.avancar(const Duration(days: 2));
    expect(repositorio.obter(sessao.token), same(sessao));
    repositorio.desvincular(sessao.token);
    relogio.avancar(const Duration(hours: 11));
    expect(repositorio.obter(sessao.token), same(sessao));
    relogio.avancar(const Duration(hours: 12, seconds: 1));
    expect(repositorio.obter(sessao.token), isNull);
  });

  test('idempotência retorna execução ativa ou detecta payload divergente', () {
    final RepositorioSessoes repositorio = RepositorioSessoes();
    final SessaoLogica sessao = repositorio.criar('prestador');
    final ExecucaoLote execucao = ExecucaoLote(total: 1);
    addTearDown(execucao.descartar);
    const List<Map<String, dynamic>> consultas = <Map<String, dynamic>>[
      <String, dynamic>{'tipo': 'senha', 'chave': '5000000000'},
    ];
    repositorio.registrarIdempotencia(
      sessao,
      'key',
      consultas,
      'batch-id',
      execucao,
    );

    final ConsultaIdempotencia repetida = repositorio.consultarIdempotencia(
      sessao,
      'key',
      consultas,
    );
    expect(repetida.estado, EstadoIdempotencia.repetida);
    expect(repetida.id, 'batch-id');
    expect(repetida.execucao, same(execucao));
    expect(
      repositorio.consultarIdempotencia(
        sessao,
        'key',
        const <Map<String, dynamic>>[
          <String, dynamic>{'tipo': 'senha', 'chave': '5111111111'},
        ],
      ).estado,
      EstadoIdempotencia.conflito,
    );
  });

  test('idempotência deixa de reter a execução depois do fim', () {
    final RepositorioSessoes repositorio = RepositorioSessoes();
    final SessaoLogica sessao = repositorio.criar('prestador');
    final ExecucaoLote execucao = ExecucaoLote(total: 0);
    addTearDown(execucao.descartar);
    execucao
      ..iniciar()
      ..concluir(resultados: const <Map<String, dynamic>>[]);
    repositorio.registrarIdempotencia(
      sessao,
      'key',
      const <Map<String, dynamic>>[],
      'batch-id',
      execucao,
    );
    repositorio.removerIdempotencia(sessao.token, 'key', execucao);

    expect(
      repositorio
          .consultarIdempotencia(sessao, 'key', const <Map<String, dynamic>>[])
          .estado,
      EstadoIdempotencia.nova,
    );
  });
}
