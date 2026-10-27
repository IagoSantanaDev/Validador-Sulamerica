import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import '../../models/procedimento.dart';
import '../../models/resultado_consulta_tuss.dart';
import '../../services/classificador_tuss_local.dart';
import 'regra_validacao.dart';

/// Compara a tabela de cada código TUSS com o `codigoTabela` declarado no XML.
///
/// Só gera erro quando a base local permite decidir: código ausente na tabela,
/// código de outra tabela ou código vencido. Tabelas sem base local ficam para
/// a consulta remota.
class RegraTuss extends RegraValidacao {
  const RegraTuss(this._classificador);

  final ClassificadorTussLocal _classificador;

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    if (!_classificador.pronto) return null;

    final List<String> problemas = [];
    for (final Procedimento procedimento in guia.procedimentos) {
      final String? tabela = procedimento.codigoTabela;
      if (tabela == null) continue;

      final String? problema = _descrever(
        _classificador.classificar(
          codigo: procedimento.codigo,
          tabela: tabela,
        ),
      );
      if (problema != null && !problemas.contains(problema)) {
        problemas.add(problema);
      }
    }
    if (problemas.isEmpty) return null;

    return ErroValidacao(campo: 'tuss', mensagem: '${problemas.join('; ')}.');
  }

  String? _descrever(ResultadoConsultaTuss? resultado) {
    return switch (resultado) {
      TussNaoEncontrado(:final String codigo, :final String tabela) =>
        'Código $codigo não encontrado na tabela $tabela',
      TussTabelaDivergente(
        :final String codigo,
        :final String tabelaDeclarada,
        :final String tabelaEncontrada,
      ) =>
        'Código $codigo pertence à tabela $tabelaEncontrada, '
            'não à $tabelaDeclarada',
      TussEncontrado(:final item, :final bool vigente) => vigente
          ? null
          : 'Código ${item.id} vencido desde ${item.fimVigencia} '
              '(tabela ${item.tabela})',
      TussIndisponivel(
        :final String codigo,
        :final String tabela,
        :final String motivo
      ) =>
        'Não foi possível verificar o código $codigo na tabela $tabela: '
            '$motivo',
      TussSemReferencia() || TussTabelaDesconhecida() || null => null,
    };
  }
}
