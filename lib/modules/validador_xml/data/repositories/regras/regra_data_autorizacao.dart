import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import '../../models/procedimento.dart';
import 'regra_validacao.dart';

/// Acusa autorização com data posterior à execução de algum procedimento.
///
/// A autorização precisa existir antes do atendimento. Cada `dataExecucao` da
/// guia é comparada com a `dataAutorizacao` e as divergências são agregadas em
/// um único erro. Datas ausentes ou inválidas são ignoradas.
class RegraDataAutorizacao extends RegraValidacao {
  const RegraDataAutorizacao();

  static const String campo = 'dataAutorizacao';

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? textoAutorizacao = guia.dataAutorizacao;
    final DateTime? autorizacao = _data(textoAutorizacao);
    if (autorizacao == null) return null;

    final List<String> execucoesAnteriores = [];
    for (final Procedimento procedimento in guia.procedimentos) {
      final String? textoExecucao = procedimento.dataExecucao;
      final DateTime? execucao = _data(textoExecucao);
      if (textoExecucao == null || execucao == null) continue;
      if (autorizacao.isAfter(execucao) &&
          !execucoesAnteriores.contains(textoExecucao)) {
        execucoesAnteriores.add(textoExecucao);
      }
    }
    if (execucoesAnteriores.isEmpty) return null;

    return ErroValidacao(
      campo: campo,
      mensagem: 'Data de autorização ($textoAutorizacao) posterior '
          'à execução (${execucoesAnteriores.join(', ')})',
    );
  }

  DateTime? _data(String? texto) =>
      texto == null || texto.isEmpty ? null : DateTime.tryParse(texto);
}
