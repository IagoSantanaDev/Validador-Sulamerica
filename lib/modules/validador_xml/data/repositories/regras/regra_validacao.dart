import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';

/// Contrato para uma regra de validação de guia. Novas regras devem
/// implementar esta interface e ser registradas no repositório, sem
/// alterar as regras já existentes (Open/Closed Principle).
abstract class RegraValidacao {
  const RegraValidacao();

  /// Retorna o erro encontrado, ou null se a guia estiver conforme a regra.
  ErroValidacao? validar(GuiaTiss guia);
}
