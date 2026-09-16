import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';

abstract class RegraValidacao {
  const RegraValidacao();

  ErroValidacao? validar(GuiaTiss guia);
}
