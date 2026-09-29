import '../../models/erro_validacao.dart';
import '../../models/guia_tiss.dart';
import 'codigos_vpp.dart';
import 'regra_validacao.dart';

class RegraSenhaProcedimento extends RegraValidacao {
  const RegraSenhaProcedimento();

  static List<String> codigosAplicaveis(GuiaTiss guia) => guia.procedimentos
      .map((procedimento) => procedimento.codigo)
      .where(CodigosVpp.todos.contains)
      .toSet()
      .toList();

  @override
  ErroValidacao? validar(GuiaTiss guia) {
    final List<String> codigos = codigosAplicaveis(guia);
    if (codigos.isEmpty || (guia.senha?.isNotEmpty ?? false)) return null;

    return ErroValidacao(
      campo: 'senha',
      mensagem:
          'Senha obrigatória para procedimentos VPP: ${codigos.join(', ')}',
    );
  }
}
