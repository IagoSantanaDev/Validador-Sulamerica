import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/agendador_lotes.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

class _SessaoFake extends SessaoPortal {
  _SessaoFake() : super(logger: Logger(level: Level.off));

  bool _autenticada = false;
  int encerramentos = 0;

  @override
  bool get autenticada => _autenticada;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    _autenticada = true;
    return const ResultadoLogin.autenticado();
  }

  @override
  Future<ResultadoLogin> garantirAutenticada() async {
    if (_autenticada) return const ResultadoLogin.autenticado();
    return login(code: 'code', user: 'user', senha: 'senha');
  }

  @override
  Future<void> encerrar() async {
    encerramentos++;
  }
}

CredenciaisPortal _credenciais() => CredenciaisPortal.resolver(
  'teste',
  ambiente: const <String, String>{
    'PORTAL_PRESTADOR_ID_TESTE_CODE': 'code',
    'PORTAL_PRESTADOR_ID_TESTE_USER': 'user',
    'PORTAL_PRESTADOR_ID_TESTE_SENHA': 'senha',
  },
)!;

void main() {
  test('faz rodízio entre identificadores e lotes', () async {
    final List<_SessaoFake> sessoes = <_SessaoFake>[];
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) {
        final _SessaoFake sessao = _SessaoFake();
        sessoes.add(sessao);
        return sessao;
      },
    );
    await pool.garantirAutenticada('teste', _credenciais());
    await pool.garantirAutenticada('outro', _credenciais());
    final Completer<void> gate = Completer<void>();
    final List<String> iniciadas = <String>[];
    final AgendadorLotes agendador = AgendadorLotes(
      pool: pool,
      executarConsulta: (sessao, consulta, cancelToken) async {
        iniciadas.add(consulta['lote'] as String);
        await gate.future;
        return <String, dynamic>{'sucesso': true};
      },
      limiteGlobal: 3,
    );

    final List<ExecucaoAgendada> execucoes = <ExecucaoAgendada>[
      _agendar(agendador, 'teste', 'a1'),
      _agendar(agendador, 'outro', 'b1'),
      _agendar(agendador, 'teste', 'a2'),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(iniciadas, hasLength(3));
    expect(iniciadas.toSet(), <String>{'a1', 'a2', 'b1'});

    gate.complete();
    await _aguardar(() => agendador.ativas == 0);
    for (final ExecucaoAgendada execucao in execucoes) {
      execucao.execucao.descartar();
    }
  });

  test('limita execuções ativas e cancela somente o lote solicitado', () async {
    final List<_SessaoFake> sessoes = <_SessaoFake>[];
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) {
        final _SessaoFake sessao = _SessaoFake();
        sessoes.add(sessao);
        return sessao;
      },
    );
    await pool.garantirAutenticada('teste', _credenciais());
    final Completer<void> gate = Completer<void>();
    final List<CancelToken> tokens = <CancelToken>[];
    final AgendadorLotes agendador = AgendadorLotes(
      pool: pool,
      executarConsulta: (sessao, consulta, cancelToken) async {
        tokens.add(cancelToken);
        await gate.future;
        return <String, dynamic>{'sucesso': true};
      },
    );
    final ExecucaoAgendada primeira = _agendar(agendador, 'teste', 'one');
    final ExecucaoAgendada segunda = _agendar(agendador, 'teste', 'two');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    primeira.execucao.cancelar();
    expect(tokens.length, 2);
    expect(tokens.first.isCancelled, isTrue);
    expect(tokens.last.isCancelled, isFalse);
    expect(sessoes.every((sessao) => sessao.encerramentos == 0), isTrue);

    gate.complete();
    await _aguardar(() => agendador.ativas == 0);
    expect(segunda.execucao.estado.name, 'concluido');
    expect(primeira.execucao.estado.name, 'cancelado');
    primeira.execucao.descartar();
    segunda.execucao.descartar();
  });

  test('limite total inclui fila e processamento', () async {
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) => _SessaoFake(),
    );
    await pool.garantirAutenticada('teste', _credenciais());
    final Completer<void> gate = Completer<void>();
    final AgendadorLotes agendador = AgendadorLotes(
      pool: pool,
      executarConsulta: (sessao, consulta, cancelToken) async {
        await gate.future;
        return <String, dynamic>{'sucesso': true};
      },
    );
    final List<ExecucaoAgendada> aceitas = <ExecucaoAgendada>[
      for (int i = 0; i < 24; i++) _agendar(agendador, 'teste', '$i'),
    ];

    expect(agendador.ativas, 24);
    expect(
      () => _agendar(agendador, 'teste', '25'),
      throwsA(isA<FilaCheiaException>()),
    );

    gate.complete();
    await _aguardar(() => agendador.ativas == 0);
    for (final ExecucaoAgendada execucao in aceitas) {
      execucao.execucao.descartar();
    }
  });

  test('doze lotes de trezentos itens iniciam sem monopolização', () async {
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) => _SessaoFake(),
    );
    await pool.garantirAutenticada('teste', _credenciais());
    final Completer<void> primeirasConsultas = Completer<void>();
    final Set<String> iniciadas = <String>{};
    final AgendadorLotes agendador = AgendadorLotes(
      pool: pool,
      executarConsulta: (sessao, consulta, cancelToken) async {
        if (consulta['indice'] == 0) {
          iniciadas.add(consulta['lote'] as String);
          await primeirasConsultas.future;
        }
        return <String, dynamic>{'sucesso': true};
      },
    );
    final List<ExecucaoAgendada> execucoes = <ExecucaoAgendada>[
      for (int lote = 0; lote < 12; lote++)
        agendador.agendar(
          identificadorPrestador: 'teste',
          tokenDono: 'token-$lote',
          credenciais: _credenciais(),
          consultas: <Map<String, dynamic>>[
            for (int indice = 0; indice < 300; indice++)
              <String, dynamic>{
                'tipo': 'senha',
                'chave': '5000000000',
                'lote': '$lote',
                'indice': indice,
              },
          ],
          aoFinalizar: () {},
        ),
    ];

    await _aguardar(() => iniciadas.length == 12);
    expect(iniciadas, <String>{for (int lote = 0; lote < 12; lote++) '$lote'});
    expect(
      execucoes.every(
        (execucao) => execucao.execucao.estado.name == 'processando',
      ),
      isTrue,
    );

    primeirasConsultas.complete();
    await _aguardar(() => agendador.ativas == 0);
    expect(
      execucoes.every((execucao) => execucao.execucao.concluidas == 300),
      isTrue,
    );
    for (final ExecucaoAgendada execucao in execucoes) {
      execucao.execucao.descartar();
    }
  });

  test('limita a dezesseis requisições simultâneas ao portal', () async {
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) => _SessaoFake(),
    );
    await pool.garantirAutenticada('teste', _credenciais());
    await pool.garantirAutenticada('outro', _credenciais());
    final Completer<void> gate = Completer<void>();
    int ativas = 0;
    int maximo = 0;
    final AgendadorLotes agendador = AgendadorLotes(
      pool: pool,
      executarConsulta: (sessao, consulta, cancelToken) async {
        ativas++;
        if (ativas > maximo) maximo = ativas;
        await gate.future;
        ativas--;
        return <String, dynamic>{'sucesso': true};
      },
    );
    final List<ExecucaoAgendada> aceitas = <ExecucaoAgendada>[
      for (int i = 0; i < 12; i++) _agendar(agendador, 'teste', 'a-$i'),
      for (int i = 0; i < 12; i++) _agendar(agendador, 'outro', 'b-$i'),
    ];

    await _aguardar(() => maximo == 16);
    expect(ativas, 16);
    expect(maximo, 16);
    gate.complete();
    await _aguardar(() => agendador.ativas == 0);
    for (final ExecucaoAgendada execucao in aceitas) {
      execucao.execucao.descartar();
    }
  });
}

ExecucaoAgendada _agendar(
  AgendadorLotes agendador,
  String identificador,
  String rotulo,
) => agendador.agendar(
  identificadorPrestador: identificador,
  tokenDono: 'token-$rotulo',
  credenciais: _credenciais(),
  consultas: <Map<String, dynamic>>[
    <String, dynamic>{'tipo': 'senha', 'chave': '5000000000', 'lote': rotulo},
  ],
  aoFinalizar: () {},
);

Future<void> _aguardar(bool Function() condicao) async {
  for (int tentativa = 0; tentativa < 200 && !condicao(); tentativa++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condicao(), isTrue, reason: 'operação assíncrona não finalizou');
}
