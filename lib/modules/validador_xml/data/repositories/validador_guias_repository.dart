import '../models/guia_validada.dart';

/// Contrato do repositório responsável por ler um lote de guias TISS e
/// aplicar as regras de validação de negócio sobre cada guia.
abstract class ValidadorGuiasRepository {
  List<GuiaValidada> validarLote(String conteudoXml);
}
