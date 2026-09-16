import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';

/// Contrato das regras (Open/Closed Principle).
abstract class RegraValidacao {
  const RegraValidacao();

  ErroValidacao? validar(GuiaTiss guia);
}
