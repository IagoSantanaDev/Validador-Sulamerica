import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../globals/constants/app_strings.dart';
import '../../../../globals/network/app_exception.dart';
import '../../../../globals/network/result.dart';
import '../../data/datasources/xml_lote_guias_datasource.dart';
import '../../data/datasources/xml_lote_guias_exceptions.dart';
import '../../data/datasources/tuss_base_local_exceptions.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/consulta_lote.dart';
import '../../data/models/guia_validada.dart';
import '../../data/models/informacoes_lote.dart';
import '../../data/models/lote_guias_extraido.dart';
import '../../data/repositories/regras/regra_credenciais_portal.dart';
import '../../data/repositories/regras/regra_senha_prefixo.dart';
import '../../data/repositories/validador_guias_repository.dart';
import '../../data/repositories/validador_guias_repository_impl.dart';
import '../../data/services/sul_america_backend_service.dart';
import '../../data/services/classificador_tuss_local.dart';

enum StatusValidador { semArquivo, arquivoPronto, validando, concluido, erro }

enum EstadoConexao { verificando, apiIndisponivel, pronto }

enum EtapaConsultaBackend {
  naoIniciada,
  consultando,
  aguardandoRetentativa,
  pendente,
  concluida,
}

class ValidadorController extends ChangeNotifier {
  static const int _maxConsultasPorLote = 300;
  static const List<Duration> _intervalosRetentativa = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  ValidadorController({
    ValidadorGuiasRepository? repository,
    SulAmericaBackendService? service,
    RegraCredenciaisPortal? regraCredenciais,
    Future<void> Function(Duration)? aguardarRetentativa,
  }) : _repository =
           repository ??
           ValidadorGuiasRepositoryImpl(
             classificadorTuss: ClassificadorTussLocal(),
           ),
       _service = service ?? _servicePadrao(),
       _regraCredenciais = regraCredenciais ?? const RegraCredenciaisPortal(),
       _aguardarRetentativa =
           aguardarRetentativa ??
           ((Duration duracao) => Future<void>.delayed(duracao));

  final ValidadorGuiasRepository _repository;
  final XmlLoteGuiasDatasource _datasource = const XmlLoteGuiasDatasource();
  final SulAmericaBackendService? _service;
  final RegraCredenciaisPortal _regraCredenciais;
  final Future<void> Function(Duration) _aguardarRetentativa;

  String? _tokenSessao;

  String? _identificadorPrestadorDoToken;
  EtapaConsultaBackend _etapaConsultaBackend = EtapaConsultaBackend.naoIniciada;
  final Map<String, ConsultaLoteItem> _consultasPendentes = {};
  final Map<String, ConsultaGuia> _resultadosConsultas = {};
  List<GuiaValidada> _guiasBaseConsultas = const [];
  bool _retentativaManualEmAndamento = false;
  String? _identificadorPrestadorDaConsulta;
  String? _mensagemAvisoConsultaBackend;

