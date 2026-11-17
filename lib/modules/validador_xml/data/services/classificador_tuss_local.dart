import '../datasources/tuss_base_local_datasource.dart';
import '../models/resultado_consulta_tuss.dart';
import '../models/tuss_item.dart';

/// Resolve, sem rede, o que a base local permite decidir sobre um código TUSS.
///
/// Retorna `null` quando a tabela declarada é válida, não tem base local e o
/// código precisa ser consultado no proxy. Tabelas `00` e `90`–`99` não têm
/// referência TUSS: nelas o código só é erro quando existe numa tabela oficial.
class ClassificadorTussLocal {
  factory ClassificadorTussLocal({
    TussBaseLocalDatasource? base,
    Set<String> tabelasOficiais = const {},
    DateTime Function() relogio = DateTime.now,
  }) =>
      ClassificadorTussLocal._(
        base ?? TussBaseLocalDatasource(),
        tabelasOficiais,
        relogio,
      );

  ClassificadorTussLocal._(this._base, this._tabelasOficiais, this._relogio);

  final TussBaseLocalDatasource _base;
  final Set<String> _tabelasOficiais;
  final DateTime Function() _relogio;

  Future<void> preparar() => _base.carregar();

  bool get pronto => _base.carregada;

  bool tabelaSemReferencia(String tabela) {
    if (tabela == '00') return true;
    final int? numero = int.tryParse(tabela);
    return numero != null && numero >= 90 && numero <= 99;
  }

  bool tabelaConhecida(String tabela) =>
      _base.tabelas.contains(tabela) || _tabelasOficiais.contains(tabela);

  ResultadoConsultaTuss? classificar({
    required String codigo,
    required String tabela,
  }) {
    if (!_base.carregada) {
      throw StateError('Chame preparar() antes de classificar códigos TUSS.');
    }

    final String codigoLimpo = codigo.trim();
    final String tabelaLimpa = tabela.trim();
    final bool semReferencia = tabelaSemReferencia(tabelaLimpa);

    if (!semReferencia && !tabelaConhecida(tabelaLimpa)) {
      return ResultadoConsultaTuss.tabelaDesconhecida(
        codigo: codigoLimpo,
        tabela: tabelaLimpa,
      );
    }

    final TussItem? item = _base.buscar(codigoLimpo);

    if (semReferencia) {
      if (item == null) {
        return ResultadoConsultaTuss.semReferencia(
          codigo: codigoLimpo,
          tabela: tabelaLimpa,
        );
      }
      return ResultadoConsultaTuss.tabelaDivergente(
        codigo: codigoLimpo,
        tabelaDeclarada: tabelaLimpa,
        tabelaEncontrada: item.tabela,
      );
    }

    if (item == null) {
      if (!_base.temBaseLocal(tabelaLimpa)) return null;
      return ResultadoConsultaTuss.naoEncontrado(
        codigo: codigoLimpo,
        tabela: tabelaLimpa,
      );
    }
    if (item.tabela != tabelaLimpa) {
      return ResultadoConsultaTuss.tabelaDivergente(
        codigo: codigoLimpo,
        tabelaDeclarada: tabelaLimpa,
        tabelaEncontrada: item.tabela,
      );
    }
    return ResultadoConsultaTuss.encontrado(
      item: item,
      vigente: _vigente(item),
    );
  }

  bool _vigente(TussItem item) {
    final String? fim = item.fimVigencia;
    if (fim == null || fim.isEmpty) return true;
    final DateTime? dataFim = DateTime.tryParse(fim);
    if (dataFim == null) return true;

    final DateTime agora = _relogio();
    final DateTime hoje = DateTime(agora.year, agora.month, agora.day);
    return !dataFim.isBefore(hoje);
  }
}
