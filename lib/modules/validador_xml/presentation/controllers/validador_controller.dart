import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../globals/constants/app_config.dart';
import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/network/result.dart';
import '../../data/datasources/xml_lote_guias_datasource.dart';
import '../../data/datasources/xml_lote_guias_exceptions.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/repositories/regras/regra_senha_prefixo.dart';
import '../../data/models/consulta_lote.dart';
import '../../data/models/guia_validada.dart';
import '../../data/models/informacoes_lote.dart';
import '../../data/models/resultado_consulta_beneficiario.dart';
import '../../data/repositories/validador_guias_repository.dart';
import '../../data/repositories/validador_guias_repository_impl.dart';
import '../../data/services/sul_america_backend_service.dart';

enum StatusValidador { semArquivo, arquivoPronto, validando, concluido, erro }

/// Pré-requisitos de conexão antes de liberar o site: API acessível + login
/// no portal SulAmérica.
enum EstadoConexao {
  verificando,
  apiIndisponivel,
  credenciaisAusentes,
  credenciaisInvalidas,
  pronto,
}

class ValidadorController extends ChangeNotifier {
  ValidadorController({
    ValidadorGuiasRepository? repository,
    SulAmericaBackendService? service,
    String? codigoPrestador,
    String? usuarioPrestador,
    String? senhaPrestador,
  })  : _repository = repository ?? ValidadorGuiasRepositoryImpl(),
        _service = service ?? _servicePadrao(),
        _codigoPrestador = codigoPrestador ?? AppConfig.portalCode,
        _usuarioPrestador = usuarioPrestador ?? AppConfig.portalUser,
        _senhaPrestador = senhaPrestador ?? AppConfig.portalSenha;

  final ValidadorGuiasRepository _repository;
  final XmlLoteGuiasDatasource _datasource = const XmlLoteGuiasDatasource();
  final SulAmericaBackendService? _service;
  final String? _codigoPrestador;
  final String? _usuarioPrestador;
  final String? _senhaPrestador;

  String? _tokenSessao;

  /// Pré-requisito de conexão: o site só funciona com a API acessível e com
  /// login no portal (sem isso, validação local fica bloqueada).
  EstadoConexao _estadoConexao = EstadoConexao.verificando;

  EstadoConexao get estadoConexao => _estadoConexao;

  Future<void> verificarDisponibilidadeApi() async {
    final SulAmericaBackendService? service = _service;
    _estadoConexao = EstadoConexao.verificando;
    notifyListeners();
    if (service == null) {
      _estadoConexao = EstadoConexao.apiIndisponivel;
      notifyListeners();
      return;
    }

    final Result<Map<String, dynamic>> status = await service.status();
    if (status is! Success<Map<String, dynamic>>) {
      _estadoConexao = EstadoConexao.apiIndisponivel;
      notifyListeners();
      return;
    }

    final String? code = _codigoPrestador;
    final String? user = _usuarioPrestador;
    final String? senha = _senhaPrestador;
    if (code == null ||
        code.isEmpty ||
        user == null ||
        user.isEmpty ||
        senha == null ||
        senha.isEmpty) {
      _estadoConexao = EstadoConexao.credenciaisAusentes;
      notifyListeners();
      return;
    }

    final Result<String> login = await service.login(
      code: code,
      user: user,
      senha: senha,
    );
    if (login is Success<String>) {
      _tokenSessao = login.valor;
      _estadoConexao = EstadoConexao.pronto;
    } else {
      _estadoConexao = EstadoConexao.credenciaisInvalidas;
    }
    notifyListeners();
  }

  /// Dedupe intra-lote: a mesma carteira/senha repetida no mesmo arquivo é
  /// consultada uma única vez (resultado idêntico no mesmo instante). O cache
  /// é limpo a cada validação — não envelhece dados entre lotes.
  final Map<String, ConsultaGuia> _cacheElegibilidade = {};
  final Map<String, ConsultaGuia> _cacheAutorizacao = {};

  StatusValidador _status = StatusValidador.semArquivo;
  String? _nomeArquivo;
  Uint8List? _bytesArquivo;
  List<GuiaValidada> _resultado = const [];
  String? _mensagemErro;
  InformacoesLote _informacoes = InformacoesLote.vazio;
  String? _hashMd5;
  Duration _tempoProcessamento = Duration.zero;

  StatusValidador get status => _status;
  String? get nomeArquivo => _nomeArquivo;
  String? get mensagemErro => _mensagemErro;
  int? get tamanhoArquivoBytes => _bytesArquivo?.length;

  List<GuiaValidada> get guiasComErro =>
      _resultado.where((g) => g.temErro || g.temFalhaConsulta).toList();

  List<GuiaValidada> get guias => _resultado;

