import 'package:logger/logger.dart';
import 'package:test/test.dart';
import 'package:validador_backend/modules/sulamerica/data/credenciais_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/pool_sessoes_portal.dart';
import 'package:validador_backend/modules/sulamerica/data/sessao_portal.dart';

class _SessaoFake extends SessaoPortal {
  _SessaoFake() : super(logger: Logger(level: Level.off));

  bool _autenticada = false;
  int logins = 0;

  @override
  bool get autenticada => _autenticada;

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async {
    logins++;
    _autenticada = true;
    return const ResultadoLogin.autenticado();
  }

  @override
  Future<ResultadoLogin> garantirAutenticada() async {
    if (_autenticada) return const ResultadoLogin.autenticado();
    return login(code: 'code', user: 'user', senha: 'senha');
  }

  @override
  Future<void> encerrar() async {}
}

class _SessaoFalhaFake extends SessaoPortal {
  _SessaoFalhaFake() : super(logger: Logger(level: Level.off));

  @override
  Map<String, int> get diagnosticoSessao => const <String, int>{
    'loginGetHttp403': 1,
    'assinaturaF5MarkerSupportId': 1,
  };

  @override
  Future<ResultadoLogin> login({
    required String code,
    required String user,
    required String senha,
  }) async =>
      const ResultadoLogin.falha(MotivoFalhaLogin.respostaInesperada);

  @override
  Future<void> encerrar() async {}
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
  test('preserva diagnóstico de sessão descartada após login inicial', () async {
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) => _SessaoFalhaFake(),
    );

    await expectLater(
      pool.garantirAutenticada('teste', _credenciais()),
      throwsA(isA<FalhaPoolSessoesException>()),
    );

    expect(pool.sessoesAtivas, 0);
    expect(pool.diagnosticoSessaoPortal['loginGetHttp403'], 1);
    expect(pool.diagnosticoSessaoPortal['assinaturaF5MarkerSupportId'], 1);
  });

  test('logins concorrentes coalescem em uma sessão', () async {
    final List<_SessaoFake> criadas = <_SessaoFake>[];
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) {
        final _SessaoFake sessao = _SessaoFake();
        criadas.add(sessao);
        return sessao;
      },
    );

    await Future.wait(
      List<Future<SessaoPortal>>.generate(
        12,
        (_) => pool.garantirAutenticada('teste', _credenciais()),
      ),
    );

    expect(pool.sessoesAtivas, 1);
    expect(criadas, hasLength(1));
    expect(criadas.single.logins, 1);
  });

  test('cria sessão sob demanda e não excede quatro por identificador',
      () async {
    final List<_SessaoFake> criadas = <_SessaoFake>[];
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) {
        final _SessaoFake sessao = _SessaoFake();
        criadas.add(sessao);
        return sessao;
      },
    );
    await pool.garantirAutenticada('teste', _credenciais());

    final List<EmprestimoSessaoPortal> emprestimos = await Future.wait(
      List<Future<EmprestimoSessaoPortal>>.generate(
        12,
        (_) => pool.adquirir(
          identificador: 'teste',
          credenciais: _credenciais(),
          tipo: TipoConsultaPortal.senha,
        ),
      ),
    );

    expect(pool.sessoesAtivas, 4);
    expect(criadas, hasLength(4));
    expect(criadas.map((sessao) => sessao.logins), everyElement(1));

    bool liberada = false;
    final Future<EmprestimoSessaoPortal> aguardando = pool
        .adquirir(
          identificador: 'teste',
          credenciais: _credenciais(),
          tipo: TipoConsultaPortal.senha,
        )
        .then((EmprestimoSessaoPortal emprestimo) {
      liberada = true;
      return emprestimo;
    });
    await Future<void>.delayed(Duration.zero);
    expect(liberada, isFalse);
    emprestimos.first.liberar();
    final EmprestimoSessaoPortal proxima = await aguardando;
    proxima.liberar();
    for (final EmprestimoSessaoPortal emprestimo in emprestimos) {
      emprestimo.liberar();
    }
  });

  test('elegibilidades são serializadas por sessão e senha aceita três',
      () async {
    final List<_SessaoFake> criadas = <_SessaoFake>[];
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) {
        final _SessaoFake sessao = _SessaoFake();
        criadas.add(sessao);
        return sessao;
      },
    );
    await pool.garantirAutenticada('teste', _credenciais());

    final List<EmprestimoSessaoPortal> senhas = await Future.wait(
      List<Future<EmprestimoSessaoPortal>>.generate(
        3,
        (_) => pool.adquirir(
          identificador: 'teste',
          credenciais: _credenciais(),
          tipo: TipoConsultaPortal.senha,
        ),
      ),
    );
    expect(senhas.map((lease) => lease.sessao).toSet(), hasLength(1));

    final Future<EmprestimoSessaoPortal> elegibilidade = pool.adquirir(
      identificador: 'teste',
      credenciais: _credenciais(),
      tipo: TipoConsultaPortal.elegibilidade,
    );
    final EmprestimoSessaoPortal elegibilidadeAdquirida =
        await elegibilidade;
    expect(elegibilidadeAdquirida.sessao, same(senhas.first.sessao));

    final EmprestimoSessaoPortal segundaElegibilidade =
        await pool.adquirir(
      identificador: 'teste',
      credenciais: _credenciais(),
      tipo: TipoConsultaPortal.elegibilidade,
    );
    expect(segundaElegibilidade.sessao, isNot(same(senhas.first.sessao)));

    for (final EmprestimoSessaoPortal senha in senhas) {
      senha.liberar();
    }
    elegibilidadeAdquirida.liberar();
    segundaElegibilidade.liberar();
  });

  test('lease libera a capacidade uma única vez', () async {
    final PoolSessoesPortal pool = PoolSessoesPortal(
      fabricaSessao: (_) => _SessaoFake(),
    );
    await pool.garantirAutenticada('teste', _credenciais());
    final EmprestimoSessaoPortal emprestimo = await pool.adquirir(
      identificador: 'teste',
      credenciais: _credenciais(),
      tipo: TipoConsultaPortal.elegibilidade,
    );

    emprestimo
      ..liberar()
      ..liberar();
    final EmprestimoSessaoPortal seguinte = await pool.adquirir(
      identificador: 'teste',
      credenciais: _credenciais(),
      tipo: TipoConsultaPortal.elegibilidade,
    );
    seguinte.liberar();
  });
}
