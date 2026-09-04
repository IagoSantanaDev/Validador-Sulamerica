import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../globals/constants/app_config.dart';
import '../../../../globals/network/result.dart';
import '../../data/datasources/xml_lote_guias_datasource.dart';
import '../../data/datasources/xml_lote_guias_exceptions.dart';
import '../../data/models/consulta_guia.dart';
import '../../data/models/guia_validada.dart';
import '../../data/models/informacoes_lote.dart';
import '../../data/models/resultado_consulta_beneficiario.dart';
import '../../data/repositories/validador_guias_repository.dart';
import '../../data/repositories/validador_guias_repository_impl.dart';
import '../../data/services/sul_america_backend_service.dart';

enum StatusValidador { semArquivo, arquivoPronto, validando, concluido, erro }

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
      _resultado.where((guia) => guia.temErro).toList();

  /// Todas as guias validadas (com ou sem erro), já ordenadas.
  List<GuiaValidada> get guias => _resultado;

  int get totalGuias => _resultado.length;
  int get totalGuiasComErro =>
      _resultado.where((guia) => guia.temErro).length;

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

  /// Para cada guia do lote, consulta o portal via backend intermediário:
  /// sem senha → elegibilidade (consulta do beneficiário); senha iniciada em
  /// 5 com 10 caracteres → autorização VPP. Sem credenciais configuradas,
  /// a validação permanece apenas local.
  Future<List<GuiaValidada>> _consultarGuias(
    List<GuiaValidada> guias,
  ) async {
    final SulAmericaBackendService? service = _service;
    if (service == null || guias.isEmpty) return guias;

    // Escopo de dedupe: apenas a validação atual. A próxima validação sempre
    // consulta o portal novamente (dados novos).
    _cacheElegibilidade.clear();
    _cacheAutorizacao.clear();

    final String? token = await _obterTokenSessao(service);
    if (token == null) return guias;

    final List<GuiaValidada> comConsultas = [];
    for (final GuiaValidada guia in guias) {
      comConsultas.add(await _consultarGuia(service, token, guia));
    }
    return comConsultas;
  }

  Future<String?> _obterTokenSessao(SulAmericaBackendService service) async {
    if (_tokenSessao != null) return _tokenSessao;
    final String? code = _codigoPrestador;
    final String? user = _usuarioPrestador;
    final String? senha = _senhaPrestador;
    if (code == null ||
        code.isEmpty ||
        user == null ||
        user.isEmpty ||
        senha == null ||
        senha.isEmpty) {
      return null;
    }

    final Result<String> resultado = await service.login(
      code: code,
      user: user,
      senha: senha,
    );
    return resultado.fold<String?>(
      onSuccess: (token) {
        _tokenSessao = token;
        return token;
      },
      onFailure: (_) => null,
    );
  }

  Future<GuiaValidada> _consultarGuia(
    SulAmericaBackendService service,
    String token,
    GuiaValidada guia,
  ) async {
    final String? senha = guia.senha;
    if (senha == null || senha.isEmpty) {
      return _consultarElegibilidade(service, token, guia);
    }
    if (_senhaValidaParaVpp(senha)) {
      return _consultarAutorizacaoVpp(service, token, guia);
    }
    return guia;
  }

  static bool _senhaValidaParaVpp(String senha) =>
      senha.length == 10 && senha.startsWith('5');

  Future<GuiaValidada> _consultarElegibilidade(
    SulAmericaBackendService service,
    String token,
    GuiaValidada guia,
  ) async {
    final String? carteira = guia.numeroCarteira;
    if (carteira == null || carteira.isEmpty) return guia;

    final ConsultaGuia? naCache = _cacheElegibilidade[carteira];
    if (naCache != null) {
      return _anexarConsulta(guia, naCache);
    }

    final Result<ResultadoConsultaBeneficiario> resultado =
        await service.consultarBeneficiario(token: token, carteira: carteira);

    final ConsultaGuia consulta = resultado.fold<ConsultaGuia>(
      onSuccess: (res) => ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: true,
        descricao: switch (res.elegivel) {
          true => 'Elegível: SIM',
          false => 'Elegível: NÃO',
          null => 'Carteira não encontrada',
        },
      ),
      onFailure: (erro) => ConsultaGuia(
        tipo: TipoConsultaGuia.elegibilidade,
        sucesso: false,
        descricao: 'Consulta de elegibilidade falhou: $erro',
      ),
    );
    _cacheElegibilidade[carteira] = consulta;
    return _anexarConsulta(guia, consulta);
  }

  Future<GuiaValidada> _consultarAutorizacaoVpp(
    SulAmericaBackendService service,
    String token,
    GuiaValidada guia,
  ) async {
    final String senha = guia.senha!;

    final ConsultaGuia? naCache = _cacheAutorizacao[senha];
    if (naCache != null) {
      return _anexarConsulta(guia, naCache);
    }

    final Result<Map<String, dynamic>> resultado =
        await service.autorizacaoVpp(token: token, numeroVpp: senha);

    final ConsultaGuia consulta = resultado.fold<ConsultaGuia>(
      onSuccess: (dados) {
        final String status = _statusAutorizacaoVpp(dados);
        final bool autorizada = status.toLowerCase().startsWith('autorizad');
        return ConsultaGuia(
          tipo: TipoConsultaGuia.autorizacaoVpp,
          sucesso: autorizada,
          descricao: autorizada
              ? 'Autorização VPP: ok'
              : 'Autorização VPP: $status',
        );
      },
      onFailure: (erro) => ConsultaGuia(
        tipo: TipoConsultaGuia.autorizacaoVpp,
        sucesso: false,
        descricao: 'Consulta de autorização VPP falhou: $erro',
      ),
    );
    _cacheAutorizacao[senha] = consulta;
    return _anexarConsulta(guia, consulta);
  }

  /// Extrai a descrição do status da autorização VPP retornada pelo portal
  /// (ex.: "Autorizado", "Negado", "Em análise"). Considera autorizada
  /// apenas quando há registro com descrição começando em "autorizad".
  String _statusAutorizacaoVpp(Map<String, dynamic> dados) {
    final dynamic registros = dados['registros'];
    if (registros is! List || registros.isEmpty) {
      return 'nenhuma solicitação encontrada';
    }
    for (final dynamic registro in registros) {
      final dynamic status = registro is Map
          ? registro['status_solicitacao']
          : null;
      final dynamic descricao =
          status is Map ? status['descricao'] : null;
      if (descricao is String && descricao.isNotEmpty) return descricao;
    }
    return 'sem status informado';
  }

  GuiaValidada _anexarConsulta(GuiaValidada guia, ConsultaGuia consulta) =>
      GuiaValidada(guia: guia.guia, erros: guia.erros, consulta: consulta);

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