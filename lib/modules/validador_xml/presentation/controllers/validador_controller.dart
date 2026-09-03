import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../data/datasources/xml_lote_guias_exceptions.dart';
import '../../data/models/guia_validada.dart';
import '../../data/repositories/validador_guias_repository.dart';
import '../../data/repositories/validador_guias_repository_impl.dart';

enum StatusValidador { semArquivo, arquivoPronto, validando, concluido, erro }

/// Controller de apresentação para a tela de validação de guias.
/// Não conhece Widgets: apenas estado e fluxo, delegando a regra de
/// negócio para o [ValidadorGuiasRepository].
class ValidadorController extends ChangeNotifier {
  ValidadorController({ValidadorGuiasRepository? repository})
      : _repository = repository ?? ValidadorGuiasRepositoryImpl();

  final ValidadorGuiasRepository _repository;

  StatusValidador _status = StatusValidador.semArquivo;
  String? _nomeArquivo;
  Uint8List? _bytesArquivo;
  List<GuiaValidada> _resultado = const [];
  String? _mensagemErro;
  bool _somenteErros = false;

  StatusValidador get status => _status;
  String? get nomeArquivo => _nomeArquivo;
  String? get mensagemErro => _mensagemErro;
  bool get somenteErros => _somenteErros;

  List<GuiaValidada> get resultadoFiltrado => _somenteErros
      ? _resultado.where((guiaValidada) => guiaValidada.temErro).toList()
      : _resultado;

  int get totalGuias => _resultado.length;
  int get totalGuiasComErro =>
      _resultado.where((guiaValidada) => guiaValidada.temErro).length;

  void definirArquivo({
    required String nomeArquivo,
    required Uint8List bytes,
  }) {
    _nomeArquivo = nomeArquivo;
    _bytesArquivo = bytes;
    _status = StatusValidador.arquivoPronto;
    _mensagemErro = null;
    _resultado = const [];
    notifyListeners();
  }

  void alternarSomenteErros(bool valor) {
    _somenteErros = valor;
    notifyListeners();
  }

  Future<void> validar() async {
    final Uint8List? bytes = _bytesArquivo;
    if (bytes == null) return;

    _status = StatusValidador.validando;
    _mensagemErro = null;
    notifyListeners();

    try {
      final String conteudoXml = _decodificarXml(bytes);
      final List<GuiaValidada> resultadoBruto =
          await Future(() => _repository.validarLote(conteudoXml));

      // Guias com o mesmo numeroGuiaPrestador ficam sequenciais, sem
      // embaralhar a ordem relativa das demais (ordenação estável).
      _resultado = _ordenarPorNumeroGuia(resultadoBruto);
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
    }

    notifyListeners();
  }

  void reiniciar() {
    _status = StatusValidador.semArquivo;
    _nomeArquivo = null;
    _bytesArquivo = null;
    _resultado = const [];
    _mensagemErro = null;
    notifyListeners();
  }

  /// TISS costuma declarar ISO-8859-1. Tenta UTF-8 primeiro (caso comum de
  /// conteúdo apenas ASCII) e cai para Latin-1 quando houver acentuação
  /// fora da faixa UTF-8 válida.
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
