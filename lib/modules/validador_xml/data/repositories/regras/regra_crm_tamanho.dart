import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'regra_validacao.dart';

class RegraCrmTamanho extends RegraValidacao {
  const RegraCrmTamanho();

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final String? numeroConselho = guia.solicitante?.numeroConselho;
    if (numeroConselho == null || numeroConselho.isEmpty) return null;
    if (numeroConselho.length <= 5) return null;

    return const ErroValidacao(
      campo: 'crm',
      mensagem: 'CRM deve ter no máximo 5 dígitos (014481)',
    );
  }
}
