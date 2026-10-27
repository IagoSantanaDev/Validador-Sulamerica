import '../models/guia_tiss.dart';
import '../models/guia_validada.dart';

abstract class ValidadorGuiasRepository {
  Future<void> preparar();

  List<GuiaValidada> validarLote(String conteudoXml);

  List<GuiaValidada> validarGuias(List<GuiaTiss> guias);
}