  EtapaConsultaBackend get etapaConsultaBackend => _etapaConsultaBackend;
  int get totalConsultasPendentes => _consultasPendentes.length;
  bool get temConsultasPendentes => _consultasPendentes.isNotEmpty;
  String? get mensagemAvisoConsultaBackend => _mensagemAvisoConsultaBackend;

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
    _estadoConexao = status is Success<Map<String, dynamic>>
        ? EstadoConexao.pronto
        : EstadoConexao.apiIndisponivel;
    notifyListeners();
  }

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

  void definirArquivo({required String nomeArquivo, required Uint8List bytes}) {
    _nomeArquivo = nomeArquivo;
    _bytesArquivo = bytes;
    _status = StatusValidador.arquivoPronto;
    _mensagemErro = null;
    _resultado = const [];
    _limparEstadoConsultas();
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = md5.convert(bytes).toString();
    notifyListeners();
  }

  Future<void> validar() async {
    final Uint8List? bytes = _bytesArquivo;
    if (bytes == null) return;

    _status = StatusValidador.validando;
    _mensagemErro = null;
    _limparEstadoConsultas();
    notifyListeners();

    final Stopwatch cronometro = Stopwatch()..start();
    try {
      final String conteudoXml = _decodificarXml(bytes);
      await _repository.preparar();
      final LoteGuiasExtraido lote = _datasource.extrairLote(conteudoXml);
      final InformacoesLote informacoes = lote.informacoes;
      final List<GuiaValidada> resultadoBruto = await Future(
        () => _repository.validarGuias(lote.guias),
      );
      final String? identificadorPrestador = _regraCredenciais.resolver(
        informacoes.prestadorCnpjCpf,
      );
      final List<GuiaValidada> comConsultas = await _consultarGuias(
        resultadoBruto,
        identificadorPrestador,
      );

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
    } on TussBaseLocalInvalidaException catch (erro) {
      _resultado = const [];
      _status = StatusValidador.erro;
      _mensagemErro = 'Não foi possível carregar a base TUSS: ${erro.mensagem}';
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
    _limparEstadoConsultas();
    _mensagemErro = null;
    _informacoes = InformacoesLote.vazio;
    _hashMd5 = null;
    _tempoProcessamento = Duration.zero;
    notifyListeners();
  }

  Future<List<GuiaValidada>> _consultarGuias(
    List<GuiaValidada> guias,
    String? identificadorPrestador,
  ) async {
    final SulAmericaBackendService? service = _service;
    _limparEstadoConsultas();
    _guiasBaseConsultas = List.of(guias);
    _identificadorPrestadorDaConsulta = identificadorPrestador;
    if (service == null || guias.isEmpty) {
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return guias;
    }

    final List<GuiaValidada> base = List.of(guias);
    for (int i = 0; i < base.length; i++) {
      final GuiaValidada guia = base[i];
      final String? senha = guia.senha;
      final String? carteira = guia.numeroCarteira;
      final List<ConsultaGuia> errosLocais = [];
      if (senha != null && senha.isNotEmpty && !_senhaValida(senha)) {
        errosLocais.add(
          ConsultaGuia(
            tipo: TipoConsultaGuia.senha,
            sucesso: false,
            descricao: '${AppStrings.erroSenhaInvalida} ($senha)',
          ),
        );
      }
      if (carteira != null &&
          carteira.isNotEmpty &&
          !_carteiraValida(carteira)) {
        errosLocais.add(
          ConsultaGuia(
            tipo: TipoConsultaGuia.elegibilidade,
            sucesso: false,
            descricao: '${AppStrings.erroCarteiraInvalida} ($carteira)',
          ),
        );
      }
      if (errosLocais.isNotEmpty) {
        base[i] = GuiaValidada(
          guia: guia.guia,
          erros: senha != null && senha.isNotEmpty && !_senhaValida(senha)
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
    _guiasBaseConsultas = base;
    if (itens.isEmpty) {
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return base;
    }

    String? token;
    String? motivoErro;
    AppException? falhaLogin;
    for (
      int tentativa = 0;
      tentativa <= _intervalosRetentativa.length;
      tentativa++
    ) {
      if (tentativa > 0) {
        _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
        notifyListeners();
        await _aguardarRetentativa(_intervalosRetentativa[tentativa - 1]);
      }
      _etapaConsultaBackend = EtapaConsultaBackend.consultando;
      notifyListeners();
      final respostaLogin = await _obterTokenSessao(
        service,
        identificadorPrestador,
      );
      token = respostaLogin.token;
      motivoErro = respostaLogin.mensagemErro;
      falhaLogin = respostaLogin.falha;
      if (token != null ||
          falhaLogin == null ||
          !_falhaTransitoria(falhaLogin) ||
          tentativa == _intervalosRetentativa.length) {
        break;
      }
    }
    if (token == null) {
      if (falhaLogin != null && _falhaTransitoria(falhaLogin)) {
        _registrarConsultasPendentes(itens);
        _etapaConsultaBackend = EtapaConsultaBackend.pendente;
        notifyListeners();
        return _aplicarResultadosConsultas(base);
      }
      if (falhaLogin is NaoAutorizadoException) {
        _avisarFalhaAutenticacao();
        return base;
      }
      final ConsultaGuia erro = ConsultaGuia(
        sucesso: false,
        descricao: motivoErro ?? AppStrings.erroCredenciaisAusentes,
      );
      for (final ConsultaLoteItem item in itens) {
        _resultadosConsultas[_chaveConsulta(item)] = ConsultaGuia(
          tipo: item.tipo,
          sucesso: false,
          descricao: erro.descricao,
        );
      }
      _etapaConsultaBackend = EtapaConsultaBackend.concluida;
      return _aplicarResultadosConsultas(base);
    }

    bool repetiuAposLogin = false;
    String tokenAtual = token;
    String? erroParada;

    for (
      int inicio = 0;
      inicio < itens.length;
      inicio += _maxConsultasPorLote
    ) {
      final int limite = inicio + _maxConsultasPorLote;
      final int fim = limite < itens.length ? limite : itens.length;
      final List<ConsultaLoteItem> lote = itens.sublist(inicio, fim);
      if (erroParada != null) {
        if (_mensagemAvisoConsultaBackend == null) {
          _registrarFalhaDoLote(lote, erroParada);
        }
        continue;
      }
      List<ConsultaLoteItem> naoResolvidas = List.of(lote);
      bool precisaNovoLogin = false;
      for (
        int tentativa = 0;
        tentativa <= _intervalosRetentativa.length && naoResolvidas.isNotEmpty;
        tentativa++
      ) {
        if (tentativa > 0) {
          _etapaConsultaBackend = EtapaConsultaBackend.aguardandoRetentativa;
          notifyListeners();
          await _aguardarRetentativa(_intervalosRetentativa[tentativa - 1]);
        }
        _etapaConsultaBackend = EtapaConsultaBackend.consultando;
        notifyListeners();
        if (precisaNovoLogin) {
          final login = await _obterTokenSessao(
            service,
            identificadorPrestador,
          );
          if (login.token == null) {
            if (login.falha != null &&
                _falhaTransitoria(login.falha!) &&
                tentativa < _intervalosRetentativa.length) {
              continue;
            }
            if (login.falha != null && _falhaTransitoria(login.falha!)) {
              _registrarConsultasPendentes(naoResolvidas);
            } else if (login.falha is NaoAutorizadoException) {
              _avisarFalhaAutenticacao();
              erroParada = login.mensagemErro ?? AppStrings.erroLoginFalhou;
            } else {
              final String mensagem =
                  login.mensagemErro ?? AppStrings.erroLoginFalhou;
              _registrarFalhaDoLote(naoResolvidas, mensagem);
              erroParada = mensagem;
            }
            naoResolvidas = [];
            break;
          }
          tokenAtual = login.token!;
          repetiuAposLogin = true;
          precisaNovoLogin = false;
        }
        final resposta = await _consultarLoteComAtualizacaoToken(
          service,
          tokenAtual,
          naoResolvidas,
          identificadorPrestador,
          repetiuAposLogin,
        );
        tokenAtual = resposta.token;
        repetiuAposLogin = resposta.repetiuAposLogin;

        final String? erroLogin = resposta.erroLogin;
        if (erroLogin != null) {
          if (resposta.falhaLogin != null &&
              _falhaTransitoria(resposta.falhaLogin!)) {
            precisaNovoLogin = true;
            if (tentativa == _intervalosRetentativa.length) {
              _registrarConsultasPendentes(naoResolvidas);
              naoResolvidas = [];
            }
          } else {
            if (resposta.falhaLogin is NaoAutorizadoException) {
              _avisarFalhaAutenticacao();
              erroParada = erroLogin;
            } else {
              erroParada = erroLogin;
              _registrarFalhaDoLote(naoResolvidas, erroLogin);
            }
            naoResolvidas = [];
          }
          continue;
        }

        final Result<List<ResultadoConsultaLote>> resultado =
            resposta.resultado!;
        final AppException? erroResultado = resultado.fold<AppException?>(
          onSuccess: (_) => null,
          onFailure: (erro) => erro,
        );
        if (erroResultado != null) {
          if (_falhaTransitoria(erroResultado) &&
              tentativa < _intervalosRetentativa.length) {
            continue;
          }
          if (_falhaTransitoria(erroResultado)) {
            _registrarConsultasPendentes(naoResolvidas);
          } else if (erroResultado is NaoAutorizadoException) {
            _tokenSessao = null;
            _identificadorPrestadorDoToken = null;
            _avisarFalhaAutenticacao();
            erroParada = 'Consulta em lote falhou: $erroResultado';
          } else {
            final String mensagem = 'Consulta em lote falhou: $erroResultado';
            _registrarFalhaDoLote(naoResolvidas, mensagem);
          }
          naoResolvidas = [];
          continue;
        }

        final List<ResultadoConsultaLote> resultados = resultado
            .fold<List<ResultadoConsultaLote>>(
              onSuccess: (itensResultado) => itensResultado,
              onFailure: (_) => const [],
            );
        final Set<String> resolvidas = {};
        for (final ResultadoConsultaLote item in resultados) {
          final String chave = '${item.tipo.name}|${item.chave}';
          if (naoResolvidas.any(
            (consulta) => _chaveConsulta(consulta) == chave,
          )) {
            if (_falhaTransitoriaNoResultado(item)) continue;
            _resultadosConsultas[chave] = _consultaDesdeBatch(item);
            resolvidas.add(chave);
          }
        }
        naoResolvidas = naoResolvidas
            .where((item) => !resolvidas.contains(_chaveConsulta(item)))
            .toList();
        if (tentativa == _intervalosRetentativa.length) {
          _registrarConsultasPendentes(naoResolvidas);
        }
      }
    }

    _etapaConsultaBackend = _consultasPendentes.isEmpty
        ? EtapaConsultaBackend.concluida
        : EtapaConsultaBackend.pendente;
    notifyListeners();
    return _aplicarResultadosConsultas(base);
  }

  void _registrarFalhaDoLote(List<ConsultaLoteItem> itens, String mensagem) {
    for (final ConsultaLoteItem item in itens) {
      _resultadosConsultas[_chaveConsulta(item)] = ConsultaGuia(
        tipo: item.tipo,
        sucesso: false,
        descricao: mensagem,
      );
    }
  }

  void _avisarFalhaAutenticacao() {
    _mensagemAvisoConsultaBackend = AppStrings.erroLoginFalhou;
    _consultasPendentes.clear();
    _etapaConsultaBackend = EtapaConsultaBackend.concluida;
  }

  void _registrarConsultasPendentes(Iterable<ConsultaLoteItem> itens) =>
      itens.forEach((item) => _consultasPendentes[_chaveConsulta(item)] = item);

  Future<
    ({
      Result<List<ResultadoConsultaLote>>? resultado,
      String token,
      bool repetiuAposLogin,
      String? erroLogin,
      AppException? falhaLogin,
    })
  >
  _consultarLoteComAtualizacaoToken(
    SulAmericaBackendService service,
    String token,
    List<ConsultaLoteItem> consultas,
    String? identificadorPrestador,
    bool repetiuAposLogin,
  ) async {
    Result<List<ResultadoConsultaLote>> resultado = await service.consultarLote(
      token: token,
      consultas: consultas,
    );
    final AppException? erro = resultado.fold<AppException?>(
      onSuccess: (_) => null,
      onFailure: (falha) => falha,
    );
    if (erro is! NaoAutorizadoException || repetiuAposLogin) {
      return (
        resultado: resultado,
        token: token,
        repetiuAposLogin: repetiuAposLogin,
        erroLogin: null,
        falhaLogin: null,
      );
    }

    _tokenSessao = null;
    _identificadorPrestadorDoToken = null;
    final respostaLogin = await _obterTokenSessao(
      service,
      identificadorPrestador,
    );
    final String? novoToken = respostaLogin.token;
    final String? erroLogin = respostaLogin.mensagemErro;
    if (novoToken == null) {
      return (
        resultado: null,
        token: token,
        repetiuAposLogin: true,
        erroLogin: erroLogin ?? AppStrings.erroLoginFalhou,
        falhaLogin: respostaLogin.falha,
      );
    }
    resultado = await service.consultarLote(
      token: novoToken,
      consultas: consultas,
    );
    return (
      resultado: resultado,
      token: novoToken,
      repetiuAposLogin: true,
      erroLogin: null,
      falhaLogin: null,
    );
  }

  bool _falhaTransitoria(AppException erro) =>
      erro is SemConexaoException ||
      erro is RequisicaoExpiradaException ||
      (erro is ErroServidorException &&
          (erro.statusCode == 408 ||
              erro.statusCode == 429 ||
              (erro.statusCode ?? 0) >= 500));

  bool _falhaTransitoriaNoResultado(ResultadoConsultaLote resultado) =>
      !resultado.sucesso &&
      resultado.erro?.trim() == 'Falha na consulta ao portal SulAmerica.';

  String _chaveConsulta(ConsultaLoteItem item) =>
      '${item.tipo.name}|${item.chave}';

  List<GuiaValidada> _aplicarResultadosConsultas(List<GuiaValidada> base) {
    final List<GuiaValidada> resultado = [];
    for (final GuiaValidada guia in base) {
      GuiaValidada atualizada = guia;
      for (final ConsultaLoteItem item in _itensDeConsulta(guia)) {
        final ConsultaGuia? consulta =
            _resultadosConsultas[_chaveConsulta(item)];
        if (consulta != null) {
          atualizada = _anexarConsulta(atualizada, consulta);
        }
      }
      resultado.add(atualizada);
    }
    return resultado;
  }

  void _limparEstadoConsultas() {
    _consultasPendentes.clear();
    _resultadosConsultas.clear();
    _guiasBaseConsultas = const [];
    _identificadorPrestadorDaConsulta = null;
    _mensagemAvisoConsultaBackend = null;
    _etapaConsultaBackend = EtapaConsultaBackend.naoIniciada;
    _retentativaManualEmAndamento = false;
  }

  Future<void> retentarConsultasPendentes() async {
    final SulAmericaBackendService? service = _service;
    if (service == null ||
        _consultasPendentes.isEmpty ||
        _retentativaManualEmAndamento) {
      return;
    }
    _retentativaManualEmAndamento = true;
    _etapaConsultaBackend = EtapaConsultaBackend.consultando;
    notifyListeners();
    final List<ConsultaLoteItem> consultas = _consultasPendentes.values
        .take(_maxConsultasPorLote)
        .toList();
    try {
      final respostaLogin = await _obterTokenSessao(
        service,
        _identificadorPrestadorDaConsulta,
      );
      final String? token = respostaLogin.token;
      final String? erroLogin = respostaLogin.mensagemErro;
      if (token == null) {
        if (respostaLogin.falha is NaoAutorizadoException) {
          _avisarFalhaAutenticacao();
        } else if (respostaLogin.falha == null ||
            !_falhaTransitoria(respostaLogin.falha!)) {
          _registrarFalhaDoLote(
            consultas,
            erroLogin ?? AppStrings.erroLoginFalhou,
          );
          for (final ConsultaLoteItem item in consultas) {
            _consultasPendentes.remove(_chaveConsulta(item));
          }
        }
      } else {
        final resposta = await _consultarLoteComAtualizacaoToken(
          service,
          token,
          consultas,
          _identificadorPrestadorDaConsulta,
          false,
        );
        final String? erroLoginRetentativa = resposta.erroLogin;
        if (erroLoginRetentativa != null) {
          if (resposta.falhaLogin is NaoAutorizadoException) {
            _avisarFalhaAutenticacao();
          } else if (resposta.falhaLogin == null ||
              !_falhaTransitoria(resposta.falhaLogin!)) {
            _registrarFalhaDoLote(consultas, erroLoginRetentativa);
            for (final ConsultaLoteItem item in consultas) {
              _consultasPendentes.remove(_chaveConsulta(item));
            }
          }
        } else {
          final Result<List<ResultadoConsultaLote>> resultado =
              resposta.resultado!;
          final AppException? erro = resultado.fold<AppException?>(
            onSuccess: (_) => null,
            onFailure: (falha) => falha,
          );
          if (erro != null && !_falhaTransitoria(erro)) {
            if (erro is NaoAutorizadoException) {
              _tokenSessao = null;
              _identificadorPrestadorDoToken = null;
              _avisarFalhaAutenticacao();
            } else {
              _registrarFalhaDoLote(
                consultas,
                'Consulta em lote falhou: $erro',
              );
              for (final ConsultaLoteItem item in consultas) {
                _consultasPendentes.remove(_chaveConsulta(item));
              }
            }
          } else if (erro == null) {
            final Set<String> resolvidas = {};
            for (final ResultadoConsultaLote item in resultado.fold(
              onSuccess: (itensResultado) => itensResultado,
              onFailure: (_) => const [],
            )) {
              final String chave = '${item.tipo.name}|${item.chave}';
              if (_consultasPendentes.containsKey(chave)) {
                if (_falhaTransitoriaNoResultado(item)) continue;
                _resultadosConsultas[chave] = _consultaDesdeBatch(item);
                resolvidas.add(chave);
              }
            }
            for (final String chave in resolvidas) {
              _consultasPendentes.remove(chave);
            }
          }
        }
      }
      _resultado = _ordenarPorNumeroGuia(
        _aplicarResultadosConsultas(_guiasBaseConsultas),
      );
      _etapaConsultaBackend = _consultasPendentes.isEmpty
          ? EtapaConsultaBackend.concluida
          : EtapaConsultaBackend.pendente;
    } finally {
      _retentativaManualEmAndamento = false;
      notifyListeners();
    }
  }

  static bool _carteiraValida(String carteira) =>
      carteira.length == 20 && RegExp(r'^\d+$').hasMatch(carteira);

  static bool _senhaValida(String senha) =>
      RegraSenhaPrefixo.senhaValida(senha);

  List<ConsultaLoteItem> _itensDeConsulta(GuiaValidada guia) {
    final List<ConsultaLoteItem> itens = [];
    final String? carteira = guia.numeroCarteira;
    if (carteira != null && carteira.isNotEmpty && _carteiraValida(carteira)) {
      itens.add(
        ConsultaLoteItem(tipo: TipoConsultaGuia.elegibilidade, chave: carteira),
      );
    }
    final String? senha = guia.senha;
    if (senha != null && _senhaValida(senha)) {
      itens.add(ConsultaLoteItem(tipo: TipoConsultaGuia.senha, chave: senha));
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
    return _consultaSenha(r.statusSenha, senha: r.chave);
  }

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

  ConsultaGuia _consultaSenha(String? descricao, {required String senha}) {
    final bool autorizada = _descricaoAutorizada(descricao);
    return ConsultaGuia(
      tipo: TipoConsultaGuia.senha,
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

  Future<({String? token, String? mensagemErro, AppException? falha})>
  _obterTokenSessao(
    SulAmericaBackendService service,
    String? identificadorPrestador,
  ) async {
    if (identificadorPrestador == null) {
      return (
        token: null,
        mensagemErro: AppStrings.erroCredenciaisAusentes,
        falha: null,
      );
    }

    final String? tokenAtual = _tokenSessao;
    if (tokenAtual != null &&
        _identificadorPrestadorDoToken == identificadorPrestador) {
      return (token: tokenAtual, mensagemErro: null, falha: null);
    }

    final Result<String> resultado = await service.login(
      identificadorPrestador: identificadorPrestador,
    );
    return resultado
        .fold<({String? token, String? mensagemErro, AppException? falha})>(
          onSuccess: (token) {
            _tokenSessao = token;
            _identificadorPrestadorDoToken = identificadorPrestador;
            return (token: token, mensagemErro: null, falha: null);
          },
          onFailure: (falha) => (
            token: null,
            mensagemErro: AppStrings.erroLoginFalhou,
            falha: falha,
          ),
        );
  }

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
      final int comparacaoGuia = a.value.numeroGuiaPrestador.compareTo(
        b.value.numeroGuiaPrestador,
      );
      return comparacaoGuia != 0 ? comparacaoGuia : a.key.compareTo(b.key);
    });
    return indexado.map((entrada) => entrada.value).toList();
  }
}
