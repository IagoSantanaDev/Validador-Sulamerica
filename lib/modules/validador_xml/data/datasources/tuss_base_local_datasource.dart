import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tuss_item.dart';
import 'tuss_base_local_exceptions.dart';

/// Indexa os datasets compactos de `assets/tuss` num único mapa `id -> item`,
/// para que a tabela real de um código seja comparável com a declarada no XML.
class TussBaseLocalDatasource {
  TussBaseLocalDatasource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const String pasta = 'assets/tuss';
  static const String caminhoManifesto = '$pasta/manifest.json';

  final AssetBundle _bundle;
  final Map<String, TussItem> _porCodigo = {};
  final Map<String, String> _snapshots = {};
  final Set<String> _tabelas = {};
  final Set<String> _tabelasComBase = {};

  Future<void>? _carregamento;
  bool _carregada = false;

  bool get carregada => _carregada;

  Set<String> get tabelas => Set.unmodifiable(_tabelas);

  Set<String> get tabelasComBase => Set.unmodifiable(_tabelasComBase);

  bool temBaseLocal(String tabela) => _tabelasComBase.contains(tabela);

  String? snapshotDaTabela(String tabela) => _snapshots[tabela];

  TussItem? buscar(String codigo) => _porCodigo[codigo];

  Future<void> carregar() => _carregamento ??= _carregarLimpandoFalha();

  Future<void> _carregarLimpandoFalha() async {
    try {
      await _carregar();
    } catch (_) {
      _carregamento = null;
      rethrow;
    }
  }

  Future<void> _carregar() async {
    final Map<String, dynamic> manifesto = _decodificar(
      await _bundle.loadString(caminhoManifesto),
      caminhoManifesto,
    );
    final dynamic tabelas = manifesto['tabelas'];
    if (tabelas is! Map || tabelas.isEmpty) {
      throw const TussBaseLocalInvalidaException(
        'Manifesto TUSS sem tabelas.',
      );
    }

    final Map<String, TussItem> porCodigo = {};
    final Map<String, String> snapshots = {};
    final Set<String> comBase = {};

    for (final MapEntry<dynamic, dynamic> entrada in tabelas.entries) {
      final String tabela = entrada.key.toString();
      final Map<String, dynamic> dados =
          _objeto(entrada.value, 'tabela $tabela');
      final String snapshot = dados['snapshot'] as String? ?? '';
      if (snapshot.isEmpty) {
        throw TussBaseLocalInvalidaException(
          'Tabela $tabela sem snapshot no manifesto.',
        );
      }
      snapshots[tabela] = snapshot;

      final String? arquivo = dados['dataset'] as String?;
      if (arquivo == null || arquivo.isEmpty) continue;
      comBase.add(tabela);

      final String caminho = '$pasta/$arquivo';
      final Map<String, dynamic> conjunto = _decodificar(
        await _bundle.loadString(caminho),
        caminho,
      );
      if (conjunto['tabela'] != tabela) {
        throw TussBaseLocalInvalidaException(
          'Dataset $arquivo declara tabela ${conjunto['tabela']} no manifesto de $tabela.',
        );
      }
      final dynamic itens = conjunto['itens'];
      if (itens is! List) {
        throw TussBaseLocalInvalidaException(
          'Dataset $arquivo sem lista de itens.',
        );
      }
      final int total = conjunto['totalItens'] as int? ?? itens.length;
      if (itens.length != total) {
        throw TussBaseLocalInvalidaException(
          'Dataset $arquivo tem ${itens.length} itens, mas declara $total.',
        );
      }

      for (final dynamic bruto in itens) {
        final TussItem item = _item(bruto, tabela, arquivo);
        final TussItem? existente = porCodigo[item.id];
        if (existente != null) {
          throw TussBaseLocalInvalidaException(
            'Código ${item.id} aparece nas tabelas ${existente.tabela} e ${item.tabela}.',
          );
        }
        porCodigo[item.id] = item;
      }
    }

    _porCodigo
      ..clear()
      ..addAll(porCodigo);
    _snapshots
      ..clear()
      ..addAll(snapshots);
    _tabelas
      ..clear()
      ..addAll(snapshots.keys);
    _tabelasComBase
      ..clear()
      ..addAll(comBase);
    _carregada = true;
  }

  TussItem _item(dynamic bruto, String tabela, String arquivo) {
    final Map<String, dynamic> dados = _objeto(bruto, 'item de $arquivo');
    final String id = dados['id'] as String? ?? '';
    final String nome = dados['nome'] as String? ?? '';
    if (id.isEmpty || nome.isEmpty) {
      throw TussBaseLocalInvalidaException(
        'Dataset $arquivo tem item com id ou nome vazio.',
      );
    }
    return TussItem(
      id: id,
      nome: nome,
      tabela: tabela,
      inicioVigencia: dados['inicioVigencia'] as String?,
      fimVigencia: dados['fimVigencia'] as String?,
    );
  }

  Map<String, dynamic> _decodificar(String conteudo, String origem) {
    final dynamic dados;
    try {
      dados = jsonDecode(conteudo);
    } on FormatException catch (erro) {
      throw TussBaseLocalInvalidaException(
        'Não foi possível ler $origem: ${erro.message}.',
      );
    }
    return _objeto(dados, origem);
  }

  Map<String, dynamic> _objeto(dynamic valor, String origem) {
    if (valor is Map<String, dynamic>) return valor;
    if (valor is Map) return valor.cast<String, dynamic>();
    throw TussBaseLocalInvalidaException('$origem não é um objeto JSON.');
  }
}