  int get totalGuias => _resultado.length;
  int get totalGuiasComErro => _resultado.where((guia) => guia.temErro).length;

  InformacoesLote get informacoes => _informacoes;
  String? get hashMd5 => _hashMd5;
  Duration get tempoProcessamento => _tempoProcessamento;

  static SulAmericaBackendService? _servicePadrao() {
    try {
      return GetIt.instance.get<SulAmericaBackendService>();
    } catch (_) {
      return null;
    }
  }

  void definirArquivo({
    required String nomeArquivo,
    required Uint8List bytes,
  }) {
    _nomeArquivo = nomeArquivo;
    _bytesArquivo = bytes;
    _status = StatusValidador.arquivoPronto;
    _mensagemErro = null;
    _resultado = const [];
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = md5.convert(bytes).toString();
    notifyListeners();
  }

  Future<void> validar() async {
    final Uint8List? bytes = _bytesArquivo;
    if (bytes == null) return;

    _status = StatusValidador.validando;
    _mensagemErro = null;
    notifyListeners();

    final Stopwatch cronometro = Stopwatch()..start();
    try {
      final String conteudoXml = _decodificarXml(bytes);
      final InformacoesLote informacoes =
          _datasource.extrairInformacoesDoLote(conteudoXml);
      final List<GuiaValidada> resultadoBruto =
          await Future(() => _repository.validarLote(conteudoXml));
      final List<GuiaValidada> comConsultas =
          await _consultarGuias(resultadoBruto);

      _resultado = _ordenarPorNumeroGuia(comConsultas);
      _informacoes = informacoes;
      _status = StatusValidador.concluido;
    } on XmlMalFormadoException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = erro.toString();
    } on NenhumaGuiaEncontradaException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = erro.toString();
    } catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = 'Erro inesperado ao validar o arquivo: $erro';
    } finally {
      cronometro.stop();
      _tempoProcessamento = cronometro.elapsed;
    }
    notifyListeners();
  }

  void novoArquivo() {
    _status = StatusValidador.semArquivo;
    _nomeArquivo = null;
    _bytesArquivo = null;
    _resultado = const [];
    _mensagemErro = null;
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = null;
    _tempoProcessamento = Duration.zero;
    notifyListeners();
  }

  /// Consulta o portal (via /api/consultas em lote) para as guias do lote:
  /// elegibilidade pela carteira SEMPRE que ela for válida; consulta de senha
  /// quando a senha for válida. Falhas estruturais viram erros na guia.
  Future<List<GuiaValidada>> _consultarGuias(
    List<GuiaValidada> guias,
  ) async {
    final SulAmericaBackendService? service = _service;
    if (service == null || guias.isEmpty) return guias;

    final List<GuiaValidada> base = List.of(guias);
    for (int i = 0; i < base.length; i++) {
      final GuiaValidada guia = base[i];
      final String? senha = guia.senha;
      final String? carteira = guia.numeroCarteira;
      final List<ConsultaGuia> errosLocais = [];
      if (senha != null && senha.isNotEmpty && !_senhaValidaParaVpp(senha)) {
        errosLocais.add(ConsultaGuia(
          tipo: TipoConsultaGuia.autorizacaoVpp,
          sucesso: false,
          descricao: '${AppStrings.erroVppSenhaInvalida} ($senha)',
        ),);
      }
      if (carteira != null &&
          carteira.isNotEmpty &&
          !_carteiraValida(carteira)) {
        errosLocais.add(ConsultaGuia(
          tipo: TipoConsultaGuia.elegibilidade,
          sucesso: false,
          descricao: '${AppStrings.erroCarteiraInvalida} ($carteira)',
        ),);
      }
      if (errosLocais.isNotEmpty) {
        base[i] = GuiaValidada(
          guia: guia.guia,
          erros:
              senha != null && senha.isNotEmpty && !_senhaValidaParaVpp(senha)
                  ? guia.erros.where((e) => e.campo != 'senha').toList()
                  : guia.erros,
          consultas: errosLocais,
        );
      }
    }

    final List<ConsultaLoteItem> itens = [];
    final Set<String> chavesVistas = {};
    for (final GuiaValidada guia in base) {
      for (final ConsultaLoteItem item in _itensDeConsulta(guia)) {
        final String chaveUnica = '${item.tipo.name}|${item.chave}';
        if (chavesVistas.add(chaveUnica)) {
          itens.add(item);
        }
      }
    }
    if (itens.isEmpty) return base;

    final (String? token, String? motivoErro) =
        await _obterTokenSessao(service);
    if (token == null) {
      final ConsultaGuia erro = ConsultaGuia(
        sucesso: false,
        descricao: motivoErro ?? AppStrings.erroCredenciaisAusentes,
      );
      return [
        for (final GuiaValidada guia in base) _anexarConsulta(guia, erro),
      ];
    }

    final Result<List<ResultadoConsultaLote>> resultado =
        await service.consultarLote(token: token, consultas: itens);

    final List<GuiaValidada>? comConsultas =
        resultado.fold<List<GuiaValidada>?>(
      onSuccess: (resultados) {
        final Map<String, ConsultaGuia> porChave = {
          for (final ResultadoConsultaLote r in resultados)
            '${r.tipo.name}|${r.chave}': _consultaDesdeBatch(r),
        };
        final List<GuiaValidada> acumulado = List.of(base);
        for (int indice = 0; indice < base.length; indice++) {
          for (final ConsultaLoteItem item in _itensDeConsulta(base[indice])) {
            final ConsultaGuia? consulta =
                porChave['${item.tipo.name}|${item.chave}'];
            if (consulta == null) continue;
            acumulado[indice] = _anexarConsulta(acumulado[indice], consulta);
          }
        }
        return acumulado;
      },
      onFailure: (_) => null,
    );

    if (comConsultas != null) return comConsultas;

    // Fallback: backend sem /api/consultas (deploy antigo) — fluxo
    // individual, com dedupe intra-lote.
    return _consultarGuiasIndividualmente(service, token, base);
  }

  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  List<ConsultaLoteItem> _itensDeConsulta(GuiaValidada guia) {
    final List<ConsultaLoteItem> itens = [];
    final String? carteira = guia.numeroCarteira;
    if (carteira != null && carteira.isNotEmpty && _carteiraValida(carteira)) {
      itens.add(ConsultaLoteItem(
        tipo: TipoConsultaGuia.elegibilidade,
        chave: carteira,
      ),);
    }
    final String? senha = guia.senha;
    if (senha != null && _senhaValidaParaVpp(senha)) {
      itens.add(ConsultaLoteItem(
        tipo: TipoConsultaGuia.autorizacaoVpp,
        chave: senha,
      ),);
    }
    return itens;
  }

  ConsultaGuia _consultaDesdeBatch(ResultadoConsultaLote r) {
    if (!r.sucesso) {
      return ConsultaGuia(
        tipo: r.tipo,
        sucesso: false,
        descricao: r.tipo == TipoConsultaGuia.elegibilidade
            ? 'Consulta de elegibilidade falhou: ${r.erro ?? 'sem detalhe'}'
            : 'Consulta de senha falhou: ${r.erro ?? 'sem detalhe'}',
      );
    }
    if (r.tipo == TipoConsultaGuia.elegibilidade) {
      return _consultaElegibilidade(
        r.elegivel,
        carteira: r.chave,
        sucessoConsulta: r.sucesso,
      );
    }
    return _consultaVpp(r.statusVpp, senha: r.chave);
  }

  /// Erro próprio para elegibilidade: SIM = ok; NÃO = erro; sem indicador =
  /// carteira não encontrada (erro); falha de transporte também é erro.
  /// A carteira é incluída no texto do erro para identificar o que falhou.
  ConsultaGuia _consultaElegibilidade(
    bool? elegivel, {
    required String carteira,
    bool sucessoConsulta = true,
  }) {
    if (!sucessoConsulta) {
      return const ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: false,
        descricao: 'Consulta de elegibilidade falhou',
      );
    }
    return switch (elegivel) {
      true => const ConsultaGuia(
          tipo: TipoConsultaGuia.elegibilidade,
          sucesso: true,
          descricao: 'Elegível: SIM',
        ),
      false => ConsultaGuia(
          tipo: TipoConsultaGuia.elegibilidade,
          sucesso: false,
          descricao: '${AppStrings.erroNaoElegivel} ($carteira)',
        ),
      null => ConsultaGuia(
          tipo: TipoConsultaGuia.elegibilidade,
          sucesso: false,
          descricao: '${AppStrings.erroCarteiraNaoEncontrada} ($carteira)',
        ),
    };
  }

  /// Fluxo individual (uma requisição por consulta) usado quando o backend
  /// ainda não expõe /api/consultas.
  Future<List<GuiaValidada>> _consultarGuiasIndividualmente(
    SulAmericaBackendService service,
    String token,
    List<GuiaValidada> guias,
  ) async {
    _cacheElegibilidade.clear();
    _cacheAutorizacao.clear();
    final List<GuiaValidada> comConsultas = [];
    for (final GuiaValidada guia in guias) {
      GuiaValidada atual = guia;
      for (final ConsultaLoteItem item in _itensDeConsulta(atual)) {
        final ConsultaGuia consulta =
            item.tipo == TipoConsultaGuia.elegibilidade
                ? await _consultarElegibilidadeItem(service, token, item.chave)
                : await _consultarAutorizacaoItem(service, token, item.chave);
        atual = _anexarConsulta(atual, consulta);
      }
      comConsultas.add(atual);
    }
    return comConsultas;
  }

  static bool _senhaValidaParaVpp(String senha) =>
      senha.length == RegraSenhaPrefixo.tamanhoExato &&
      senha.startsWith(RegraSenhaPrefixo.prefixoObrigatorio);

  Future<ConsultaGuia> _consultarElegibilidadeItem(
    SulAmericaBackendService service,
    String token,
    String carteira,
  ) async {
    final ConsultaGuia? naCache = _cacheElegibilidade[carteira];
    if (naCache != null) return naCache;

    final Result<ResultadoConsultaBeneficiario> resultado =
        await service.consultarBeneficiario(token: token, carteira: carteira);

    final ConsultaGuia consulta = resultado.fold<ConsultaGuia>(
      onSuccess: (res) =>
          _consultaElegibilidade(res.elegivel, carteira: carteira),
      onFailure: (erro) => ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: false,
        descricao: 'Consulta de elegibilidade falhou: $erro',
      ),
    );
    _cacheElegibilidade[carteira] = consulta;
    return consulta;
  }

  Future<ConsultaGuia> _consultarAutorizacaoItem(
    SulAmericaBackendService service,
    String token,
    String senha,
  ) async {
    final ConsultaGuia? naCache = _cacheAutorizacao[senha];
    if (naCache != null) return naCache;

    final Result<Map<String, dynamic>> resultado =
        await service.autorizacaoVpp(token: token, numeroVpp: senha);

    final ConsultaGuia consulta = resultado.fold<ConsultaGuia>(
      onSuccess: (dados) =>
          _consultaVpp(dados['descricao'] as String?, senha: senha),
      onFailure: (erro) => ConsultaGuia(
        tipo: TipoConsultaGuia.autorizacaoVpp,
        sucesso: false,
        descricao: 'Consulta de senha falhou: $erro',
      ),
    );
    _cacheAutorizacao[senha] = consulta;
    return consulta;
  }

  /// Retorna (token, motivoDeErro): token nulo com motivo quando a sessão
  /// não pôde ser obtida (credenciais ausentes ou login rejeitado).
  Future<(String?, String?)> _obterTokenSessao(
    SulAmericaBackendService service,
  ) async {
    final String? tokenAtual = _tokenSessao;
    if (tokenAtual != null) return (tokenAtual, null);
    final String? code = _codigoPrestador;
    final String? user = _usuarioPrestador;
    final String? senha = _senhaPrestador;
    if (code == null ||
        code.isEmpty ||
        user == null ||
        user.isEmpty ||
        senha == null ||
        senha.isEmpty) {
      return (null, AppStrings.erroCredenciaisAusentes);
    }

    final Result<String> resultado = await service.login(
      code: code,
      user: user,
      senha: senha,
    );
    return resultado.fold<(String?, String?)>(
      onSuccess: (token) {
        _tokenSessao = token;
        return (token, null);
      },
      onFailure: (_) => (null, AppStrings.erroLoginFalhou),
    );
  }

  /// Monta o resultado da autorização (senha) a partir da descrição do status
  /// do portal. Autorizada quando a descrição CONTÉM "autorizado". Senha com
  /// formato válido mas SEM status no portal = "Senha não encontrada no
  /// portal" — diferente de formato inválido (Senha inválida), tratado na
  /// pré-validação.
  ConsultaGuia _consultaVpp(String? descricao, {required String senha}) {
    final bool autorizada = _descricaoAutorizada(descricao);
    return ConsultaGuia(
      tipo: TipoConsultaGuia.autorizacaoVpp,
      sucesso: autorizada,
      descricao: autorizada
          ? 'Senha: ok'
          : descricao == null
              ? '${AppStrings.erroSenhaNaoEncontrada} ($senha)'
              : 'Senha: $descricao ($senha)',
    );
  }

  static bool _descricaoAutorizada(String? descricao) =>
      descricao != null && descricao.toLowerCase().contains('autorizado');

  GuiaValidada _anexarConsulta(GuiaValidada guia, ConsultaGuia consulta) =>
      GuiaValidada(
        guia: guia.guia,
        erros: guia.erros,
        consultas: [...guia.consultas, consulta],
      );

  String _decodificarXml(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  List<GuiaValidada> _ordenarPorNumeroGuia(List<GuiaValidada> lista) {
    final List<MapEntry<int, GuiaValidada>> indexado = List.generate(
      lista.length,
      (indice) => MapEntry(indice, lista[indice]),
    );
    indexado.sort((a, b) {
      final int comparacaoGuia =
          a.value.numeroGuiaPrestador.compareTo(b.value.numeroGuiaPrestador);
      return comparacaoGuia != 0 ? comparacaoGuia : a.key.compareTo(b.key);
    });
    return indexado.map((entrada) => entrada.value).toList();
  }
}
