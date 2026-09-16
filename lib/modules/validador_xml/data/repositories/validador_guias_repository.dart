import '../models/guia_validada.dart';

abstract class ValidadorGuiasRepository {
  List<GuiaValidada> validarLote(String conteudoXml);
}
