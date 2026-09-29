import 'guia_tiss.dart';
import 'informacoes_lote.dart';

class LoteGuiasExtraido {
  const LoteGuiasExtraido({
    required this.informacoes,
    required this.guias,
  });

  final InformacoesLote informacoes;
  final List<GuiaTiss> guias;
}
